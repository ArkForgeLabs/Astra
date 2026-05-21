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

return util
