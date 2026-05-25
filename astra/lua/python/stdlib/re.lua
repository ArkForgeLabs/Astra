local validation = require("validation")

local function create_match(pattern, string, ct, anchored)
  return {
    group = function(self, n)
      if n == nil or n == 0 then return ct[1] end
      return ct[n + 1]
    end,
    groups = function(self)
      local results = {}
      for i = 2, #ct do
        results[#results + 1] = ct[i]
      end
      return table.unpack(results)
    end,
    start = function(self, n)
      return 1
    end,
    ["end"] = function(self, n)
      return #string
    end,
  }
end

local function get_captures(regex, string)
  local captures = regex:captures(string)
  if captures and captures[1] then
    return captures[1]
  end
  return nil
end

local re_mod = {}

function re_mod.search(pattern, string)
  local regex = validation.regex(pattern)
  local ct = get_captures(regex, string)
  if ct then
    return create_match(pattern, string, ct)
  end
  return nil
end

function re_mod.match(pattern, string)
  local regex = validation.regex("^" .. pattern)
  local ct = get_captures(regex, string)
  if ct then
    return create_match("^" .. pattern, string, ct, true)
  end
  return nil
end

function re_mod.fullmatch(pattern, string)
  local regex = validation.regex("^" .. pattern .. "$")
  local ct = get_captures(regex, string)
  if ct then
    return create_match("^" .. pattern .. "$", string, ct, true)
  end
  return nil
end

function re_mod.findall(pattern, string)
  local regex = validation.regex(pattern)
  local result = {}
  local offset = 1
  while offset <= #string do
    local captures = regex:captures(string:sub(offset))
    if captures and captures[1] then
      local ct = captures[1]
      local match_str = ct[1]
      if #ct > 1 then
        local groups = {}
        for i = 2, #ct do
          groups[#groups + 1] = ct[i]
        end
        result[#result + 1] = groups
      else
        result[#result + 1] = match_str
      end
      offset = offset + #match_str
    else
      offset = offset + 1
    end
  end
  return result
end

function re_mod.split(pattern, string)
  local regex = validation.regex(pattern)
  local parts = {}
  local last_end = 1
  while last_end <= #string do
    local captures = regex:captures(string:sub(last_end))
    if captures and captures[1] then
      local ct = captures[1]
      local match_str = ct[1]
      local idx = string:find(match_str, last_end, true)
      if idx then
        parts[#parts + 1] = string:sub(last_end, idx - 1)
        last_end = idx + #match_str
      else
        break
      end
    else
      break
    end
  end
  parts[#parts + 1] = string:sub(last_end)
  return parts
end

function re_mod.sub(pattern, repl, string, count)
  count = count or 1
  local regex = validation.regex(pattern)
  local current_string = string
  local replaced = 0
  local offset = 1
  while replaced < count and offset <= #current_string do
    local captures = regex:captures(current_string:sub(offset))
    if captures and captures[1] then
      local ct = captures[1]
      local match_str = ct[1]
      local idx = current_string:find(match_str, offset, true)
      if idx then
        if type(repl) == "string" then
          current_string = current_string:sub(1, idx - 1) .. repl .. current_string:sub(idx + #match_str)
          offset = idx + #repl
        elseif type(repl) == "function" then
          local replacement = repl(ct[1])
          current_string = current_string:sub(1, idx - 1) .. tostring(replacement) .. current_string:sub(idx + #match_str)
          offset = idx + #tostring(replacement)
        end
        replaced = replaced + 1
      else
        break
      end
    else
      break
    end
  end
  return current_string, replaced
end

function re_mod.subn(pattern, repl, string)
  local result, n = re_mod.sub(pattern, repl, string, math.huge)
  return result, n
end

function re_mod.escape(pattern)
  return pattern:gsub("([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1")
end

function re_mod.compile(pattern)
  return {
    search = function(self, s) return re_mod.search(pattern, s) end,
    match = function(self, s) return re_mod.match(pattern, s) end,
    split = function(self, s) return re_mod.split(pattern, s) end,
    sub = function(self, repl, s) return re_mod.sub(pattern, repl, s) end,
    findall = function(self, s) return re_mod.findall(pattern, s) end,
  }
end

return re_mod
