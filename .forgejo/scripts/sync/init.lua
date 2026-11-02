local M = {}

local util
local markers
local HttpClient
local Forgejo
local GitHub
local issues
local comments
local releases

function M.setup(deps)
  util = deps.util
  markers = deps.markers
  HttpClient = deps.http
  Forgejo = deps.forgejo
  GitHub = deps.github
  issues = deps.issues
  comments = deps.comments
  releases = deps.releases
end

function M.parse_args(argv)
  return util.parse_args(argv)
end

local function env(name, default)
  return util.env(name, default)
end

local function config_from_env(args)
  args = args or {}

  local mode = type(args.mode) == "string" and args.mode or env("SYNC_MODE")
  local event = env("SYNC_EVENT", "")
  if not mode or mode == "" then
    if event == "issues" then
      mode = "issue"
    elseif event == "issue_comment" then
      mode = "comment"
    elseif event == "release" then
      mode = "release"
    else
      mode = "full"
    end
  end

  if mode ~= "full" and mode ~= "issue" and mode ~= "comment" and mode ~= "release" and mode ~= "assets" then
    return nil, "invalid sync mode: " .. tostring(mode)
  end

  local namespace = env("SYNC_MARKER_NAMESPACE", "astra-sync")
  if not markers.validate_namespace(namespace) then
    return nil, "invalid SYNC_MARKER_NAMESPACE: " .. tostring(namespace)
  end

  local config = {
    forgejo_url = env("FORGEJO_URL", "https://git.arkforge.net"),
    forgejo_repo = env("FORGEJO_REPO", "ArkForgeLabs/Astra"),
    github_api_url = env("GITHUB_API_URL", "https://api.github.com"),
    github_repo = env("GITHUB_REPO", "ArkForgeLabs/Astra"),
    github_token = env("GH_SYNC_TOKEN"),
    forgejo_token = env("SYNC_FORGEJO_TOKEN") or env("FORGEJO_SYNC_TOKEN") or env("FORGEJO_TOKEN"),
    namespace = namespace,
    user_agent = env("SYNC_USER_AGENT", "Astra-GitHub-Sync/1.0"),
    mode = mode,
    event = event,
    dry_run = util.parse_bool(args.dry_run or env("SYNC_INPUT_DRY_RUN") or env("SYNC_DRY_RUN"), false),
    only_issue = tonumber(args.issue or env("SYNC_ISSUE_NUMBER")),
    only_comment = tonumber(args.comment or env("SYNC_COMMENT_ID")),
    only_tag = type(args.tag) == "string" and args.tag or env("SYNC_TAG"),
    max_assets = tonumber(args.max_assets or env("SYNC_MAX_ASSETS") or "0") or 0,
    max_bytes = tonumber(args.max_bytes or env("SYNC_MAX_BYTES") or "0") or 0,
    max_asset_bytes = tonumber(args.max_asset_bytes or env("SYNC_MAX_ASSET_BYTES", "134217728")) or 134217728,
    retries = tonumber(env("SYNC_RETRIES", "3")) or 3,
    bootstrap = util.parse_bool(args.bootstrap or env("SYNC_BOOTSTRAP"), false),
  }

  if not config.github_token then
    return nil, "GH_SYNC_TOKEN is required"
  end
  if not config.forgejo_token and not config.dry_run then
    return nil, "FORGEJO_TOKEN or SYNC_FORGEJO_TOKEN is required"
  end

  return config
end

local function new_context(config)
  local client = HttpClient.new(config)
  local ctx = {
    config = config,
    dry_run = config.dry_run,
    namespace = config.namespace,
    client = client,
    fj = Forgejo.new(client, config),
    gh = GitHub.new(client, config),
    errors = {},
    stats = {
      planned = 0,
      created = 0,
      updated = 0,
      skipped = 0,
      errors = 0,
      assets_uploaded = 0,
      bytes_uploaded = 0,
    },
  }

  function ctx:info(fmt, ...)
    util.info(fmt, ...)
  end

  function ctx:warn(fmt, ...)
    util.warn(fmt, ...)
  end

  function ctx:plan(fmt, ...)
    self.stats.planned = self.stats.planned + 1
    util.plan(fmt, ...)
  end

  function ctx:error(fmt, ...)
    local message
    if select("#", ...) == 0 then
      message = tostring(fmt)
    else
      local ok, formatted = pcall(string.format, fmt, ...)
      message = ok and formatted or tostring(fmt)
    end
    self.stats.errors = self.stats.errors + 1
    self.errors[#self.errors + 1] = message
    util.error("%s", message)
  end

  return ctx
end

local function run_sync(ctx)
  local config = ctx.config
  if config.mode == "issue" then
    issues.sync(ctx, { only_number = config.only_issue })
  elseif config.mode == "comment" then
    local state = issues.sync(ctx, { only_number = config.only_issue })
    if state then
      comments.sync(ctx, state, { only_number = config.only_issue })
    end
  elseif config.mode == "release" then
    releases.sync(ctx, { only_tag = config.only_tag, assets = false })
  elseif config.mode == "assets" then
    releases.sync(ctx, { only_tag = config.only_tag, assets = true, assets_only = true })
  else
    local state = issues.sync(ctx, {})
    if state then
      comments.sync(ctx, state, {})
    end
    releases.sync(ctx, { assets = true })
  end
end

function M.run(argv)
  local args = M.parse_args(argv)
  local config, err = config_from_env(args)
  if not config then
    util.error("%s", err)
    return false
  end

  util.info(
    "starting sync mode=%s event=%s dry_run=%s forgejo=%s github=%s",
    config.mode,
    config.event,
    tostring(config.dry_run),
    config.forgejo_repo,
    config.github_repo
  )
  if config.only_issue then
    util.info("filtering issue/PR #%d", config.only_issue)
  end
  if config.only_tag then
    util.info("filtering release tag %s", config.only_tag)
  end
  if config.max_assets > 0 then
    util.info("asset upload limit: %d", config.max_assets)
  end
  if config.max_bytes > 0 then
    util.info("asset byte limit: %d", config.max_bytes)
  end

  local ctx = new_context(config)
  local ok, run_err = pcall(run_sync, ctx)
  if not ok then
    ctx:error("sync failed: %s", tostring(run_err))
  end

  util.info(
    "summary planned=%d created=%d updated=%d skipped=%d assets=%d bytes=%d errors=%d",
    ctx.stats.planned,
    ctx.stats.created,
    ctx.stats.updated,
    ctx.stats.skipped,
    ctx.stats.assets_uploaded,
    ctx.stats.bytes_uploaded,
    ctx.stats.errors
  )

  return #ctx.errors == 0
end

return M
