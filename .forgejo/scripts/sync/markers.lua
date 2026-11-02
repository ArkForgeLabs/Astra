local M = {}

local function escape_pattern(value)
  return (tostring(value or ""):gsub("([^%w])", "%%%1"))
end

local function marker_pattern(namespace)
  return "<!%-%-%s*astra%-sync:" .. escape_pattern(namespace) .. ":[^>]-%-%->"
end

function M.validate_namespace(namespace)
  return type(namespace) == "string" and namespace:match("^[%w%-_%.]+$") ~= nil
end

function M.issue(namespace, source, number, hash)
  return string.format("<!-- astra-sync:%s:%s-issue:%d:%s -->", namespace, source, number, hash)
end

function M.comment(namespace, source, issue_number, comment_id, hash)
  return string.format("<!-- astra-sync:%s:%s-comment:%d:%d:%s -->", namespace, source, issue_number, comment_id, hash)
end

function M.strip(namespace, body)
  local s = tostring(body or "")
  s = s:gsub(marker_pattern(namespace), "")
  s = s:gsub("%s+$", "")
  return s
end

function M.set(namespace, body, marker)
  local clean = M.strip(namespace, body)
  if clean == "" then
    return marker
  end
  return clean .. "\n\n" .. marker
end

local function parse(namespace, body)
  local found = {}
  local s = tostring(body or "")
  for inner in s:gmatch("<!%-%-%s*astra%-sync:([^>]-)%-%->") do
    local trimmed = inner:gsub("^%s+", ""):gsub("%s+$", "")
    local ns, kind = trimmed:match("^([^:]+):(.+)$")
    if ns == namespace then
      local source, issue, hash = kind:match("^([%w%-]+)%-issue:(%d+):([0-9a-fA-F]+)$")
      if source then
        found[#found + 1] = {
          kind = "issue",
          source = source,
          issue = tonumber(issue),
          hash = hash:lower(),
        }
      else
        local csource, cissue, comment, chash = kind:match("^([%w%-]+)%-comment:(%d+):(%d+):([0-9a-fA-F]+)$")
        if csource then
          found[#found + 1] = {
            kind = "comment",
            source = csource,
            issue = tonumber(cissue),
            comment = tonumber(comment),
            hash = chash:lower(),
          }
        end
      end
    end
  end
  return found
end

function M.find_issue(namespace, body, source)
  for _, item in ipairs(parse(namespace, body)) do
    if item.kind == "issue" and item.source == source then
      return item
    end
  end
  return nil
end

function M.find_comment(namespace, body, source)
  for _, item in ipairs(parse(namespace, body)) do
    if item.kind == "comment" and item.source == source then
      return item
    end
  end
  return nil
end

function M.list(namespace, body)
  return parse(namespace, body)
end

return M
