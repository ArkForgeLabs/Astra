local ast = require("python.ast")
local util = require("python.util")

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
      if t.type == ast.LIST or t.type == ast.TUPLE then
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
        ctx.gen_body(stmt.body)
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
            local unpack_parts = {}
            for i, t in ipairs(targets) do
              unpack_parts[#unpack_parts + 1] = t .. " = __py_for_vars[" .. i .. "]"
            end
            ctx.push(ctx.indent() .. "local " .. table.concat(unpack_parts, ", "))
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
      for _, handler in ipairs(stmt.handlers) do
        if handler.name then
          ctx.push(ctx.indent() .. "if not __ok then")
          ctx.with_indent(function()
            ctx.push(ctx.indent() .. "local " .. handler.name .. " = __err")
            ctx.gen_body(handler.body)
          end)
          ctx.push(ctx.indent() .. "end")
        else
          ctx.push(ctx.indent() .. "if not __ok then")
          ctx.with_indent(function()
            ctx.gen_body(handler.body)
          end)
          ctx.push(ctx.indent() .. "end")
        end
      end
      if stmt.finally_body then
        ctx.push(ctx.indent() .. "do")
        ctx.with_indent(function()
          ctx.gen_body(stmt.finally_body)
        end)
        ctx.push(ctx.indent() .. "end")
      end
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
      ctx.push(ctx.indent() .. ctx.gen_subscript_target(stmt.target) .. " = " .. ctx.gen_subscript_target(stmt.target) .. " " .. stmt.op .. " " .. ctx.gen_expr(stmt.value))
    end,
    [ast.EXPR_STMT] = function(stmt)
      ctx.push(ctx.indent() .. ctx.gen_expr(stmt.expr))
    end,
    [ast.COMMENT] = function(stmt)
      local text = stmt.value
      if text == "" then
        ctx.push("")
      else
        for _, line in ipairs(text:split("\n")) do
          ctx.push(ctx.indent() .. "--[[" .. line .. "]]")
        end
      end
    end,
    [ast.IMPORT] = function(stmt)
      for _, name in ipairs(stmt.names) do
        local parts = {}
        if name.name == "*" then
          parts[#parts + 1] = ctx.indent() .. "package.preload['" .. stmt.module .. "'] = function() end"
        end
        ctx.push(table.concat(parts, "\n"))
      end
    end,
    [ast.IMPORT_FROM] = function(stmt)
      local target = stmt.module
      for _, name in ipairs(stmt.names) do
        if name.name == "*" then
          ctx.push(ctx.indent() .. "for k, v in pairs(require('" .. stmt.module .. "')) do _ENV[k] = v end")
        else
          local alias = name.as_name or name.name
          ctx.push(ctx.indent() .. "local " .. alias .. " = require('" .. stmt.module .. "')." .. name.name)
        end
      end
    end,
    [ast.PASS] = function(_)
      ctx.push(ctx.indent() .. "-- pass")
    end,
    [ast.GLOBAL] = function(stmt)
      local names = {}
      for _, n in ipairs(stmt.names) do
        names[#names + 1] = n
      end
      ctx.push(ctx.indent() .. "local " .. table.concat(names, ", "))
    end,
  }

  return stmt_handlers
end
