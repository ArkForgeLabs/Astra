local chr, ord, str, int = string.char, string.byte, tostring, tonumber
if not table.unpack then table.unpack = unpack end
local function __py_slice(tbl, start, stop, step)
  local s, e, st = start, stop, step or 1
  local n = #tbl
  if st > 0 then
    if s == nil then
      s = 0
    end
    if e == nil then
      e = n
    end
    s = s + 1
    local result = {}
    for i = s, e, st do
      result[#result + 1] = tbl[i]
    end
    return result
  elseif st < 0 then
    if s == nil then
      s = n - 1
    end
    if e == nil then
      e = -1
    end
    s = s + 1
    e = e + 1
    local result = {}
    for i = s, e, st do
      result[#result + 1] = tbl[i]
    end
    return result
  end
  return {}
end

local function __py_getitem(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end

function reverse(s)
    return __py_slice(s, nil, nil, (- 1))
end
return { reverse = reverse }
