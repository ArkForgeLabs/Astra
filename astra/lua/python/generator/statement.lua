local ast = require("python.ast")
local util = require("python.util")
local stdlib = require("python.stdlib")

local function has_yield(body)
  for _, stmt in ipairs(body or {}) do
    if stmt.type == ast.YIELD then
      return true
    end
    if stmt.body and has_yield(stmt.body) then return true end
    if stmt.type == ast.IF then
      if has_yield(stmt.body) then return true end
      for _, elif in ipairs(stmt.elifs or {}) do
        if has_yield(elif.body) then return true end
      end
      if has_yield(stmt.or_else) then return true end
    end
    if (stmt.type == ast.WHILE or stmt.type == ast.FOR) and has_yield(stmt.body) then return true end
    if stmt.type == ast.TRY then
      if has_yield(stmt.body) then return true end
      for _, handler in ipairs(stmt.handlers or {}) do
        if has_yield(handler.body) then return true end
      end
      if has_yield(stmt.finally_body) then return true end
    end
  end
  return false
end

return function(ctx)
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
      ctx.push(ctx.indent() .. stmt.name .. " = " .. ctx.gen_expr(d) .. "(" .. stmt.name .. ")")
    end
  end

  local function flatten_targets(tt)
    local result = {}
    for _, t in ipairs(tt) do
      if type(t) == "string" then
        result[#result + 1] = t
      elseif t.type == ast.LIST or t.type == ast.TUPLE then
        for _, e in ipairs(t.elements) do
          result[#result + 1] = ctx.gen_subscript_target(e)
        end
      else
        result[#result + 1] = ctx.gen_subscript_target(t)
      end
    end
    return result
  end

  local stmt_handlers = {
    [ast.FUNCTION_DEF] = function(stmt)
      local has_decos = stmt.decorators and #stmt.decorators > 0
      local signature = gen_fn_sig(stmt.args, stmt.vararg, stmt.kwarg)
      local is_gen = has_yield(stmt.body)
      local function emit_body()
        for i, d in ipairs(stmt.args) do
          local default_val = stmt.defaults[i]
          if default_val then
            ctx.push(ctx.indent() .. "if " .. d .. " == nil then " .. d .. " = " .. ctx.gen_expr(default_val) .. " end")
          end
        end
        if stmt.vararg then
          ctx.push(ctx.indent() .. "local " .. stmt.vararg .. " = {...}")
        end
        if stmt.kwarg then
          ctx.push(ctx.indent() .. "local " .. stmt.kwarg .. " = {...}")
        end
        if is_gen then
          ctx.push(ctx.indent() .. "return coroutine.wrap(function()")
          ctx.with_indent(function()
            ctx.gen_body(stmt.body)
          end)
          ctx.push(ctx.indent() .. "end)")
        else
          ctx.gen_body(stmt.body)
        end
      end
      if has_decos then
        ctx.push(ctx.indent() .. "do")
        ctx.with_indent(function()
          ctx.push(ctx.indent() .. "local __fn")
          ctx.push(ctx.indent() .. "__fn = function(" .. signature .. ")")
          ctx.with_indent(function()
            emit_body()
          end)
          ctx.push(ctx.indent() .. "end")
          ctx.push(ctx.indent() .. stmt.name .. " = __fn")
        end)
        ctx.push(ctx.indent() .. "end")
        apply_decorators(stmt)
      else
        ctx.push(ctx.indent() .. "function " .. stmt.name .. "(" .. signature .. ")")
        ctx.with_indent(function()
          emit_body()
        end)
        ctx.push(ctx.indent() .. "end")
      end
    end,
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
      ctx.push(ctx.indent() .. "do")
      ctx.with_indent(function()
        ctx.push(ctx.indent() .. "local __class, __call, __mt")
        ctx.push(ctx.indent() .. "__mt = {}")
        ctx.push(ctx.indent() .. "__call = function(cls, ...)")
        ctx.push(ctx.indent() .. "    local mt = {}")
        ctx.push(ctx.indent() .. "    for k, v in pairs(__mt) do mt[k] = v end")
        ctx.push(ctx.indent() .. "    if not mt.__index then mt.__index = cls end")
        ctx.push(ctx.indent() .. "    local inst = setmetatable({}, mt)")
        ctx.push(ctx.indent() .. "    if cls.__init__ then cls.__init__(inst, ...) end")
        ctx.push(ctx.indent() .. "    return inst")
        ctx.push(ctx.indent() .. "end")
        if #stmt.bases == 0 then
          ctx.push(ctx.indent() .. "__class = setmetatable({}, {__call = __call})")
        else
          ctx.push(ctx.indent() .. "__class = setmetatable({}, {__index = " .. ctx.gen_expr(stmt.bases[1]) .. ", __call = __call})")
          ctx.push(ctx.indent() .. "__class.__py_base = " .. ctx.gen_expr(stmt.bases[1]))
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
              ctx.push(ctx.indent() .. "function __mt." .. lua_name .. "(" .. table.concat(s.args, ", ") .. ")")
            elseif is_static then
              ctx.push(ctx.indent() .. "function __class." .. s.name .. "(self" .. (#s.args > 0 and ", " or "") .. table.concat(s.args, ", ") .. ")")
            elseif is_classmethod then
              ctx.push(ctx.indent() .. "function __class." .. s.name .. "(cls" .. (#s.args > 1 and ", " or "") .. table.concat(s.args, ", ", 2) .. ")")
              ctx.push(ctx.indent() .. "    cls = __class")
            else
              ctx.push(ctx.indent() .. "function __class." .. s.name .. "(" .. table.concat(s.args, ", ") .. ")")
            end
            ctx.with_indent(function()
              ctx.gen_body(s.body)
            end)
            ctx.push(ctx.indent() .. "end")
          elseif s.type == ast.ASSIGN and #s.targets == 1 and s.targets[1].type == ast.NAME then
            local var = s.targets[1].id
            if var:match("^(.+)%.setter$") then
              local prop_name = var:match("^(.+)%.setter$")
              ctx.push(ctx.indent() .. "function __mt.__newindex(t, k, v) if k == " .. util.escape(prop_name) .. " then __class." .. prop_name .. "(t, v) else rawset(t, k, v) end end")
            else
              ctx.push(ctx.indent() .. "__class." .. s.targets[1].id .. " = " .. ctx.gen_expr(s.value))
            end
          elseif s.type == ast.EXPR_STMT then
            ctx.push(ctx.indent() .. ctx.gen_expr(s.expr))
          end
        end
        if next(property_getters) then
          ctx.push(ctx.indent() .. "__mt.__index = function(_, k)")
          ctx.with_indent(function()
            for name, _ in pairs(property_getters) do
              ctx.push(ctx.indent() .. "if k == " .. util.escape(name) .. " then return __class." .. name .. "(_, _) end")
            end
            ctx.push(ctx.indent() .. "return __class[k]")
          end)
          ctx.push(ctx.indent() .. "end")
        end
        ctx.push(ctx.indent() .. stmt.name .. " = __class")
      end)
      ctx.push(ctx.indent() .. "end")
      apply_decorators(stmt)
    end,
    [ast.IF] = function(stmt)
      ctx.push(ctx.indent() .. "if " .. ctx.gen_expr(stmt.test) .. " then")
      ctx.with_indent(function()
        ctx.gen_body(stmt.body)
      end)
      for _, elif in ipairs(stmt.elifs) do
        ctx.push(ctx.indent() .. "elseif " .. ctx.gen_expr(elif.test) .. " then")
        ctx.with_indent(function()
          ctx.gen_body(elif.body)
        end)
      end
      if stmt.or_else then
        ctx.push(ctx.indent() .. "else")
        ctx.with_indent(function()
          ctx.gen_body(stmt.or_else)
        end)
      end
      ctx.push(ctx.indent() .. "end")
    end,
    [ast.WHILE] = function(stmt)
      ctx.push(ctx.indent() .. "while " .. ctx.gen_expr(stmt.test) .. " do")
      ctx.with_indent(function()
        ctx.gen_body(stmt.body)
      end)
      ctx.push(ctx.indent() .. "::__continue::")
      ctx.push(ctx.indent() .. "end")
      if stmt.or_else then
        ctx.push(ctx.indent() .. "do")
        ctx.with_indent(function()
          ctx.gen_body(stmt.or_else)
        end)
        ctx.push(ctx.indent() .. "end")
      end
    end,
    [ast.FOR] = function(stmt)
      if stmt.is_range then
        local num_args = #stmt.range_args
        local range_start = ctx.gen_expr(stmt.range_args[1])
        local start_val = num_args == 1 and "0" or range_start
        local stop_val = ctx.gen_expr(stmt.range_args[num_args == 1 and 1 or 2])
        local step_val = num_args == 3 and ctx.gen_expr(stmt.range_args[3]) or "1"
        local target = stmt.targets[1]
        ctx.push(ctx.indent() .. "for " .. target .. " = " .. start_val .. ", " .. stop_val .. " - 1, " .. step_val .. " do")
      else
        local targets = flatten_targets(stmt.targets)
        if #targets == 1 then
          ctx.push(ctx.indent() .. "for _, " .. targets[1] .. " in ipairs(" .. ctx.gen_expr(stmt.iterator) .. ") do")
        else
          ctx.push(ctx.indent() .. "for _, __py_for_vars in ipairs(" .. ctx.gen_expr(stmt.iterator) .. ") do")
          ctx.with_indent(function()
            local var_names = {}
            local val_parts = {}
            for i, t in ipairs(targets) do
              var_names[#var_names + 1] = t
              val_parts[#val_parts + 1] = "__py_for_vars[" .. i .. "]"
            end
            ctx.push(ctx.indent() .. "local " .. table.concat(var_names, ", ") .. " = " .. table.concat(val_parts, ", "))
          end)
        end
      end
      ctx.with_indent(function()
        ctx.gen_body(stmt.body)
      end)
      ctx.push(ctx.indent() .. "::__continue::")
      ctx.push(ctx.indent() .. "end")
      if stmt.or_else then
        ctx.push(ctx.indent() .. "do")
        ctx.with_indent(function()
          ctx.gen_body(stmt.or_else)
        end)
        ctx.push(ctx.indent() .. "end")
      end
    end,
    [ast.TRY] = function(stmt)
      ctx.push(ctx.indent() .. "local __ok, __err = pcall(function()")
      ctx.with_indent(function()
        ctx.gen_body(stmt.body)
      end)
      ctx.push(ctx.indent() .. "end)")
      ctx.push(ctx.indent() .. "local __caught = false")
      for _, handler in ipairs(stmt.handlers) do
        if handler.type then
          local type_check
          if handler.type.type == ast.TUPLE then
            local checks = {}
            for _, t in ipairs(handler.type.elements) do
              checks[#checks + 1] = "__py_exception_match(__err, " .. ctx.gen_expr(t) .. ")"
            end
            type_check = "(" .. table.concat(checks, " or ") .. ")"
          else
            type_check = "__py_exception_match(__err, " .. ctx.gen_expr(handler.type) .. ")"
          end
          ctx.push(ctx.indent() .. "if not __ok and not __caught and type(__err) == \"table\" and " .. type_check .. " then")
          ctx.with_indent(function()
            if handler.name then
              ctx.push(ctx.indent() .. "local " .. handler.name .. " = __err")
            end
            ctx.push(ctx.indent() .. "__caught = true")
            ctx.gen_body(handler.body)
          end)
          ctx.push(ctx.indent() .. "end")
        else
          ctx.push(ctx.indent() .. "if not __ok and not __caught then")
          ctx.with_indent(function()
            ctx.push(ctx.indent() .. "__caught = true")
            ctx.gen_body(handler.body)
          end)
          ctx.push(ctx.indent() .. "end")
        end
      end
      if stmt.or_else then
        ctx.push(ctx.indent() .. "if __ok then")
        ctx.with_indent(function()
          ctx.gen_body(stmt.or_else)
        end)
        ctx.push(ctx.indent() .. "end")
      end
      if stmt.finally_body then
        ctx.push(ctx.indent() .. "do")
        ctx.with_indent(function()
          ctx.gen_body(stmt.finally_body)
        end)
        ctx.push(ctx.indent() .. "end")
      end
      ctx.push(ctx.indent() .. "if not __ok and not __caught then")
      ctx.with_indent(function()
        ctx.push(ctx.indent() .. "error(__err)")
      end)
      ctx.push(ctx.indent() .. "end")
    end,
    [ast.RETURN] = function(stmt)
      if stmt.value then
        if stmt.value.type == ast.TUPLE then
          local elements = {}
          for _, e in ipairs(stmt.value.elements) do
            elements[#elements + 1] = ctx.gen_expr(e)
          end
          ctx.push(ctx.indent() .. "return " .. table.concat(elements, ", "))
        else
          ctx.push(ctx.indent() .. "return " .. ctx.gen_expr(stmt.value))
        end
      else
        ctx.push(ctx.indent() .. "return")
      end
    end,
    [ast.ASSIGN] = function(stmt)
      local value = ctx.gen_expr(stmt.value)
      local target = stmt.targets[1]
      if target and target.type == ast.SUBSCRIPT and target.index.type == ast.SLICE then
        local obj = ctx.gen_expr(target.value)
        local lower = target.index.lower and ctx.gen_expr(target.index.lower) or "nil"
        local upper = target.index.upper and ctx.gen_expr(target.index.upper) or "nil"
        local step = target.index.step and ctx.gen_expr(target.index.step) or "nil"
        ctx.push(ctx.indent() .. "__py_slice_assign(" .. obj .. ", " .. lower .. ", " .. upper .. ", " .. step .. ", " .. value .. ")")
        return
      end
      local targets = flatten_targets(stmt.targets)
      if #targets == 1 then
        ctx.push(ctx.indent() .. targets[1] .. " = " .. value)
      else
        if stmt.chain then
          ctx.push(ctx.indent() .. targets[1] .. " = " .. value)
          for i = 2, #targets do
            ctx.push(ctx.indent() .. targets[i] .. " = " .. targets[1])
          end
        else
          ctx.push(ctx.indent() .. targets[1] .. ", " .. table.concat(targets, ", ", 2) .. " = " .. value)
        end
      end
    end,
    [ast.AUG_ASSIGN] = function(stmt)
      local target = ctx.gen_subscript_target(stmt.target)
      local value = ctx.gen_expr(stmt.value)
      local special = {
        ["**"] = function() return target .. " = (" .. target .. " ^ " .. value .. ")" end,
        ["//"] = function() return target .. " = math.floor(" .. target .. " / " .. value .. ")" end,
        ["|"] = function() return target .. " = __py_bor(" .. target .. ", " .. value .. ")" end,
        ["^"] = function() return target .. " = __py_bxor(" .. target .. ", " .. value .. ")" end,
        ["&"] = function() return target .. " = __py_band(" .. target .. ", " .. value .. ")" end,
        ["<<"] = function() return target .. " = __py_lshift(" .. target .. ", " .. value .. ")" end,
        [">>"] = function() return target .. " = __py_rshift(" .. target .. ", " .. value .. ")" end,
      }
      local gen = special[stmt.op]
      if gen then
        ctx.push(ctx.indent() .. gen())
      else
        ctx.push(ctx.indent() .. target .. " = " .. target .. " " .. stmt.op .. " " .. value)
      end
    end,
    [ast.EXPR_STMT] = function(stmt)
      if stmt.expr.type ~= ast.CONSTANT then
        ctx.push(ctx.indent() .. ctx.gen_expr(stmt.expr))
      end
    end,
    [ast.COMMENT] = function(stmt)
      local text = stmt.value
      if text == "" then
        ctx.push("")
      else
        for line in text:gmatch("[^\n]+") do
          ctx.push(ctx.indent() .. "-- " .. line)
        end
      end
    end,
    [ast.IMPORT] = function(stmt)
      for _, name in ipairs(stmt.names) do
        local parts = {}
        if name.name == "*" then
          parts[#parts + 1] = ctx.indent() .. "package.preload['" .. stmt.module .. "'] = function() end"
        else
          local alias = name.as_name or name.name
          local module_map = stdlib.map[name.name]
          if module_map then
            local fields = {}
            for k, v in pairs(module_map) do
              if k ~= "__module" then
                fields[#fields + 1] = "[" .. util.escape(k) .. "] = " .. v
              end
            end
            parts[#parts + 1] = ctx.indent() .. "local " .. alias .. " = {" .. table.concat(fields, ", ") .. "}"
          else
            parts[#parts + 1] = ctx.indent() .. "local " .. alias .. " = require('" .. name.name .. "')"
          end
        end
        ctx.push(table.concat(parts, "\n"))
      end
    end,
    [ast.IMPORT_FROM] = function(stmt)
      local target = stmt.module
      for _, name in ipairs(stmt.names) do
        if name.name == "*" then
          ctx.push(ctx.indent() .. "for k, v in pairs(require('" .. (stdlib.map[stmt.module] and stdlib.map[stmt.module].__module or stmt.module) .. "')) do _ENV[k] = v end")
        else
          local alias = name.as_name or name.name
          local inline = stdlib.map[stmt.module] and stdlib.map[stmt.module][name.name]
          if inline then
            ctx.push(ctx.indent() .. "local " .. alias .. " = " .. inline)
          else
            ctx.push(ctx.indent() .. "local " .. alias .. " = require('" .. (stdlib.map[stmt.module] and stdlib.map[stmt.module].__module or stmt.module) .. "')." .. name.name)
          end
        end
      end
    end,
    [ast.BREAK] = function(_)
      ctx.push(ctx.indent() .. "break")
    end,
    [ast.CONTINUE] = function(_)
      ctx.push(ctx.indent() .. "goto __continue")
    end,
    [ast.PASS] = function(_)
      ctx.push(ctx.indent() .. "-- pass")
    end,
    [ast.RAISE] = function(stmt)
      if stmt.exc then
        local exc_code = ctx.gen_expr(stmt.exc)
        if stmt.cause then
          ctx.push(ctx.indent() .. "local __exc = " .. exc_code .. "; __exc.__cause = " .. ctx.gen_expr(stmt.cause) .. "; error(__exc)")
        else
          ctx.push(ctx.indent() .. "error(" .. exc_code .. ")")
        end
      else
        ctx.push(ctx.indent() .. "error(\"\")")
      end
    end,
    [ast.ASSERT] = function(stmt)
      local test = ctx.gen_expr(stmt.test)
      if stmt.message then
        ctx.push(ctx.indent() .. "if not (" .. test .. ") then error(" .. ctx.gen_expr(stmt.message) .. ") end")
      else
        ctx.push(ctx.indent() .. "if not (" .. test .. ") then error(\"assertion failed\") end")
      end
    end,
    [ast.DEL] = function(stmt)
      local function gen_del(target)
        if target.type == ast.NAME then
          ctx.push(ctx.indent() .. target.id .. " = nil")
        elseif target.type == ast.SUBSCRIPT then
          local obj = ctx.gen_expr(target.value)
          local idx = ctx.gen_expr(target.index)
          if target.index.type == ast.CONSTANT and type(target.index.value) == "string" then
            ctx.push(ctx.indent() .. obj .. "[" .. idx .. "] = nil")
          else
            ctx.push(ctx.indent() .. "table.remove(" .. obj .. ", " .. idx .. " + 1)")
          end
        elseif target.type == ast.ATTRIBUTE then
          ctx.push(ctx.indent() .. ctx.gen_expr(target.value) .. "." .. target.attr .. " = nil")
        elseif target.type == ast.TUPLE then
          for _, e in ipairs(target.elements) do
            gen_del(e)
          end
        end
      end
      gen_del(stmt.target)
    end,
    [ast.NONLOCAL] = function(_)
      -- Lua upvalues handle this automatically.
    end,
    [ast.YIELD] = function(stmt)
      if stmt.value then
        ctx.push(ctx.indent() .. "coroutine.yield(" .. ctx.gen_expr(stmt.value) .. ")")
      else
        ctx.push(ctx.indent() .. "coroutine.yield()")
      end
    end,
    [ast.WITH] = function(stmt)
      for i, item in ipairs(stmt.items) do
        local ctx_var = "__ctx" .. i
        ctx.push(ctx.indent() .. "local " .. ctx_var .. " = " .. ctx.gen_expr(item.context_expr))
        if item.optional_vars then
          ctx.push(ctx.indent() .. "local " .. ctx.gen_expr(item.optional_vars) .. " = " .. ctx_var .. ":__enter__()")
        else
          ctx.push(ctx.indent() .. ctx_var .. ":__enter__()")
        end
      end
      ctx.push(ctx.indent() .. "local __ok, __err = pcall(function()")
      ctx.with_indent(function()
        ctx.gen_body(stmt.body)
      end)
      ctx.push(ctx.indent() .. "end)")
      for i = #stmt.items, 1, -1 do
        local ctx_var = "__ctx" .. i
        ctx.push(ctx.indent() .. "pcall(" .. ctx_var .. ".__exit__, " .. ctx_var .. ", __ok and nil or __err, nil, nil)")
      end
      ctx.push(ctx.indent() .. "if not __ok then")
      ctx.with_indent(function()
        ctx.push(ctx.indent() .. "error(__err)")
      end)
      ctx.push(ctx.indent() .. "end")
    end,
    [ast.ASYNC_FUNCTION_DEF] = function(stmt)
      local signature = gen_fn_sig(stmt.args, stmt.vararg, stmt.kwarg)
      ctx.push(ctx.indent() .. "function " .. stmt.name .. "(" .. signature .. ")")
      ctx.with_indent(function()
        for i, d in ipairs(stmt.args) do
          local default_val = stmt.defaults[i]
          if default_val then
            ctx.push(ctx.indent() .. "if " .. d .. " == nil then " .. d .. " = " .. ctx.gen_expr(default_val) .. " end")
          end
        end
        if stmt.vararg then
          ctx.push(ctx.indent() .. "local " .. stmt.vararg .. " = {...}")
        end
        if stmt.kwarg then
          ctx.push(ctx.indent() .. "local " .. stmt.kwarg .. " = {...}")
        end
        ctx.push(ctx.indent() .. "return spawn_task(function()")
        ctx.with_indent(function()
          ctx.gen_body(stmt.body)
        end)
        ctx.push(ctx.indent() .. "end)")
      end)
      ctx.push(ctx.indent() .. "end")
    end,
    [ast.GLOBAL] = function(_)
      -- Python's global declaration means "use the module-level variable".
      -- In Lua, globals are the default, so this is a no-op.
    end,
  }

  return stmt_handlers
end
