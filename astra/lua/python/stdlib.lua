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

---@param tbl any[]
---@param start_val integer?
---@param end_val integer?
---@param step_val integer?
---@param values any[]
function stdlib.__py_slice_assign(tbl, start_val, end_val, step_val, values)
  local s = (start_val or 0) + 1
  local e = end_val or #tbl
  local num = e - (start_val or 0)
  if num < 0 then num = 0 end
  for _ = 1, num do
    table.remove(tbl, s)
  end
  for i = #values, 1, -1 do
    table.insert(tbl, s, values[i])
  end
end

---@param container any[]|string

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
stdlib.aliases = aliases
for k, v in pairs(aliases) do
  _G[k] = stdlib[v]
end

for _, k in ipairs({
  "__py_slice",
  "__py_slice_assign",
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

-- Inline function bodies for the generator (single source of truth)
stdlib.__inline_functions = {}

stdlib.__inline_functions.__py_slice = [====[
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
]====]

stdlib.__inline_functions.__py_slice_assign = [====[
local function __py_slice_assign(tbl, start, stop, step, values)
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
]====]
stdlib.__inline_functions.__py_in = [====[
local function __py_in(container, item)
  if type(container) == "table" then
    for _, __v in ipairs(container) do
      if __v == item then
        return true
      end
    end
    return false
  elseif type(container) == "string" then
    return string.find(container, item, 1, true) ~= nil
  end
  return false
end
]====]

stdlib.__inline_functions.__py_repeat = [====[
local function __py_repeat(val, n)
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
]====]

stdlib.__inline_functions.__py_range = [====[
local function __py_range(...)
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
]====]

stdlib.__inline_functions.__py_items = [====[
local function __py_items(container)
  local result = {}
  for k, v in pairs(container) do
    result[#result + 1] = { k, v }
  end
  return result
end
]====]

stdlib.__inline_functions.__py_super = [====[
local function __py_super(cls, self)
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
]====]

stdlib.__inline_functions.__py_getitem = [====[
local function __py_getitem(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end
]====]

stdlib.__inline_functions.__py_isinstance = [====[
local function __py_isinstance(obj, cls)
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
]====]

stdlib.__inline_functions.__py_issubclass = [====[
local function __py_issubclass(child, parent)
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
]====]

stdlib.__inline_functions.__py_call = [====[
local function __py_call(func, args, kwargs, params)
  if not params then
    local all = {}
    for _, a in ipairs(args) do
      all[#all + 1] = a
    end
    for _, kw in ipairs(kwargs) do
      all[#all + 1] = kw.value
    end
    return func(table.unpack(all))
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
]====]

-- Stdlib module name mappings (for import translation)
stdlib.map = {
  time = {
    __module = "datetime",
    perf_counter = [[function() return require("datetime").new():get_epoch_milliseconds() / 1000 end]],
    time = [[function() return require("datetime").new():get_epoch_milliseconds() / 1000 end]],
    sleep = [[function(secs) require("datetime").sleep(secs * 1000) end]],
  },
  sys = {
    __module = "sys",
    argv = [[setmetatable({}, {__index = function(t, k) return arg[k - 1] end, __len = function() return #arg + 1 end})]],
    stderr = [[io.stderr]],
    exit = [[os.exit]],
  },
  json = {
    __module = "serde",
    dumps = [[function(obj) return require("serde").json.encode(obj) end]],
    loads = [[function(s) return require("serde").json.decode(s) end]],
    dump = [[function(obj, fp) fp:write(require("serde").json.encode(obj)) end]],
    load = [[function(fp) return require("serde").json.decode(fp:read("*a")) end]],
  },
  math = {
    __module = "math",
    pi = [[math.pi]],
    e = [[math.exp(1)]],
    inf = [[math.huge]],
    nan = [[0/0]],
    sqrt = [[math.sqrt]],
    sin = [[math.sin]],
    cos = [[math.cos]],
    tan = [[math.tan]],
    asin = [[math.asin]],
    acos = [[math.acos]],
    atan = [[math.atan]],
    atan2 = [[function(y, x) return math.atan(y / x) end]],
    sinh = [[math.sinh]],
    cosh = [[math.cosh]],
    tanh = [[math.tanh]],
    ceil = [[math.ceil]],
    floor = [[math.floor]],
    trunc = [[function(x) return x // 1 end]],
    abs = [[math.abs]],
    fabs = [[math.abs]],
    fmod = [[math.fmod]],
    modf = [[math.modf]],
    exp = [[math.exp]],
    log = [[function(x, base) if base then return math.log(x) / math.log(base) else return math.log(x) end end]],
    log10 = [[math.log10]],
    log2 = [[function(x) return math.log(x) / math.log(2) end]],
    pow = [[function(x, y) return x ^ y end]],
    degrees = [[function(x) return x * 180 / math.pi end]],
    radians = [[function(x) return x * math.pi / 180 end]],
    hypot = [[math.hypot or (function(x, y) return math.sqrt(x * x + y * y) end)]],
    isclose = [[function(a, b, rel_tol, abs_tol) rel_tol = rel_tol or 1e-9; abs_tol = abs_tol or 0.0; return math.abs(a - b) <= rel_tol * math.max(math.abs(a), math.abs(b)) + abs_tol end]],
    gcd = [[function(a, b) while b ~= 0 do a, b = b, a % b end return math.abs(a) end]],
    ldexp = [[function(m, e) return m * (2 ^ e) end]],
    frexp = [[function(x) if x == 0 then return 0, 0 end local e = 0 local s = x < 0 and -1 or 1 x = math.abs(x) while x < 1 do x = x * 2 e = e - 1 end while x >= 2 do x = x / 2 e = e + 1 end return s * x, e end]],
    gamma = [[function(x) local g = 7 local c = {0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7} if x < 0.5 then return math.pi / (math.sin(math.pi * x) * gamma(1 - x)) end x = x - 1 local a = c[1] local t = x + g + 0.5 for i = 2, #c do a = a + c[i] / (x + i - 1) end return math.sqrt(2 * math.pi) * t ^ (x + 0.5) * math.exp(-t) * a end]],
    lgamma = [[function(x) return math.log(gamma(x)) end]],
    factorial = [[function(x) if x < 2 then return 1 end local r = 1 for i = 2, x do r = r * i end return r end]],
    isfinite = [[function(x) return x ~= math.huge and x ~= -math.huge and x == x end]],
    isinf = [[function(x) return x == math.huge or x == -math.huge end]],
    isnan = [[function(x) return x ~= x end]],
    copysign = [[function(x, y) return math.abs(x) * (y < 0 and -1 or 1) end]],
  },
  random = {
    __module = "random",
    random = [[math.random]],
    randint = [[function(a, b) return math.random(a, b) end]],
    uniform = [[function(a, b) return a + math.random() * (b - a) end]],
    choice = [[function(seq) return seq[math.random(#seq)] end]],
    shuffle = [[function(lst) local n = #lst for i = n, 2, -1 do local j = math.random(i) lst[i], lst[j] = lst[j], lst[i] end end]],
    seed = [[function(n) math.randomseed(n or os.time()) end]],
    randrange = [[function(start, stop, step) step = step or 1 local n = math.floor((stop - start) / step) return start + step * math.random(0, n) end]],
  },
  os = {
    __module = "os",
    getcwd = [[(require("python.stdlib.os")).getcwd]],
    chdir = [[(require("python.stdlib.os")).chdir]],
    listdir = [[(require("python.stdlib.os")).listdir]],
    mkdir = [[(require("python.stdlib.os")).mkdir]],
    makedirs = [[(require("python.stdlib.os")).makedirs]],
    remove = [[(require("python.stdlib.os")).remove]],
    rename = [[(require("python.stdlib.os")).rename]],
    environ = [[(require("python.stdlib.os")).environ]],
    sep = [[(require("python.stdlib.os")).sep]],
    pathsep = [[(require("python.stdlib.os")).pathsep]],
    linesep = [[(require("python.stdlib.os")).linesep]],
    path = [[(require("python.stdlib.os")).path]],
    system = [[(require("python.stdlib.os")).system]],
  },
  re = {
    __module = "re",
    search = [[(require("python.stdlib.re")).search]],
    match = [[(require("python.stdlib.re")).match]],
    fullmatch = [[(require("python.stdlib.re")).fullmatch]],
    findall = [[(require("python.stdlib.re")).findall]],
    split = [[(require("python.stdlib.re")).split]],
    sub = [[(require("python.stdlib.re")).sub]],
    subn = [[(require("python.stdlib.re")).subn]],
    escape = [[(require("python.stdlib.re")).escape]],
    compile = [[(require("python.stdlib.re")).compile]],
  },
  csv = {
    __module = "csv",
    reader = [[(require("python.stdlib.csv")).reader]],
    writer = [[(require("python.stdlib.csv")).writer]],
    DictReader = [[(require("python.stdlib.csv")).DictReader]],
    DictWriter = [[(require("python.stdlib.csv")).DictWriter]],
  },
}

return stdlib