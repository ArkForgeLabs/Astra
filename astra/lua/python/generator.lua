local ast = require("python.ast")
local util = require("python.util")
local stdlib_map = require("python.stdlib_map")
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

  -- Converts Python 0-based index to Lua 1-based by appending +1
  -- String keys skip the offset (e.g. dict["key"] stays as-is)
  local function gen_index(expr)
    local idx = gen_expr(expr.index)
    if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
      return idx
    end
    return idx .. " + 1"
  end

  gen_body = function(body)
    for _, s in ipairs(body) do
      gen_stmt(s)
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
    parts[#parts + 1] = "for _, " .. gen_clause.target .. " in ipairs(" .. gen_expr(gen_clause.iterator) .. ") do "
    for _, if_expr in ipairs(gen_clause.ifs or {}) do
      parts[#parts + 1] = "if " .. gen_expr(if_expr) .. " then "
    end
    parts[#parts + 1] = gen_comp_loops(inner_fn, generators, idx + 1)
    for _ in ipairs(gen_clause.ifs or {}) do
      parts[#parts + 1] = "end "
    end
    parts[#parts + 1] = "end "
    return table.concat(parts)
  end

  local compare_handlers = {
    ["!="] = function(left, right)
      return "(" .. left .. " ~= " .. right .. ")"
    end,
    ["is"] = function(left, right)
      return "(" .. left .. " == " .. right .. ")"
    end,
    ["is not"] = function(left, right)
      return "(" .. left .. " ~= " .. right .. ")"
    end,
    ["in"] = function(left, right)
      return "__py_in(" .. right .. ", " .. left .. ")"
    end,
    ["not in"] = function(left, right)
      return "not __py_in(" .. right .. ", " .. left .. ")"
    end,
  }
  local function compare_values(left, op, right)
    local h = compare_handlers[op]
    if h then
      return h(left, right)
    end
    return "(" .. left .. " " .. op .. " " .. right .. ")"
  end

  local function is_lua_module(name)
    local modules = { math = true, string = true, table = true, io = true, os = true, debug = true, coroutine = true }
    return modules[name]
  end

  local function gen_list(expr)
    local elements = {}
    for _, e in ipairs(expr.elements) do
      elements[#elements + 1] = gen_expr(e)
    end
    return "{" .. table.concat(elements, ", ") .. "}"
  end

  -- Expression dispatch table: each AST node type maps to a generator function
  -- that produces a Lua expression string from the AST node
  local expr_handlers = {
    [ast.CONSTANT] = function(expr)
      local v = expr.value
      if v == nil then
        return "nil"
      end
      if v == true then
        return "true"
      end
      if v == false then
        return "false"
      end
      if type(v) == "string" then
        return util.escape(v)
      end
      return tostring(v)
    end,
    [ast.NAME] = function(expr)
      return expr.id
    end,
    [ast.BIN_OP] = function(expr)
      local handler = binop_gen[expr.op]
      if handler then
        return handler(gen_expr(expr.left), gen_expr(expr.right), expr.left, expr.right)
      end
      return "(" .. gen_expr(expr.left) .. " " .. expr.op .. " " .. gen_expr(expr.right) .. ")"
    end,
    [ast.UNARY_OP] = function(expr)
      return "(" .. expr.op .. " " .. gen_expr(expr.operand) .. ")"
    end,
    [ast.BOOL_OP] = function(expr)
      local vals = {}
      for _, v in ipairs(expr.values) do
        vals[#vals + 1] = gen_expr(v)
      end
      return table.concat(vals, " " .. expr.op .. " ")
    end,
    [ast.COMPARE] = function(expr)
      if #expr.ops == 1 then
        if
          expr.left.type == ast.NAME
          and expr.left.id == "__name__"
          and expr.comparators[1].type == ast.CONSTANT
          and expr.comparators[1].value == "__main__"
          and expr.ops[1] == "=="
        then
          return "(MAIN_SCRIPT == CURRENT_SCRIPT)"
        end
        return compare_values(gen_expr(expr.left), expr.ops[1], gen_expr(expr.comparators[1]))
      else
        local parts = {}
        local prev = gen_expr(expr.left)
        for i = 1, #expr.ops do
          local right = gen_expr(expr.comparators[i])
          parts[#parts + 1] = compare_values(prev, expr.ops[i], right)
          prev = right
        end
        return table.concat(parts, " and ")
      end
    end,
    [ast.CALL] = function(expr)
      if expr.func.type == ast.NAME and analysis and analysis.used_stdlib then
        local id = expr.func.id
        if id == "len" or id == "__py_len" then
          local a = gen_expr(expr.args[1])
          return "(getmetatable("
            .. a
            .. ") and getmetatable("
            .. a
            .. ").__len and getmetatable("
            .. a
            .. ").__len("
            .. a
            .. ") or #"
            .. a
            .. ")"
        end
        if id == "int" or id == "__py_int" then
          return "tonumber(" .. gen_expr(expr.args[1]) .. ")"
        end
      end
      if expr.func.type == ast.SUPER then
        return "__py_super(__class, self)"
      end
      if expr.func.type == ast.ATTRIBUTE and not (expr.keywords and #expr.keywords > 0) then
        if expr.func.attr == "items" and #expr.args == 0 then
          return "__py_items(" .. gen_expr(expr.func.value) .. ")"
        elseif expr.func.attr == "endswith" and #expr.args == 1 then
          if analysis and analysis.used_stdlib then
            return gen_expr(expr.func.value) .. ":sub(-#" .. gen_expr(expr.args[1]) .. ") == " .. gen_expr(expr.args[1])
          end
          return "__py_endswith(" .. gen_expr(expr.func.value) .. ", " .. gen_expr(expr.args[1]) .. ")"
        end
      end
      local args = {}
      for _, arg in ipairs(expr.args) do
        if arg.type == ast.STARRED then
          args[#args + 1] = "table.unpack(" .. gen_expr(arg.value) .. ")"
        else
          args[#args + 1] = gen_expr(arg)
        end
      end
      if
        expr.func.type == ast.ATTRIBUTE
        and expr.func.value.type == ast.NAME
        and not is_lua_module(expr.func.value.id)
        and not (expr.keywords and #expr.keywords > 0)
      then
        local obj = gen_expr(expr.func.value)
        return obj .. ":" .. expr.func.attr .. "(" .. table.concat(args, ", ") .. ")"
      end
      if expr.keywords and #expr.keywords > 0 then
        local kw_parts = {}
        for _, kw in ipairs(expr.keywords) do
          kw_parts[#kw_parts + 1] = "{arg=" .. util.escape(kw.arg) .. ", value=" .. gen_expr(kw.value) .. "}"
        end
        local params = expr._resolved_params
        if params and #params > 0 then
          return "__py_call("
            .. gen_expr(expr.func)
            .. ", {"
            .. table.concat(args, ", ")
            .. "}, {"
            .. table.concat(kw_parts, ", ")
            .. '}, {"'
            .. table.concat(params, '", "')
            .. '"})'
        end
        return "__py_call("
          .. gen_expr(expr.func)
          .. ", {"
          .. table.concat(args, ", ")
          .. "}, {"
          .. table.concat(kw_parts, ", ")
          .. "}, nil)"
      end
      return gen_expr(expr.func) .. "(" .. table.concat(args, ", ") .. ")"
    end,
    [ast.SUBSCRIPT] = function(expr)
      local target_obj = gen_expr(expr.value)
      if expr.index.type == ast.SLICE then
        local lower = expr.index.lower and gen_expr(expr.index.lower) or "nil"
        local upper = expr.index.upper and gen_expr(expr.index.upper) or "nil"
        local step = expr.index.step and gen_expr(expr.index.step) or "nil"
        return "__py_slice(" .. target_obj .. ", " .. lower .. ", " .. upper .. ", " .. step .. ")"
      end
      local idx = gen_index(expr)
      if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
        return target_obj .. "[" .. idx .. "]"
      end
      return "__py_getitem(" .. target_obj .. ", " .. idx .. ")"
    end,
    [ast.ATTRIBUTE] = function(expr)
      return gen_expr(expr.value) .. "." .. expr.attr
    end,
    [ast.LIST] = gen_list,
    [ast.SET] = gen_list,
    [ast.DICT] = function(expr)
      local items = {}
      for i = 1, #expr.keys do
        items[#items + 1] = "[" .. gen_expr(expr.keys[i]) .. "] = " .. gen_expr(expr.values[i])
      end
      return "{" .. table.concat(items, ", ") .. "}"
    end,
    [ast.TUPLE] = function(expr)
      local elements = {}
      for _, e in ipairs(expr.elements) do
        elements[#elements + 1] = gen_expr(e)
      end
      return table.concat(elements, ", ")
    end,
    [ast.LAMBDA] = function(expr)
      local parts = {}
      local has_vararg = false
      for _, arg in ipairs(expr.args) do
        if arg:sub(1, 1) == "*" then
          parts[#parts + 1] = "..."
          has_vararg = true
        else
          parts[#parts + 1] = arg
        end
      end
      local sig = table.concat(parts, ", ")
      local body_code = gen_expr(expr.body)
      if has_vararg and #expr.args > 0 and expr.args[#expr.args]:sub(1, 1) == "*" then
        local varname = expr.args[#expr.args]:sub(2)
        return "(function(" .. sig .. ") local " .. varname .. " = {...}; return " .. body_code .. " end)"
      end
      return "function(" .. sig .. ") return " .. body_code .. " end"
    end,
    [ast.WALRUS] = function(expr)
      local target = gen_expr(expr.target)
      local value = gen_expr(expr.value)
      return "(function() local __w = " .. value .. "; " .. target .. " = __w; return __w end)()"
    end,
    [ast.IF_EXPR] = function(expr)
      return "(function(...) if "
        .. gen_expr(expr.test)
        .. " then return "
        .. gen_expr(expr.body)
        .. " else return "
        .. gen_expr(expr.or_else)
        .. " end end)()"
    end,
    [ast.LIST_COMP] = function(expr)
      return "(function() local __res = {} "
        .. gen_comp_loops(function()
          return "__res[#__res + 1] = " .. gen_expr(expr.element) .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.SET_COMP] = function(expr)
      return "(function() local __res = {} "
        .. gen_comp_loops(function()
          return "__res[#__res + 1] = " .. gen_expr(expr.element) .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.DICT_COMP] = function(expr)
      local key = gen_expr(expr.key)
      local val = gen_expr(expr.value)
      return "(function() local __res = {} "
        .. gen_comp_loops(function()
          return "__res[" .. key .. "] = " .. val .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.JOINED_STR] = function(expr)
      local parts = {}
      for _, v in ipairs(expr.values) do
        parts[#parts + 1] = gen_expr(v)
      end
      return table.concat(parts, " .. ")
    end,
    [ast.FORMATTED_VALUE] = function(expr)
      local val = gen_expr(expr.value)
      return "tostring(" .. val .. ")"
    end,
  }
  gen_expr = function(expr)
    local handler = expr_handlers[expr.type]
    if handler then
      return handler(expr)
    end
    error("unknown expression type: " .. expr.type)
  end

  local function flatten_targets(tt)
    local result = {}
    for _, t in ipairs(tt) do
      if t.type == ast.LIST or t.type == ast.TUPLE then
        for _, e in ipairs(t.elements) do
          result[#result + 1] = gen_subscript_target(e)
        end
      else
        result[#result + 1] = gen_subscript_target(t)
      end
    end
    return result
  end

  gen_subscript_target = function(expr)
    if expr.type == ast.SUBSCRIPT then
      local idx = gen_index(expr)
      if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
        return gen_expr(expr.value) .. "[" .. idx .. "]"
      end
      return gen_expr(expr.value) .. "[" .. idx .. "]"
    end
    return gen_expr(expr)
  end

  local function gen_fn_sig(args, vararg, kwarg)
    local parts = {}
    for _, a in ipairs(args) do
      parts[#parts + 1] = a
    end
    if vararg or kwarg then
      parts[#parts + 1] = "..."
    end
    return table.concat(parts, ", ")
  end

  local function apply_decorators(stmt)
    if not stmt.decorators then
      return
    end
    for i = #stmt.decorators, 1, -1 do
      local d = stmt.decorators[i]
      push(indent() .. stmt.name .. " = " .. gen_expr(d) .. "(" .. stmt.name .. ")")
    end
  end

  -- Statement dispatch table: each AST node type maps to a generator function
  -- that emits Lua code via push() and modifies the surrounding context
  local stmt_handlers = {
    [ast.FUNCTION_DEF] = function(stmt)
      local has_decos = stmt.decorators and #stmt.decorators > 0
      local signature = gen_fn_sig(stmt.args, stmt.vararg, stmt.kwarg)
      local function emit_body()
        for i, d in ipairs(stmt.args) do
          local default_val = stmt.defaults[i]
          if default_val then
            push(indent() .. "if " .. d .. " == nil then " .. d .. " = " .. gen_expr(default_val) .. " end")
          end
        end
        if stmt.vararg then
          push(indent() .. "local " .. stmt.vararg .. " = {...}")
        end
        if stmt.kwarg then
          push(indent() .. "local " .. stmt.kwarg .. " = {...}")
        end
        gen_body(stmt.body)
      end
      if has_decos then
        push(indent() .. "do")
        with_indent(function()
          push(indent() .. "local __fn")
          push(indent() .. "__fn = function(" .. signature .. ")")
          with_indent(function()
            emit_body()
          end)
          push(indent() .. "end")
          push(indent() .. stmt.name .. " = __fn")
        end)
        push(indent() .. "end")
        apply_decorators(stmt)
      else
        push(indent() .. "function " .. stmt.name .. "(" .. signature .. ")")
        with_indent(function()
          emit_body()
        end)
        push(indent() .. "end")
      end
    end,
    -- Emits a Lua metatable-based class with __call as constructor,
    -- dunder method mapping (__add, __len, etc.), @property/@staticmethod/@classmethod,
    -- and optional single-inheritance via __py_base
    [ast.CLASS_DEF] = function(stmt)
      local dunder_map = {
        __str__ = "__tostring",
        __len__ = "__len",
        __add__ = "__add",
        __sub__ = "__sub",
        __mul__ = "__mul",
        __div__ = "__div",
        __eq__ = "__eq",
        __lt__ = "__lt",
        __le__ = "__le",
        __call__ = "__call",
        __concat__ = "__concat",
        __unm__ = "__unm",
      }
      local property_getters = {}
      for _, s in ipairs(stmt.body) do
        if s.type == ast.FUNCTION_DEF then
          for _, d in ipairs(s.decorators or {}) do
            if d.type == ast.NAME and d.id == "property" then
              property_getters[s.name] = s.name
            end
          end
        end
      end

      push(indent() .. "do")
      with_indent(function()
        push(indent() .. "local __class, __call, __mt")
        push(indent() .. "__mt = {}")
        push(indent() .. "__call = function(cls, ...)")
        push(indent() .. "    local mt = {}")
        push(indent() .. "    for k, v in pairs(__mt) do mt[k] = v end")
        push(indent() .. "    if not mt.__index then mt.__index = cls end")
        push(indent() .. "    local inst = setmetatable({}, mt)")
        push(indent() .. "    if cls.__init__ then cls.__init__(inst, ...) end")
        push(indent() .. "    return inst")
        push(indent() .. "end")
        if #stmt.bases == 0 then
          push(indent() .. "__class = setmetatable({}, {__call = __call})")
        else
          push(indent() .. "__class = setmetatable({}, {__index = " .. gen_expr(stmt.bases[1]) .. ", __call = __call})")
          push(indent() .. "__class.__py_base = " .. gen_expr(stmt.bases[1]))
        end
        for _, s in ipairs(stmt.body) do
          if s.type == ast.FUNCTION_DEF then
            local lua_name = dunder_map[s.name]
            local is_static = false
            local is_classmethod = false
            for _, d in ipairs(s.decorators or {}) do
              if d.type == ast.NAME then
                if d.id == "staticmethod" then
                  is_static = true
                elseif d.id == "classmethod" then
                  is_classmethod = true
                end
              end
            end
            if lua_name and not is_static and not is_classmethod then
              push(indent() .. "function __mt." .. lua_name .. "(" .. table.concat(s.args, ", ") .. ")")
            elseif is_static then
              push(
                indent()
                  .. "function __class."
                  .. s.name
                  .. "(self"
                  .. (#s.args > 0 and ", " or "")
                  .. table.concat(s.args, ", ")
                  .. ")"
              )
            elseif is_classmethod then
              push(
                indent()
                  .. "function __class."
                  .. s.name
                  .. "(cls"
                  .. (#s.args > 1 and ", " or "")
                  .. table.concat(s.args, ", ", 2)
                  .. ")"
              )
              push(indent() .. "    cls = __class")
            else
              push(indent() .. "function __class." .. s.name .. "(" .. table.concat(s.args, ", ") .. ")")
            end
            with_indent(function()
              gen_body(s.body)
            end)
            push(indent() .. "end")
          elseif s.type == ast.ASSIGN and #s.targets == 1 and s.targets[1].type == ast.NAME then
            local var = s.targets[1].id
            if var:match("^(.+)%.setter$") then
              local prop_name = var:match("^(.+)%.setter$")
              push(
                indent()
                  .. "function __mt.__newindex(t, k, v) if k == "
                  .. util.escape(prop_name)
                  .. " then __class."
                  .. prop_name
                  .. "(t, v) else rawset(t, k, v) end end"
              )
            else
              push(indent() .. "__class." .. s.targets[1].id .. " = " .. gen_expr(s.value))
            end
          elseif s.type == ast.EXPR_STMT then
            push(indent() .. gen_expr(s.expr))
          end
        end
        if next(property_getters) then
          push(indent() .. "__mt.__index = function(_, k)")
          with_indent(function()
            for name, _ in pairs(property_getters) do
              push(indent() .. "if k == " .. util.escape(name) .. " then return __class." .. name .. "(_, _) end")
            end
            push(indent() .. "return __class[k]")
          end)
          push(indent() .. "end")
        end
        push(indent() .. stmt.name .. " = __class")
      end)
      push(indent() .. "end")
      apply_decorators(stmt)
    end,
    [ast.IF] = function(stmt)
      push(indent() .. "if " .. gen_expr(stmt.test) .. " then")
      with_indent(function()
        gen_body(stmt.body)
      end)
      for _, elif in ipairs(stmt.elifs) do
        push(indent() .. "elseif " .. gen_expr(elif.test) .. " then")
        with_indent(function()
          gen_body(elif.body)
        end)
      end
      if stmt.or_else then
        push(indent() .. "else")
        with_indent(function()
          gen_body(stmt.or_else)
        end)
      end
      push(indent() .. "end")
    end,
    [ast.WHILE] = function(stmt)
      push(indent() .. "while " .. gen_expr(stmt.test) .. " do")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "::__continue::")
      push(indent() .. "end")
      if stmt.or_else then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.or_else)
        end)
        push(indent() .. "end")
      end
    end,
    [ast.FOR] = function(stmt)
      if stmt.is_range then
        local num_args = #stmt.range_args
        local range_start = gen_expr(stmt.range_args[1])
        local start_val = num_args == 1 and "0" or range_start
        local stop_val = gen_expr(stmt.range_args[num_args == 1 and 1 or 2])
        local step = num_args == 3 and gen_expr(stmt.range_args[3]) or "1"
        push(
          indent() .. "for " .. stmt.targets[1] .. " = " .. start_val .. ", " .. stop_val .. " - 1, " .. step .. " do"
        )
      else
        if #stmt.targets == 1 then
          push(indent() .. "for _, " .. stmt.targets[1] .. " in ipairs(" .. gen_expr(stmt.iterator) .. ") do")
        else
          push(indent() .. "for _, __pair in ipairs(" .. gen_expr(stmt.iterator) .. ") do")
          indent_level = indent_level + 1
          local target_names = {}
          local target_exprs = {}
          for i, target in ipairs(stmt.targets) do
            target_names[i] = target
            target_exprs[i] = "__pair[" .. i .. "]"
          end
          push(indent() .. "local " .. table.concat(target_names, ", ") .. " = " .. table.concat(target_exprs, ", "))
          push("\n")
          indent_level = indent_level - 1
        end
      end
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "::__continue::")
      push(indent() .. "end")
      if stmt.or_else then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.or_else)
        end)
        push(indent() .. "end")
      end
    end,
    [ast.RETURN] = function(stmt)
      if stmt.value then
        push(indent() .. "return " .. gen_expr(stmt.value))
      else
        push(indent() .. "return")
      end
    end,
    [ast.ASSIGN] = function(stmt)
      if #stmt.targets == 1 and stmt.targets[1].type == ast.SUBSCRIPT and stmt.targets[1].index.type == ast.SLICE then
        local slice_index = stmt.targets[1].index
        local target_obj = gen_expr(stmt.targets[1].value)
        local lower = slice_index.lower and gen_expr(slice_index.lower) or "0"
        local upper = slice_index.upper and gen_expr(slice_index.upper) or "#" .. target_obj
        push(indent() .. "do")
        with_indent(function()
          push(indent() .. "local __src = " .. gen_expr(stmt.value))
          push(indent() .. "local __lo = " .. lower)
          push(indent() .. "for __i = __lo + 1, " .. upper .. " do " .. target_obj .. "[__i] = __src[__i - __lo] end")
        end)
        push(indent() .. "end")
        return
      end
      if #stmt.targets > 1 and stmt.chain then
        local val = gen_expr(stmt.value)
        push(indent() .. "do")
        with_indent(function()
          push(indent() .. "local __tmp = " .. val)
          for _, target in ipairs(stmt.targets) do
            push(indent() .. gen_subscript_target(target) .. " = __tmp")
          end
        end)
        push(indent() .. "end")
      else
        push(indent() .. table.concat(flatten_targets(stmt.targets), ", ") .. " = " .. gen_expr(stmt.value))
      end
    end,
    [ast.AUG_ASSIGN] = function(stmt)
      local t = gen_subscript_target(stmt.target)
      push(indent() .. t .. " = " .. gen_expr(stmt.target) .. " " .. stmt.op .. " " .. gen_expr(stmt.value))
    end,
    [ast.EXPR_STMT] = function(stmt)
      if stmt.expr.type == ast.CONSTANT and type(stmt.expr.value) == "string" then
        local text = stmt.expr.value
        if text:find("\n") then
          local safe = text:gsub("]]", "] ]")
          push(indent() .. "--[[ " .. safe .. " ]]")
        else
          push(indent() .. "-- " .. text)
        end
      elseif stmt.expr.type ~= ast.NAME then
        push(indent() .. gen_expr(stmt.expr))
      end
    end,
    [ast.GLOBAL] = function() end,
    [ast.PASS] = function() end,
    [ast.BREAK] = function()
      push(indent() .. "break")
    end,
    [ast.CONTINUE] = function()
      push(indent() .. "goto __continue")
    end,
    -- Simulates Python try/except via pcall:
    -- wraps the try body in a pcall, checks for errors via __py_ok,
    -- and binds the error message to the exception variable on match
    [ast.COMMENT] = function(stmt)
      local text = stmt.value
      if text == "" then
        push("")
      elseif text:find("\n") then
        local safe = text:gsub("]]", "] ]")
        push(indent() .. "--[[ " .. safe .. " ]]")
      else
        push(indent() .. "-- " .. text)
      end
    end,
    [ast.IMPORT] = function(stmt)
      for _, entry in ipairs(stmt.names) do
        local local_name = entry.as_name or entry.name
        local mapped = stdlib_map[entry.name]
        if mapped then
          local fields = {}
          for name, expr in pairs(mapped) do
            fields[#fields + 1] = "  " .. name .. " = " .. expr
          end
          push(indent() .. "local " .. local_name .. " = {\n" .. table.concat(fields, ",\n") .. "\n" .. indent() .. "}")
        else
          push(indent() .. "local " .. local_name .. " = require(" .. util.escape(entry.name) .. ")")
        end
      end
    end,
    [ast.IMPORT_FROM] = function(stmt)
      for _, entry in ipairs(stmt.names) do
        if entry.name == "*" then
          push(indent() .. "do local _m = require(" .. util.escape(stmt.module) .. "); for _k,_v in pairs(_m) do _G[_k] = _v end end")
        else
          local local_name = entry.as_name or entry.name
          local mapped = stdlib_map[stmt.module]
          if mapped and mapped[entry.name] then
            push(indent() .. "local " .. local_name .. " = " .. mapped[entry.name])
          else
            push(indent() .. "local " .. local_name .. " = require(" .. util.escape(stmt.module) .. ")." .. entry.name)
          end
        end
      end
    end,
    [ast.TRY] = function(stmt)
      push(indent() .. "local __py_ok, __py_err = pcall(function()")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "end)")
      if #stmt.handlers > 0 then
        push(indent() .. "if not __py_ok then")
        with_indent(function()
          for _, h in ipairs(stmt.handlers) do
            if h.name then
              push(indent() .. "local " .. h.name .. " = __py_err")
            end
            gen_body(h.body)
          end
        end)
        push(indent() .. "end")
      end
      if stmt.finally_body then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.finally_body)
        end)
        push(indent() .. "end")
      end
    end,
  }
  gen_stmt = function(stmt)
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
