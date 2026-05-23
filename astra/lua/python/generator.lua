local ast = require("python.ast")
local util = require("python.util")
local stdlib_map = require("python.stdlib_map")
local expression_gen = require("python.expression_generator")
local statement_gen = require("python.statement_generator")
local generator = {}
local stdlib_inline = {}

stdlib_inline.__py_slice = [====[
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

stdlib_inline.__py_in = [====[
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

stdlib_inline.__py_repeat = [====[
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

stdlib_inline.__py_range = [====[
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

stdlib_inline.__py_items = [====[
local function __py_items(container)
  local result = {}
  for k, v in pairs(container) do
    result[#result + 1] = { k, v }
  end
  return result
end
]====]

stdlib_inline.__py_super = [====[
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

stdlib_inline.__py_getitem = [====[
local function __py_getitem(container, index)
  if type(container) == "string" then
    return string.sub(container, index, index)
  end
  return container[index]
end
]====]

stdlib_inline.__py_isinstance = [====[
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

stdlib_inline.__py_issubclass = [====[
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

stdlib_inline.__py_call = [====[
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
local binop_gen = {
  ["**"] = function(l, r) return "(" .. l .. " ^ " .. r .. ")" end,
  ["//"] = function(l, r) return "math.floor(" .. l .. " / " .. r .. ")" end,
  ["+"]  = function(l, r, ln, rn)
    if (ln.type == ast.CONSTANT and type(ln.value) == "string")
    or (rn.type == ast.CONSTANT and type(rn.value) == "string") then
      return "(" .. l .. " .. " .. r .. ")"
    end
    return "(" .. l .. " + " .. r .. ")"
  end,
  ["*"]  = function(l, r, ln, rn)
    if ln.type == ast.CONSTANT and type(ln.value) == "string" then
      return "string.rep(" .. l .. ", " .. r .. ")"
    end
    if rn.type == ast.CONSTANT and type(rn.value) == "string" then
      return "string.rep(" .. r .. ", " .. l .. ")"
    end
    if ln.type == ast.LIST or ln.type == ast.SET
    or rn.type == ast.LIST or rn.type == ast.SET then
      return "__py_repeat(" .. l .. ", " .. r .. ")"
    end
    return "(" .. l .. " * " .. r .. ")"
  end,
  ["%"]  = function(l, r, ln, rn)
    if ln.type == ast.CONSTANT and type(ln.value) == "string" then
      return "string.format(" .. l .. ", " .. r .. ")"
    end
    return "(" .. l .. " % " .. r .. ")"
  end,
}

---@param prog ast.Program
---@param analysis? {used_stdlib?: table<string,boolean>, has_kwargs?: boolean}
---@return string
function generator.generate(prog, analysis)
  analysis = analysis or {}
  local indent_level = 0
  local parts = {}

  local function indent()
    return string.rep("    ", indent_level)
  end
  local function push(s)
    parts[#parts + 1] = s
  end

  -- pre-declare recursive functions for Lua 5.1
  local gen_body, with_indent, gen_expr, gen_stmt
  local gen_comp_loops
  local gen_subscript_target

  local ctx = {
    push = push,
    indent = indent,
    analysis = analysis,
    indent_level = indent_level,
  }

  -- Converts Python 0-based index to Lua 1-based by appending +1
  -- String keys skip the offset (e.g. dict["key"] stays as-is)
  local function gen_index(expr)
    local idx = ctx.gen_expr(expr.index)
    if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
      return idx
    end
    return idx .. " + 1"
  end

  gen_body = function(body)
    for _, s in ipairs(body) do
      ctx.gen_stmt(s)
    end
  end

  with_indent = function(fn)
    indent_level = indent_level + 1
    fn()
    indent_level = indent_level - 1
  end

  -- Recursively emits for/if clauses for list/set/dict comprehensions
  -- inner_fn produces the element expression, generators are the for/if clauses
  gen_comp_loops = function(inner_fn, generators, idx)
    if idx > #generators then
      return inner_fn()
    end
    local gen_clause = generators[idx]
    local parts = {}
    parts[#parts + 1] = "for _, " .. gen_clause.target .. " in ipairs(" .. ctx.gen_expr(gen_clause.iterator) .. ") do "
    for _, if_expr in ipairs(gen_clause.ifs or {}) do
      parts[#parts + 1] = "if " .. ctx.gen_expr(if_expr) .. " then "
    end
    parts[#parts + 1] = gen_comp_loops(inner_fn, generators, idx + 1)
    for _ in ipairs(gen_clause.ifs or {}) do
      parts[#parts + 1] = "end "
    end
    parts[#parts + 1] = "end "
    return table.concat(parts)
  end

  local function is_lua_module(name)
    local modules = { math = true, string = true, table = true, io = true, os = true, debug = true, coroutine = true }
    return modules[name]
  end

  -- Populate ctx with shared helpers before loading sub-modules
  ctx.gen_body = gen_body
  ctx.with_indent = with_indent
  ctx.gen_index = gen_index
  ctx.is_lua_module = is_lua_module
  ctx.gen_comp_loops = gen_comp_loops

  -- Load expression and statement handler tables
  local expr_handlers = expression_gen(ctx)
  local stmt_handlers = statement_gen(ctx)

  ctx.gen_expr = function(expr)
    local handler = expr_handlers[expr.type]
    if handler then
      return handler(expr)
    end
    error("unknown expression type: " .. expr.type)
  end

  ctx.gen_subscript_target = function(expr)
    if expr.type == ast.SUBSCRIPT then
      local idx = gen_index(expr)
      if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
        return ctx.gen_expr(expr.value) .. "[" .. idx .. "]"
      end
      return ctx.gen_expr(expr.value) .. "[" .. idx .. "]"
    end
    return ctx.gen_expr(expr)
  end

  ctx.gen_stmt = function(stmt)
    local handler = stmt_handlers[stmt.type]
    if handler then
      handler(stmt)
    else
      error("unknown statement type: " .. stmt.type)
    end
  end

  -- generate user code first
  gen_body(prog.body)
  local user_body = table.concat(parts, "\n")

  -- runtime helpers preamble
  local used = (analysis or {}).used_stdlib
  local preamble_parts = {}
  local stdlib_order = {
    "__py_slice",
    "__py_in",
    "__py_repeat",
    "__py_range",
    "__py_items",
    "__py_super",
    "__py_getitem",
    "__py_isinstance",
    "__py_issubclass",
    "__py_call",
  }
  if used then
    preamble_parts[#preamble_parts + 1] = "local chr, ord, str, int = string.char, string.byte, tostring, tonumber"
    preamble_parts[#preamble_parts + 1] = "if not table.unpack then table.unpack = unpack end"
    for _, name in ipairs(stdlib_order) do
      if used[name] then
        preamble_parts[#preamble_parts + 1] = stdlib_inline[name]
      end
    end
  else
    preamble_parts[#preamble_parts + 1] = "require('python.stdlib')"
  end

  local preamble = table.concat(preamble_parts, "\n")
  return preamble .. "\n" .. user_body
end

-- ============================================================
-- Public API
-- ============================================================

return generator
