local util = {}

function util.escape(input_str)
  input_str = input_str:gsub("\\", "\\\\")
  input_str = input_str:gsub("\n", "\\n")
  input_str = input_str:gsub("\t", "\\t")
  input_str = input_str:gsub('"', '\\"')
  input_str = input_str:gsub("'", "\\'")
  return '"' .. input_str .. '"'
end

function util.unescape(input_str)
  input_str = input_str:gsub("\\\\", "\\")
  input_str = input_str:gsub("\\n", "\n")
  input_str = input_str:gsub("\\t", "\t")
  input_str = input_str:gsub('\\"', '"')
  input_str = input_str:gsub("\\'", "'")
  return input_str
end

return util
