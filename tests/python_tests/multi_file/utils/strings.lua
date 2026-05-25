local chr, ord, str, int = string.char, string.byte, tostring, tonumber
if not table.unpack then table.unpack = unpack end
__py_slice = function(tbl, start, stop, step)
  local start_pos, end_pos, step_val = start, stop, step or 1
  local n = #tbl
  if step_val > 0 then
    if start_pos == nil then
      start_pos = 0
    end
    if end_pos == nil then
      end_pos = n
    end
    start_pos = start_pos + 1
    local result = {}
    for i = start_pos, end_pos, step_val do
      result[#result + 1] = tbl[i]
    end
    return result
  elseif step_val < 0 then
    if start_pos == nil then
      start_pos = n - 1
    end
    if end_pos == nil then
      end_pos = -1
    end
    start_pos = start_pos + 1
    end_pos = end_pos + 1
    local result = {}
    for i = start_pos, end_pos, step_val do
      result[#result + 1] = tbl[i]
    end
    return result
  end
  return {}
end

__py_slice_assign = function(tbl, start, stop, step, values)
  local s = (start or 0) + 1
  local e = stop or #tbl
  local num = e - (start or 0)
  if num < 0 then num = 0 end
  for _ = 1, num do
    table.remove(tbl, s)
  end
  for i = #values, 1, -1 do
    table.insert(tbl, s, values[i])
  end
end

__py_getitem = function(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end

function reverse(s)
    return __py_slice(s, nil, nil, (- 1))
end
return { reverse = reverse }
