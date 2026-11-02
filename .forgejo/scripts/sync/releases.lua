local M = {}

local util
local assets

function M.init(deps)
  util = deps.util
  assets = deps.assets
end

local function fetch_tags(api)
  local tags, err = api:list_tags()
  if not tags then
    return nil, err
  end
  local map = {}
  for _, tag in ipairs(tags) do
    local sha = tag.commit and tag.commit.sha or tag.sha
    if tag.name and sha then
      map[tag.name] = sha
    end
  end
  return map
end

local function fetch_releases(api)
  local releases, err = api:list_releases()
  if not releases then
    return nil, nil, err
  end
  local published = {}
  local drafts = {}
  for _, release in ipairs(releases) do
    if release.tag_name then
      if release.draft then
        drafts[release.tag_name] = release
      else
        published[release.tag_name] = release
      end
    end
  end
  return published, drafts
end

local function tag_sha(tag)
  return tag and (tag.commit and tag.commit.sha or tag.sha)
end

local function ensure_tag(ctx, api, side, tag, sha)
  local existing, err = api:get_tag(tag)
  if not existing and err then
    ctx:error("could not inspect %s tag %s: %s", side, tag, tostring(err))
    return nil
  end
  if existing then
    local existing_sha = tag_sha(existing)
    if existing_sha ~= sha then
      ctx:error(
        "tag %s already exists on %s at %s, expected %s; refusing to force-update",
        tag,
        side,
        tostring(existing_sha),
        sha
      )
      return nil
    end
    return existing
  end

  if ctx.dry_run then
    ctx:plan("create %s tag %s at %s", side, tag, sha)
    return nil
  end

  local created, create_err = api:create_tag(tag, sha)
  if created then
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created %s tag %s at %s", side, tag, sha)
    return created
  end

  if create_err and (create_err:match(" %-> 409:") or create_err:match(" %-> 422:")) then
    existing = api:get_tag(tag)
    if existing and tag_sha(existing) == sha then
      return existing
    end
  end

  ctx:error("could not create %s tag %s: %s", side, tag, tostring(create_err))
  return nil
end

local function create_release(ctx, source, side, tag, sha)
  local payload = {
    tag_name = tag,
    target_commitish = sha,
    name = source.name or "",
    body = util.strip_full_changelog(source.body or ""),
    draft = false,
    prerelease = source.prerelease and true or false,
  }

  if ctx.dry_run then
    ctx:plan("create %s release %s from %s", side, tag, source.html_url or "remote release")
    return nil
  end

  local api = side == "github" and ctx.gh or ctx.fj
  local created, err = api:create_release(payload)
  if not created then
    if err and (err:match(" %-> 409:") or err:match(" %-> 422:")) then
      local existing = api:get_release_by_tag(tag)
      if existing then
        return existing
      end
    end
    ctx:error("could not create %s release %s: %s", side, tag, tostring(err))
    return nil
  end

  ctx.stats.created = ctx.stats.created + 1
  ctx:info("created %s release %s", side, tag)
  return created
end

local function sync_metadata(ctx, tag, fj_release, gh_release)
  local fj_body = util.strip_full_changelog(fj_release.body or "")
  local gh_body = util.strip_full_changelog(gh_release.body or "")
  local fj_name = fj_release.name or ""
  local gh_name = gh_release.name or ""
  local fj_prerelease = fj_release.prerelease and true or false
  local gh_prerelease = gh_release.prerelease and true or false

  if
    fj_name == gh_name
    and util.normalize_release_body(fj_body) == util.normalize_release_body(gh_body)
    and fj_prerelease == gh_prerelease
  then
    return
  end

  local payload = {
    name = fj_name,
    body = util.merge_full_changelog(fj_body, gh_release.body),
    prerelease = fj_prerelease,
    draft = false,
  }

  if ctx.dry_run then
    ctx:plan("update GitHub release %s from Forgejo", tag)
    return
  end

  local updated, err = ctx.gh:edit_release(gh_release.id, payload)
  if not updated then
    ctx:error("could not update GitHub release %s: %s", tag, tostring(err))
    return
  end

  gh_release.name = fj_name
  gh_release.body = payload.body
  gh_release.prerelease = fj_prerelease
  ctx.stats.updated = ctx.stats.updated + 1
  ctx:info("updated GitHub release %s from Forgejo", tag)
end

local function sorted_tags(...)
  local seen = {}
  local list = {}
  for _, releases in ipairs({ ... }) do
    for tag in pairs(releases) do
      if not seen[tag] then
        seen[tag] = true
        list[#list + 1] = tag
      end
    end
  end
  table.sort(list)
  return list
end

function M.sync(ctx, opts)
  opts = opts or {}

  local fj_releases, fj_drafts, err = fetch_releases(ctx.fj)
  if not fj_releases then
    ctx:error("could not load Forgejo releases: %s", tostring(err))
    return
  end
  local gh_releases, gh_drafts, err = fetch_releases(ctx.gh)
  if not gh_releases then
    ctx:error("could not load GitHub releases: %s", tostring(err))
    return
  end

  local budget = {
    count = 0,
    bytes = 0,
    max_assets = ctx.config.max_assets or 0,
    max_bytes = ctx.config.max_bytes or 0,
  }

  if opts.assets_only then
    local tags = sorted_tags(fj_releases, gh_releases)
    local seen = {}
    for _, tag in ipairs(tags) do
      if not opts.only_tag or opts.only_tag == tag then
        seen[tag] = true
        if gh_drafts[tag] and not gh_releases[tag] then
          ctx:info("skipping GitHub draft release %s", tag)
        elseif fj_drafts[tag] and not fj_releases[tag] then
          ctx:info("skipping Forgejo draft release %s", tag)
        else
          local fj_release = fj_releases[tag]
          local gh_release = gh_releases[tag]
          if fj_release and gh_release then
            assets.sync(ctx, tag, gh_release, fj_release, budget)
          else
            ctx:warn("skipping assets for %s: release missing on %s", tag, fj_release and "GitHub" or "Forgejo")
          end
        end
      end
    end
    if opts.only_tag and not seen[opts.only_tag] then
      ctx:warn("tag %s was not found in published releases on either side", opts.only_tag)
    end
    return
  end

  local fj_tags, err = fetch_tags(ctx.fj)
  if not fj_tags then
    ctx:error("could not load Forgejo tags: %s", tostring(err))
    return
  end
  local gh_tags, err = fetch_tags(ctx.gh)
  if not gh_tags then
    ctx:error("could not load GitHub tags: %s", tostring(err))
    return
  end

  local tags = sorted_tags(fj_releases, gh_releases)
  local seen = {}
  for _, tag in ipairs(tags) do
    if not opts.only_tag or opts.only_tag == tag then
      seen[tag] = true
      local fj_release = fj_releases[tag]
      local gh_release = gh_releases[tag]

      if gh_drafts[tag] and not gh_release then
        ctx:info("skipping GitHub draft release %s", tag)
      elseif fj_drafts[tag] and not fj_release then
        ctx:info("skipping Forgejo draft release %s", tag)
      else
        local fj_sha = fj_tags[tag]
        local gh_sha = gh_tags[tag]
        if fj_sha and gh_sha and fj_sha ~= gh_sha then
          ctx:error("tag %s SHA mismatch: Forgejo=%s GitHub=%s", tag, fj_sha, gh_sha)
        else
          local source_sha = fj_sha or gh_sha
          local target_side
          local source_release
          if fj_release and not gh_release then
            target_side = "github"
            source_release = fj_release
          elseif gh_release and not fj_release then
            target_side = "forgejo"
            source_release = gh_release
          end

          if target_side then
            if not source_sha then
              ctx:error("release %s exists without a matching tag SHA", tag)
            else
              local target_api = target_side == "github" and ctx.gh or ctx.fj
              local target_tags = target_side == "github" and gh_tags or fj_tags
              local target_releases = target_side == "github" and gh_releases or fj_releases

              local ready = true
              if not target_tags[tag] then
                local ensured = ensure_tag(ctx, target_api, target_side, tag, source_sha)
                if ensured then
                  target_tags[tag] = source_sha
                else
                  ready = false
                end
              end

              if ready then
                local created = create_release(ctx, source_release, target_side, tag, source_sha)
                if created then
                  target_releases[tag] = created
                end
              end
            end
          end

          local final_fj = fj_releases[tag]
          local final_gh = gh_releases[tag]
          if final_fj and final_gh then
            sync_metadata(ctx, tag, final_fj, final_gh)
            if opts.assets then
              assets.sync(ctx, tag, final_gh, final_fj, budget)
            end
          end
        end
      end
    end
  end

  if opts.only_tag and not seen[opts.only_tag] then
    ctx:warn("tag %s was not found in published releases on either side", opts.only_tag)
  end
end

return M
