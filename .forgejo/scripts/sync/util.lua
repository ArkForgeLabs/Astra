local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.env(name, default)
  local value = astra_internal__getenv(name)
  if value == nil or value == "" then
    return default
  end
  return value
end

function M.parse_bool(value, default)
  if value == nil then
    return default
  end
  if type(value) == "boolean" then
    return value
  end
  local s = tostring(value):lower()
  if s == "1" or s == "true" or s == "yes" or s == "on" then
    return true
  end
  if s == "0" or s == "false" or s == "no" or s == "off" then
    return false
  end
  return default
end

function M.parse_args(argv)
  local args = {}
  argv = argv or {}
  local i = 1
  while i <= #argv do
    local item = argv[i]
    if item == "--dry-run" then
      args.dry_run = true
    elseif item == "--bootstrap" then
      args.bootstrap = true
    elseif item:sub(1, 2) == "--" then
      local body = item:sub(3)
      local separator = body:find("=", 1, true)
      local key = body:gsub("%-", "_")
      if separator then
        args[body:sub(1, separator - 1):gsub("%-", "_")] = body:sub(separator + 1)
      else
        local value = argv[i + 1]
        if value == nil or value:sub(1, 2) == "--" then
          args[key] = true
        else
          args[key] = value
          i = i + 1
        end
      end
    end
    i = i + 1
  end
  return args
end

function M.normalize_title(title)
  return trim(tostring(title or "")):gsub("%s+", " "):lower()
end

function M.normalize_body(body)
  local s = tostring(body or "")
  s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
  s = s:gsub("[ \t]+\n", "\n")
  s = s:gsub("\n\n\n+", "\n\n")
  return trim(s)
end

function M.normalize_label(name)
  return trim(tostring(name or "")):lower()
end

function M.normalize_release_body(body)
  return M.normalize_body(M.strip_full_changelog(body))
end

function M.issue_labels(issue)
  local names = {}
  local seen = {}
  for _, label in ipairs(issue and issue.labels or {}) do
    local name = type(label) == "table" and label.name or tostring(label)
    if name and name ~= "" and not seen[name] then
      names[#names + 1] = name
      seen[name] = true
    end
  end
  table.sort(names)
  return names
end

function M.milestone_title(issue)
  local milestone = issue and issue.milestone
  if type(milestone) == "table" then
    return milestone.title
  end
  return nil
end

function M.issue_hash(issue, body)
  local labels = table.concat(M.issue_labels(issue), "\0")
  local milestone = M.milestone_title(issue) or ""
  local state = tostring(issue and issue.state or "open")
  return M.sha256(table.concat({
    "title",
    tostring(issue and issue.title or ""),
    "body",
    M.normalize_body(body),
    "state",
    state,
    "labels",
    labels,
    "milestone",
    milestone,
  }, "\0"))
end

function M.comment_hash(body)
  return M.sha256("comment\0" .. M.normalize_body(body))
end

function M.decide_direction(fj_hash, fj_marker_hash, gh_hash, gh_marker_hash)
  if fj_hash == gh_hash then
    return "none"
  end
  local fj_changed = fj_marker_hash == nil or fj_marker_hash ~= fj_hash
  local gh_changed = gh_marker_hash == nil or gh_marker_hash ~= gh_hash
  if fj_changed and not gh_changed then
    return "forgejo"
  end
  if gh_changed and not fj_changed then
    return "github"
  end
  return "forgejo"
end

function M.strip_full_changelog(body)
  local lines = {}
  local s = tostring(body or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in (s .. "\n"):gmatch("(.-)\n") do
    if not line:match("^%*%*Full Changelog%*%*:") and not line:match("^Full Changelog:") then
      lines[#lines + 1] = line
    end
  end
  return trim(table.concat(lines, "\n"))
end

function M.extract_full_changelog(body)
  local lines = {}
  local s = tostring(body or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in (s .. "\n"):gmatch("(.-)\n") do
    if line:match("^%*%*Full Changelog%*%*:") or line:match("^Full Changelog:") then
      lines[#lines + 1] = trim(line)
    end
  end
  return table.concat(lines, "\n")
end

function M.merge_full_changelog(body, existing)
  local changelog = M.extract_full_changelog(existing)
  local clean = M.strip_full_changelog(body)
  if changelog == "" then
    return clean
  end
  if clean == "" then
    return changelog
  end
  return clean .. "\n\n" .. changelog
end

local unreserved = {}
for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"):gmatch(".") do
  unreserved[c] = true
end

function M.url_encode(value)
  return (
    tostring(value or ""):gsub(".", function(c)
      if unreserved[c] then
        return c
      end
      return string.format("%%%02X", string.byte(c))
    end)
  )
end

function M.build_query(base, params)
  local parts = {}
  for key, value in pairs(params or {}) do
    if value ~= nil then
      parts[#parts + 1] = M.url_encode(key) .. "=" .. M.url_encode(value)
    end
  end
  if #parts == 0 then
    return base
  end
  table.sort(parts)
  local separator = base:find("?", 1, true) and "&" or "?"
  return base .. separator .. table.concat(parts, "&")
end

function M.sha256(value)
  return astra_internal__hash("sha2_256", tostring(value or ""))
end

function M.select_fields(payload, fields)
  local out = {}
  for _, field in ipairs(fields) do
    if payload[field] ~= nil then
      out[field] = payload[field]
    end
  end
  return out
end

local function format_message(fmt, ...)
  if select("#", ...) == 0 then
    return tostring(fmt)
  end
  local ok, message = pcall(string.format, fmt, ...)
  if ok then
    return message
  end
  return tostring(fmt)
end

function M.info(fmt, ...)
  print("[info] " .. format_message(fmt, ...))
end

function M.warn(fmt, ...)
  print("[warn] " .. format_message(fmt, ...))
end

function M.plan(fmt, ...)
  print("[plan] " .. format_message(fmt, ...))
end

function M.error(fmt, ...)
  print("[error] " .. format_message(fmt, ...))
end

return M
