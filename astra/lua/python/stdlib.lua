local stdlib = {}

-- Platform compatibility (Lua 5.1 fallback)
if not table.unpack then
  ---@diagnostic disable-next-line: deprecated
  table.unpack = unpack
end

-- Built-in type aliases
_G.chr = string.char
_G.ord = string.byte
_G.str = tostring

---@param value any
---@return integer
function stdlib.__py_len(value)
  local mt = getmetatable(value)
  if mt and mt.__len then
    return mt.__len(value)
  end
  return #value
end

---@param value any
---@return integer?
function stdlib.__py_int(value)
  return type(value) == "number" and math.floor(value) or tonumber(value)
end

---@param tbl any[]
---@param start_val integer?
---@param end_val integer?
---@param step_val integer?
---@return any[]
function stdlib.__py_slice(tbl, start_val, end_val, step_val)
  local s, e, st = start_val, end_val, step_val or 1
  local length = #tbl
  if st > 0 then
    if s == nil then
      s = 0
    end
    if e == nil then
      e = length
    end
    s = s + 1
    local result = {}
    for i = s, e, st do
      result[#result + 1] = tbl[i]
    end
    return result
  elseif st < 0 then
    if s == nil then
      s = length - 1
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

---@param container any[]|string
---@param item any
---@return boolean
function stdlib.__py_in(container, item)
  if type(container) == "table" then
    for _, __elem in ipairs(container) do
      if __elem == item then
        return true
      end
    end
    return false
  elseif type(container) == "string" then
    return string.find(container, item, 1, true) ~= nil
  end
  return false
end

---@param val any
---@param count integer
---@return any[]
function stdlib.__py_repeat(val, count)
  local result = {}
  if type(val) == "table" then
    for _ = 1, count do
      for _, __elem in ipairs(val) do
        result[#result + 1] = __elem
      end
    end
  else
    for _ = 1, count do
      result[#result + 1] = val
    end
  end
  return result
end

---@param ... integer
---@return integer[]
function stdlib.__py_range(...)
  local start, stop, step
  if select("#", ...) == 1 then
    start, stop, step = 0, (...), 1
  elseif select("#", ...) == 2 then
    start, stop, step = (...), select(2, ...), 1
  else
    start, stop, step = (...), select(2, ...), select(3, ...)
  end
  local result = {}
  if step > 0 then
    for i = start, stop - 1, step do
      result[#result + 1] = i
    end
  end
  if step < 0 then
    for i = start, stop + 1, step do
      result[#result + 1] = i
    end
  end
  return result
end

---@param container any[]|string
---@param index integer
---@return any
function stdlib.__py_getitem(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end

---@param container table
---@return any[][]
function stdlib.__py_items(container)
  local result = {}
  for k, v in pairs(container) do
    result[#result + 1] = { k, v }
  end
  return result
end

---@param str string
---@param suffix string
---@return boolean
function stdlib.__py_endswith(str, suffix)
  return string.sub(str, -#suffix) == suffix
end

---@param cls table
---@param self table
---@return table
function stdlib.__py_super(cls, self)
  local base = cls.__py_base
  if not base then
    error("super(): no base class")
  end
  return setmetatable({}, {
    __index = function(_, k)
      local fn = base[k]
      if fn then
        return function(...)
          return fn(self, ...)
        end
      end
    end,
  })
end

---@param obj any
---@param cls table|function
---@return boolean
function stdlib.__py_isinstance(obj, cls)
  if type(cls) == "table" then
    local mt = getmetatable(obj)
    while mt do
      if mt.__index == cls then
        return true
      end
      if mt.__index and mt.__index.__py_base then
        local base = mt.__index
        while base do
          if base == cls then
            return true
          end
          base = base.__py_base
        end
      end
      mt = getmetatable(mt)
    end
    return false
  elseif type(cls) == "function" then
    ---@diagnostic disable-next-line: undefined-global
    if cls == int then
      return type(obj) == "number"
    end
    if cls == str or cls == chr then
      return type(obj) == "string"
    end
    return false
  end
  return false
end

---@param child table?
---@param parent table
---@return boolean
function stdlib.__py_issubclass(child, parent)
  if type(child) ~= "table" then
    return false
  end
  local base = child.__py_base or (getmetatable(child) or {}).__index
  while base do
    if base == parent then
      return true
    end
    base = base.__py_base
  end
  return false
end

---@param func function
---@param args any[]
---@param kwargs {arg:string, value:any}[]
---@param params? string[]
---@return any
function stdlib.__py_call(func, args, kwargs, params)
  if not params then
    local all_args = {}
    for _, arg in ipairs(args) do
      all_args[#all_args + 1] = arg
    end
    for _, kw in ipairs(kwargs) do
      all_args[#all_args + 1] = kw.value
    end
    return func(table.unpack(all_args))
  end
  local merged = {}
  for i = 1, #params do
    merged[i] = args[i]
  end
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

local aliases = {
  len = "__py_len",
  int = "__py_int",
  range = "__py_range",
  isinstance = "__py_isinstance",
  issubclass = "__py_issubclass",
}
for k, v in pairs(aliases) do
  _G[k] = stdlib[v]
end
for _, k in ipairs({
  "__py_slice",
  "__py_in",
  "__py_repeat",
  "__py_range",
  "__py_getitem",
  "__py_items",
  "__py_endswith",
  "__py_super",
  "__py_isinstance",
  "__py_issubclass",
  "__py_call",
}) do
  _G[k] = stdlib[k]
end

return stdlib
