local util = {}

---@param input_str string
---@return string
function util.escape(input_str)
  input_str = input_str:gsub("\\", "\\\\")
  input_str = input_str:gsub("\n", "\\n")
  input_str = input_str:gsub("\t", "\\t")
  input_str = input_str:gsub('"', '\\"')
  input_str = input_str:gsub("'", "\\'")
  return '"' .. input_str .. '"'
end

---@param input_str string
---@return string
function util.unescape(input_str)
  input_str = input_str:gsub("\\\\", "\\")
  input_str = input_str:gsub("\\n", "\n")
  input_str = input_str:gsub("\\t", "\t")
  input_str = input_str:gsub('\\"', '"')
  input_str = input_str:gsub("\\'", "'")
  return input_str
end

---@param path string
---@return string
function util.dirname(path)
  local dir = path:match("^(.*/)") or path:match("^(.*\\)")
  return (dir and dir:sub(1, -2)) or "."
end

---@param name string
---@return string?
function util.get_top_level(name)
  return name:match("^([^.]+)")
end

return util
