local util = {}

function util.escape(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub("\n", "\\n")
  s = s:gsub("\t", "\\t")
  s = s:gsub('"', '\\"')
  s = s:gsub("'", "\\'")
  return '"' .. s .. '"'
end

function util.unescape(s)
  s = s:gsub("\\\\", "\\")
  s = s:gsub("\\n", "\n")
  s = s:gsub("\\t", "\t")
  s = s:gsub('\\"', '"')
  s = s:gsub("\\'", "'")
  return s
end

return util
