local M = {}

local util

function M.init(deps)
  util = deps.util
end

local function index_assets(assets)
  local map = {}
  for _, asset in ipairs(assets or {}) do
    if asset.name then
      map[asset.name] = asset
    end
  end
  return map
end

local function budget_reached(budget)
  if budget.max_assets > 0 and budget.count >= budget.max_assets then
    return true
  end
  if budget.max_bytes > 0 and budget.bytes >= budget.max_bytes then
    return true
  end
  return false
end

local function budget_allows(budget, size)
  if budget.max_assets > 0 and budget.count + 1 > budget.max_assets then
    return false
  end
  if budget.max_bytes > 0 and budget.bytes + size > budget.max_bytes then
    return false
  end
  return true
end

function M.sync(ctx, tag, gh_release, fj_release, budget)
  if not gh_release or not fj_release then
    return
  end

  local gh_assets, err = ctx.gh:list_release_assets(gh_release.id)
  if not gh_assets then
    ctx:error("could not list GitHub assets for %s: %s", tag, tostring(err))
    return
  end
  local fj_assets, err = ctx.fj:list_release_assets(fj_release.id)
  if not fj_assets then
    ctx:error("could not list Forgejo assets for %s: %s", tag, tostring(err))
    return
  end

  local gh_by_name = index_assets(gh_assets)
  local fj_by_name = index_assets(fj_assets)

  for _, asset in ipairs(gh_assets) do
    local existing = fj_by_name[asset.name]
    if not existing then
      local size = asset.size or 0
      if size > ctx.config.max_asset_bytes then
        ctx:warn(
          "skipping %s/%s: %d bytes exceeds SYNC_MAX_ASSET_BYTES (%d)",
          tag,
          asset.name,
          size,
          ctx.config.max_asset_bytes
        )
      elseif size > 2048 * 1024 * 1024 then
        ctx:warn("skipping %s/%s: exceeds Forgejo's 2048 MB asset limit", tag, asset.name)
      elseif budget_reached(budget) then
        ctx:info("asset budget reached before %s/%s", tag, asset.name)
        return
      elseif not budget_allows(budget, size) then
        ctx:info("asset byte budget reached before %s/%s", tag, asset.name)
        return
      else
        if ctx.dry_run then
          ctx:plan("upload Forgejo asset %s/%s (%d bytes)", tag, asset.name, size)
          budget.count = budget.count + 1
          budget.bytes = budget.bytes + size
        else
          local bytes, download_err = ctx.gh:download_release_asset(asset.id)
          if not bytes then
            ctx:error("could not download GitHub asset %s/%s: %s", tag, asset.name, tostring(download_err))
          else
            local uploaded, upload_err = ctx.fj:upload_release_asset(fj_release.id, asset.name, bytes)
            if not uploaded then
              if upload_err and (upload_err:match(" %-> 409:") or upload_err:match(" %-> 422:")) then
                ctx:warn("Forgejo asset %s/%s already exists; skipping", tag, asset.name)
              else
                ctx:error("could not upload Forgejo asset %s/%s: %s", tag, asset.name, tostring(upload_err))
              end
            else
              local uploaded_size = uploaded.size or #bytes
              if uploaded_size ~= size then
                ctx:error("size mismatch for %s/%s: GitHub=%d Forgejo=%d", tag, asset.name, size, uploaded_size)
              else
                budget.count = budget.count + 1
                budget.bytes = budget.bytes + size
                ctx.stats.assets_uploaded = ctx.stats.assets_uploaded + 1
                ctx.stats.bytes_uploaded = ctx.stats.bytes_uploaded + size
                ctx:info("uploaded %s/%s (%d bytes)", tag, asset.name, size)
              end
            end
          end
        end
      end
    elseif existing.size ~= asset.size then
      ctx:warn(
        "asset size mismatch for %s/%s: GitHub=%s Forgejo=%s",
        tag,
        asset.name,
        tostring(asset.size),
        tostring(existing.size)
      )
      ctx.stats.skipped = ctx.stats.skipped + 1
    end
  end

  for _, asset in ipairs(fj_assets) do
    if not gh_by_name[asset.name] then
      ctx:info("Forgejo-only asset %s/%s; leaving in place", tag, asset.name)
    end
  end
end

return M
