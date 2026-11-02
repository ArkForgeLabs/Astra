local M = {}

local util
local markers

function M.init(deps)
  util = deps.util
  markers = deps.markers
end

local function number_from_url(url)
  return tonumber(tostring(url or ""):match("/(%d+)/?$"))
end

local function classify_forgejo(comment)
  local pr_number = number_from_url(comment.pull_request_url)
  if pr_number then
    return "pr", pr_number
  end
  return "issue", number_from_url(comment.issue_url)
end

local function classify_github(comment, pr_numbers)
  local number = number_from_url(comment.issue_url)
  if number and pr_numbers[number] then
    return "pr", number
  end
  return "issue", number
end

local function group_comments(list, classifier)
  local grouped = {}
  for _, comment in ipairs(list or {}) do
    local kind, number = classifier(comment)
    if kind and number then
      local key = kind .. ":" .. number
      grouped[key] = grouped[key] or {}
      grouped[key][#grouped[key] + 1] = comment
    end
  end
  return grouped
end

local function sort_comments(list)
  table.sort(list, function(a, b)
    local a_created = a.created_at or ""
    local b_created = b.created_at or ""
    if a_created == b_created then
      return (a.id or 0) < (b.id or 0)
    end
    return a_created < b_created
  end)
end

local function comment_author(comment)
  return comment.user and comment.user.login or ""
end

local function pair_pulls(ctx)
  local fj_pulls, err = ctx.fj:list_pulls()
  if not fj_pulls then
    return nil, nil, nil, err
  end
  local gh_pulls, err = ctx.gh:list_pulls()
  if not gh_pulls then
    return nil, nil, nil, err
  end

  local gh_by_sha = {}
  local gh_pr_numbers = {}
  for _, pull in ipairs(gh_pulls) do
    gh_pr_numbers[pull.number] = true
    if pull.head and pull.head.sha then
      gh_by_sha[pull.head.sha] = pull
    end
  end

  local pairs = {}
  local fj_pr_numbers = {}
  for _, pull in ipairs(fj_pulls) do
    fj_pr_numbers[pull.number] = true
    local sha = pull.head and pull.head.sha
    if sha and gh_by_sha[sha] then
      pairs[#pairs + 1] = { fj = pull, gh = gh_by_sha[sha] }
    end
  end

  return pairs, gh_pr_numbers, fj_pr_numbers
end

local function find_comment_marker(ctx, side, body)
  if side == "forgejo" then
    return markers.find_comment(ctx.namespace, body, "github")
  end
  return markers.find_comment(ctx.namespace, body, "forgejo")
end

local function comment_marker_for(ctx, target_side, source_issue, source_comment, hash)
  if target_side == "github" then
    return markers.comment(ctx.namespace, "forgejo", source_issue, source_comment, hash)
  end
  return markers.comment(ctx.namespace, "github", source_issue, source_comment, hash)
end

local function ensure_comment_marker(ctx, side, comment, other_issue, other_comment, hash)
  local existing = find_comment_marker(ctx, side, comment.body)
  if existing and existing.issue == other_issue and existing.comment == other_comment and existing.hash == hash then
    return
  end

  local marker = comment_marker_for(ctx, side, other_issue, other_comment, hash)
  local body = markers.set(ctx.namespace, comment.body, marker)

  if ctx.dry_run then
    ctx:plan("update %s comment %d sync marker", side, comment.id)
    return
  end

  local api = side == "forgejo" and ctx.fj or ctx.gh
  local updated, err = api:edit_comment(comment.id, { body = body })
  if not updated then
    ctx:error("could not update %s comment %d marker: %s", side, comment.id, tostring(err))
    return
  end
  comment.body = body
end

local function update_comment(ctx, source, target, source_side, target_side, source_issue, target_issue)
  local source_body = markers.strip(ctx.namespace, source.body or "")
  local target_body = markers.strip(ctx.namespace, target.body or "")
  local source_hash = util.comment_hash(source_body)
  local target_hash = util.comment_hash(target_body)
  local source_marker = find_comment_marker(ctx, source_side, source.body)
  local target_marker = find_comment_marker(ctx, target_side, target.body)
  local direction = util.decide_direction(
    source_hash,
    source_marker and source_marker.hash,
    target_hash,
    target_marker and target_marker.hash
  )

  if direction == "forgejo" then
    local marker = comment_marker_for(ctx, "github", source_issue, source.id, source_hash)
    local new_body = markers.set(ctx.namespace, source_body, marker)
    local marker_changed = target_marker == nil
      or target_marker.issue ~= source_issue
      or target_marker.comment ~= source.id
      or target_marker.hash ~= source_hash
    if util.normalize_body(source_body) ~= util.normalize_body(target_body) or marker_changed then
      if ctx.dry_run then
        ctx:plan("update GitHub comment %d from Forgejo comment %d", target.id, source.id)
      else
        local updated, err = ctx.gh:edit_comment(target.id, { body = new_body })
        if not updated then
          ctx:error("could not update GitHub comment %d: %s", target.id, tostring(err))
          return
        end
        target.body = new_body
        ctx.stats.updated = ctx.stats.updated + 1
        ctx:info("updated GitHub comment %d from Forgejo comment %d", target.id, source.id)
      end
    end
    ensure_comment_marker(ctx, "forgejo", source, target_issue, target.id, source_hash)
  elseif direction == "github" then
    local marker = comment_marker_for(ctx, "forgejo", source_issue, source.id, source_hash)
    local new_body = markers.set(ctx.namespace, source_body, marker)
    local marker_changed = target_marker == nil
      or target_marker.issue ~= source_issue
      or target_marker.comment ~= source.id
      or target_marker.hash ~= source_hash
    if util.normalize_body(source_body) ~= util.normalize_body(target_body) or marker_changed then
      if ctx.dry_run then
        ctx:plan("update Forgejo comment %d from GitHub comment %d", target.id, source.id)
      else
        local updated, err = ctx.fj:edit_comment(target.id, { body = new_body })
        if not updated then
          ctx:error("could not update Forgejo comment %d: %s", target.id, tostring(err))
          return
        end
        target.body = new_body
        ctx.stats.updated = ctx.stats.updated + 1
        ctx:info("updated Forgejo comment %d from GitHub comment %d", target.id, source.id)
      end
    end
    ensure_comment_marker(ctx, "github", source, target_issue, target.id, source_hash)
  else
    ensure_comment_marker(ctx, "forgejo", source, target_issue, target.id, source_hash)
    ensure_comment_marker(ctx, "github", target, source_issue, source.id, target_hash)
  end
end

local function create_comment(ctx, source, source_side, target_side, source_issue, target_issue)
  local source_body = markers.strip(ctx.namespace, source.body or "")
  local hash = util.comment_hash(source_body)
  local marker = comment_marker_for(ctx, target_side, source_issue, source.id, hash)
  local body = markers.set(ctx.namespace, source_body, marker)

  if target_side == "github" then
    if ctx.dry_run then
      ctx:plan("create GitHub comment on #%d from Forgejo comment %d", target_issue, source.id)
      return
    end
    local created, err = ctx.gh:create_comment(target_issue, body)
    if not created then
      ctx:error("could not create GitHub comment on #%d: %s", target_issue, tostring(err))
      return
    end
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created GitHub comment %d on #%d from Forgejo comment %d", created.id, target_issue, source.id)
    ensure_comment_marker(ctx, "forgejo", source, target_issue, created.id, hash)
  else
    if ctx.dry_run then
      ctx:plan("create Forgejo comment on #%d from GitHub comment %d", target_issue, source.id)
      return
    end
    local created, err = ctx.fj:create_comment(target_issue, body)
    if not created then
      ctx:error("could not create Forgejo comment on #%d: %s", target_issue, tostring(err))
      return
    end
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created Forgejo comment %d on #%d from GitHub comment %d", created.id, target_issue, source.id)
    ensure_comment_marker(ctx, "github", source, target_issue, created.id, hash)
  end
end

local function pair_comments(ctx, fj_list, gh_list, fj_issue, gh_issue)
  local fj_by_id = {}
  for _, comment in ipairs(fj_list) do
    fj_by_id[comment.id] = comment
  end
  local gh_by_id = {}
  for _, comment in ipairs(gh_list) do
    gh_by_id[comment.id] = comment
  end

  local paired = {}
  local used_fj, used_gh = {}, {}
  local orphan_fj, orphan_gh = {}, {}

  for _, fj in ipairs(fj_list) do
    local marker = markers.find_comment(ctx.namespace, fj.body, "github")
    if marker then
      if marker.issue ~= gh_issue then
        orphan_fj[fj.id] = true
        ctx:warn("Forgejo comment %d marker points to GitHub issue #%d, expected #%d", fj.id, marker.issue, gh_issue)
      else
        local gh = gh_by_id[marker.comment]
        if not gh then
          orphan_fj[fj.id] = true
          ctx:warn("Forgejo comment %d points to missing GitHub comment %d; treating as orphan", fj.id, marker.comment)
        elseif used_gh[gh.id] then
          orphan_fj[fj.id] = true
          ctx:warn("Forgejo comment %d points to already-paired GitHub comment %d", fj.id, gh.id)
        else
          local gh_marker = markers.find_comment(ctx.namespace, gh.body, "forgejo")
          if gh_marker and (gh_marker.issue ~= fj_issue or gh_marker.comment ~= fj.id) then
            orphan_fj[fj.id] = true
            orphan_gh[gh.id] = true
            ctx:error(
              "comment marker mismatch: Forgejo %d -> GitHub %d, GitHub %d -> Forgejo %d",
              fj.id,
              gh.id,
              gh.id,
              gh_marker.comment
            )
          else
            paired[#paired + 1] = { fj = fj, gh = gh }
            used_fj[fj.id] = true
            used_gh[gh.id] = true
          end
        end
      end
    end
  end

  for _, gh in ipairs(gh_list) do
    if not used_gh[gh.id] then
      local marker = markers.find_comment(ctx.namespace, gh.body, "forgejo")
      if marker then
        if marker.issue ~= fj_issue then
          orphan_gh[gh.id] = true
          ctx:warn("GitHub comment %d marker points to Forgejo issue #%d, expected #%d", gh.id, marker.issue, fj_issue)
        else
          local fj = fj_by_id[marker.comment]
          if not fj then
            orphan_gh[gh.id] = true
            ctx:warn(
              "GitHub comment %d points to missing Forgejo comment %d; treating as orphan",
              gh.id,
              marker.comment
            )
          elseif used_fj[fj.id] then
            orphan_gh[gh.id] = true
            ctx:warn("GitHub comment %d points to already-paired Forgejo comment %d", gh.id, fj.id)
          else
            paired[#paired + 1] = { fj = fj, gh = gh }
            used_fj[fj.id] = true
            used_gh[gh.id] = true
          end
        end
      end
    end
  end

  local gh_by_body = {}
  for _, gh in ipairs(gh_list) do
    if not used_gh[gh.id] and not orphan_gh[gh.id] then
      local key = util.normalize_body(markers.strip(ctx.namespace, gh.body or ""))
      gh_by_body[key] = gh_by_body[key] or {}
      gh_by_body[key][#gh_by_body[key] + 1] = gh
    end
  end
  for _, list in pairs(gh_by_body) do
    sort_comments(list)
  end

  for _, fj in ipairs(fj_list) do
    if not used_fj[fj.id] and not orphan_fj[fj.id] then
      local key = util.normalize_body(markers.strip(ctx.namespace, fj.body or ""))
      local candidates = gh_by_body[key]
      if candidates then
        local selected
        local author = comment_author(fj)
        for _, gh in ipairs(candidates) do
          if not used_gh[gh.id] and comment_author(gh) == author then
            selected = gh
            break
          end
        end
        if not selected then
          for _, gh in ipairs(candidates) do
            if not used_gh[gh.id] then
              selected = gh
              break
            end
          end
        end
        if selected then
          paired[#paired + 1] = { fj = fj, gh = selected }
          used_fj[fj.id] = true
          used_gh[selected.id] = true
        end
      end
    end
  end

  return paired, used_fj, used_gh, orphan_fj, orphan_gh
end

local function sync_comment_pair(ctx, pair, fj_issue, gh_issue)
  local fj_body = markers.strip(ctx.namespace, pair.fj.body or "")
  local gh_body = markers.strip(ctx.namespace, pair.gh.body or "")
  local fj_hash = util.comment_hash(fj_body)
  local gh_hash = util.comment_hash(gh_body)
  local fj_marker = markers.find_comment(ctx.namespace, pair.fj.body, "github")
  local gh_marker = markers.find_comment(ctx.namespace, pair.gh.body, "forgejo")
  local direction = util.decide_direction(fj_hash, fj_marker and fj_marker.hash, gh_hash, gh_marker and gh_marker.hash)

  if direction == "forgejo" then
    update_comment(ctx, pair.fj, pair.gh, "forgejo", "github", fj_issue, gh_issue)
  elseif direction == "github" then
    update_comment(ctx, pair.gh, pair.fj, "github", "forgejo", gh_issue, fj_issue)
  else
    ensure_comment_marker(ctx, "forgejo", pair.fj, gh_issue, pair.gh.id, fj_hash)
    ensure_comment_marker(ctx, "github", pair.gh, fj_issue, pair.fj.id, gh_hash)
  end
end

local function sync_comment_list(ctx, fj_list, gh_list, fj_issue, gh_issue)
  local paired, used_fj, used_gh, orphan_fj, orphan_gh = pair_comments(ctx, fj_list, gh_list, fj_issue, gh_issue)

  for _, pair in ipairs(paired) do
    sync_comment_pair(ctx, pair, fj_issue, gh_issue)
  end

  for _, fj in ipairs(fj_list) do
    if not used_fj[fj.id] and not orphan_fj[fj.id] then
      create_comment(ctx, fj, "forgejo", "github", fj_issue, gh_issue)
    end
  end
  for _, gh in ipairs(gh_list) do
    if not used_gh[gh.id] and not orphan_gh[gh.id] then
      create_comment(ctx, gh, "github", "forgejo", gh_issue, fj_issue)
    end
  end
end

function M.sync(ctx, issue_state, opts)
  opts = opts or {}
  if not issue_state then
    return
  end

  local fj_comments, err = ctx.fj:list_comments()
  if not fj_comments then
    ctx:error("could not load Forgejo comments: %s", tostring(err))
    return
  end
  local gh_comments, err = ctx.gh:list_comments()
  if not gh_comments then
    ctx:error("could not load GitHub comments: %s", tostring(err))
    return
  end

  local pr_pairs, gh_pr_numbers, fj_pr_numbers, pr_err = pair_pulls(ctx)
  if not pr_pairs then
    ctx:error("could not load pull requests: %s", tostring(pr_err))
    return
  end

  local fj_grouped = group_comments(fj_comments, classify_forgejo)
  local gh_grouped = group_comments(gh_comments, function(comment)
    return classify_github(comment, gh_pr_numbers)
  end)

  for _, pair in ipairs(issue_state.pairs or {}) do
    if not opts.only_number or pair.fj.number == opts.only_number or pair.gh.number == opts.only_number then
      sync_comment_list(
        ctx,
        fj_grouped["issue:" .. pair.fj.number] or {},
        gh_grouped["issue:" .. pair.gh.number] or {},
        pair.fj.number,
        pair.gh.number
      )
    end
  end

  for _, pair in ipairs(pr_pairs) do
    if not opts.only_number or pair.fj.number == opts.only_number or pair.gh.number == opts.only_number then
      sync_comment_list(
        ctx,
        fj_grouped["pr:" .. pair.fj.number] or {},
        gh_grouped["pr:" .. pair.gh.number] or {},
        pair.fj.number,
        pair.gh.number
      )
    end
  end

  local unmatched_issue_comments = 0
  local paired_issue_keys = {}
  for _, pair in ipairs(issue_state.pairs or {}) do
    paired_issue_keys["issue:" .. pair.fj.number] = true
    paired_issue_keys["issue:" .. pair.gh.number] = true
  end
  for key, list in pairs(fj_grouped) do
    if key:sub(1, 6) == "issue:" and not paired_issue_keys[key] then
      unmatched_issue_comments = unmatched_issue_comments + #list
    end
  end
  for key, list in pairs(gh_grouped) do
    if key:sub(1, 6) == "issue:" and not paired_issue_keys[key] then
      unmatched_issue_comments = unmatched_issue_comments + #list
    end
  end

  local paired_pr_keys = {}
  for _, pair in ipairs(pr_pairs) do
    paired_pr_keys["pr:" .. pair.fj.number] = true
    paired_pr_keys["pr:" .. pair.gh.number] = true
  end
  local unmatched_pr_comments = 0
  for key, list in pairs(fj_grouped) do
    if key:sub(1, 3) == "pr:" and not paired_pr_keys[key] then
      unmatched_pr_comments = unmatched_pr_comments + #list
    end
  end
  for key, list in pairs(gh_grouped) do
    if key:sub(1, 3) == "pr:" and not paired_pr_keys[key] then
      unmatched_pr_comments = unmatched_pr_comments + #list
    end
  end

  if not opts.only_number and unmatched_issue_comments > 0 then
    ctx:warn("skipped %d comments on unpaired issues", unmatched_issue_comments)
  end
  if not opts.only_number and unmatched_pr_comments > 0 then
    ctx:warn("skipped %d comments on unpaired pull requests", unmatched_pr_comments)
  end
end

return M
