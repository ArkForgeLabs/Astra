local stdlib = {}

-- Platform compatibility
if not table.unpack then table.unpack = unpack end

-- Built-in type aliases
_G.chr = string.char
_G.ord = string.byte
_G.str = tostring

function stdlib.__py_len(x)
  local mt = getmetatable(x)
  if mt and mt.__len then return mt.__len(x) end
  return #x
end
_G.len = stdlib.__py_len

function stdlib.__py_int(x)
  return type(x) == "number" and math.floor(x) or tonumber(x)
end
_G.int = stdlib.__py_int

function stdlib.__py_slice(tbl, start, stop, step)
  local s, e, st = start, stop, step or 1
  local n = #tbl
  if st > 0 then
    if s == nil then s = 0 end
    if e == nil then e = n end
    s = s + 1
    local result = {}
    for i = s, e, st do result[#result + 1] = tbl[i] end
    return result
  elseif st < 0 then
    if s == nil then s = n - 1 end
    if e == nil then e = -1 end
    s = s + 1
    e = e + 1
    local result = {}
    for i = s, e, st do result[#result + 1] = tbl[i] end
    return result
  end
  return {}
end
_G.__py_slice = stdlib.__py_slice

function stdlib.__py_in(container, item)
  if type(container) == "table" then
    for _, __v in ipairs(container) do if __v == item then return true end end
    return false
  elseif type(container) == "string" then
    return string.find(container, item, 1, true) ~= nil
  end
  return false
end
_G.__py_in = stdlib.__py_in

function stdlib.__py_repeat(val, n)
  local res = {}
  if type(val) == "table" then
    for _ = 1, n do
      for _, __v in ipairs(val) do
        res[#res + 1] = __v
      end
    end
  else
    for _ = 1, n do
      res[#res + 1] = val
    end
  end
  return res
end
_G.__py_repeat = stdlib.__py_repeat

function stdlib.__py_range(...)
  local start, stop, step
  if select("#", ...) == 1 then start, stop, step = 0, (...), 1
  elseif select("#", ...) == 2 then start, stop, step = (...), select(2, ...), 1
  else start, stop, step = (...), select(2, ...), select(3, ...) end
  local result = {}
  if step > 0 then for i = start, stop - 1, step do result[#result + 1] = i end
  end
  if step < 0 then for i = start, stop + 1, step do result[#result + 1] = i end
  end
  return result
end
_G.range = stdlib.__py_range
_G.__py_range = stdlib.__py_range

function stdlib.__py_getitem(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end
_G.__py_getitem = stdlib.__py_getitem

function stdlib.__py_items(container)
  local result = {}
  for k, v in pairs(container) do
    result[#result + 1] = {k, v}
  end
  return result
end
_G.__py_items = stdlib.__py_items

function stdlib.__py_endswith(str, suffix)
  return string.sub(str, -#suffix) == suffix
end
_G.__py_endswith = stdlib.__py_endswith

function stdlib.__py_super(cls, self)
  local base = cls.__py_base
  if not base then error("super(): no base class") end
  return setmetatable({}, {__index = function(_, k)
    local fn = base[k]
    if fn then return function(...) return fn(self, ...) end end
  end})
end
_G.__py_super = stdlib.__py_super

function stdlib.__py_isinstance(obj, cls)
  if type(cls) == "table" then
    local mt = getmetatable(obj)
    while mt do
      if mt.__index == cls then return true end
      if mt.__index and mt.__index.__py_base then
        local base = mt.__index
        while base do
          if base == cls then return true end
          base = base.__py_base
        end
      end
      mt = getmetatable(mt)
    end
    return false
  elseif type(cls) == "function" then
    if cls == int then return type(obj) == "number" end
    if cls == str or cls == chr then return type(obj) == "string" end
    return false
  end
  return false
end
_G.isinstance = stdlib.__py_isinstance
_G.__py_isinstance = stdlib.__py_isinstance

function stdlib.__py_issubclass(child, parent)
  if type(child) ~= "table" then return false end
  local base = child.__py_base or (getmetatable(child) or {}).__index
  while base do
    if base == parent then return true end
    base = base.__py_base
  end
  return false
end
_G.issubclass = stdlib.__py_issubclass
_G.__py_issubclass = stdlib.__py_issubclass

_G.__py_fn_params = {}

function stdlib.__py_call(func, args, kwargs)
  local params = __py_fn_params[func]
  if not params then
    local all = {}
    for _, a in ipairs(args) do all[#all + 1] = a end
    for _, kw in ipairs(kwargs) do all[#all + 1] = kw.value end
    return func(table.unpack(all))
  end
  local merged = {}
  for i = 1, #params do merged[i] = args[i] end
  for _, kw in ipairs(kwargs) do
    for j, name in ipairs(params) do
      if kw.arg == name then
        merged[j] = kw.value
        break
      end
    end
  end
  return func(table.unpack(merged, 1, #params))
end
_G.__py_call = stdlib.__py_call

return stdlib
