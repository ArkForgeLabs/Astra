local ast = require("python.ast")
local util = require("python.util")

return function(ctx)
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

  local function gen_list(expr)
    local elements = {}
    for _, e in ipairs(expr.elements) do
      elements[#elements + 1] = ctx.gen_expr(e)
    end
    return "{" .. table.concat(elements, ", ") .. "}"
  end

  local function gen_index(expr)
    local idx = ctx.gen_expr(expr.index)
    if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
      return idx
    end
    return idx .. " + 1"
  end

  local expr_handlers = {
    [ast.CONSTANT] = function(expr)
      local v = expr.value
      if v == nil then return "nil" end
      if v == true then return "true" end
      if v == false then return "false" end
      if type(v) == "string" then return util.escape(v) end
      return tostring(v)
    end,
    [ast.NAME] = function(expr)
      return expr.id
    end,
    [ast.SUPER] = function(_)
      return "__py_super(__class, self)"
    end,
    [ast.BIN_OP] = function(expr)
      local handler = binop_gen[expr.op]
      if handler then
        return handler(ctx.gen_expr(expr.left), ctx.gen_expr(expr.right), expr.left, expr.right)
      end
      return "(" .. ctx.gen_expr(expr.left) .. " " .. expr.op .. " " .. ctx.gen_expr(expr.right) .. ")"
    end,
    [ast.UNARY_OP] = function(expr)
      return "(" .. expr.op .. " " .. ctx.gen_expr(expr.operand) .. ")"
    end,
    [ast.BOOL_OP] = function(expr)
      local vals = {}
      for _, v in ipairs(expr.values) do
        vals[#vals + 1] = ctx.gen_expr(v)
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
        return compare_values(ctx.gen_expr(expr.left), expr.ops[1], ctx.gen_expr(expr.comparators[1]))
      else
        local parts = {}
        local prev = ctx.gen_expr(expr.left)
        for i = 1, #expr.ops do
          local right = ctx.gen_expr(expr.comparators[i])
          parts[#parts + 1] = compare_values(prev, expr.ops[i], right)
          prev = right
        end
        return table.concat(parts, " and ")
      end
    end,
    [ast.CALL] = function(expr)
      if expr.func.type == ast.NAME and ctx.analysis and ctx.analysis.used_stdlib then
        local id = expr.func.id
        if id == "len" or id == "__py_len" then
          local a = ctx.gen_expr(expr.args[1])
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
          return "tonumber(" .. ctx.gen_expr(expr.args[1]) .. ")"
        end
      end
      if expr.func.type == ast.ATTRIBUTE and not (expr.keywords and #expr.keywords > 0) then
        if expr.func.attr == "items" and #expr.args == 0 then
          return "__py_items(" .. ctx.gen_expr(expr.func.value) .. ")"
        elseif expr.func.attr == "endswith" and #expr.args == 1 then
          if ctx.analysis and ctx.analysis.used_stdlib then
            return ctx.gen_expr(expr.func.value) .. ":sub(-#" .. ctx.gen_expr(expr.args[1]) .. ") == " .. ctx.gen_expr(expr.args[1])
          end
          return "__py_endswith(" .. ctx.gen_expr(expr.func.value) .. ", " .. ctx.gen_expr(expr.args[1]) .. ")"
        end
      end
      local args = {}
      for _, arg in ipairs(expr.args) do
        if arg.type == ast.STARRED then
          args[#args + 1] = "table.unpack(" .. ctx.gen_expr(arg.value) .. ")"
        else
          args[#args + 1] = ctx.gen_expr(arg)
        end
      end
      if
        expr.func.type == ast.ATTRIBUTE
        and expr.func.value.type == ast.NAME
        and not ctx.is_lua_module(expr.func.value.id)
        and not (expr.keywords and #expr.keywords > 0)
      then
        local obj = ctx.gen_expr(expr.func.value)
        return obj .. ":" .. expr.func.attr .. "(" .. table.concat(args, ", ") .. ")"
      end
      if expr.keywords and #expr.keywords > 0 then
        local kw_parts = {}
        for _, kw in ipairs(expr.keywords) do
          kw_parts[#kw_parts + 1] = "{arg=" .. util.escape(kw.arg) .. ", value=" .. ctx.gen_expr(kw.value) .. "}"
        end
        local params = expr._resolved_params
        if params and #params > 0 then
          return "__py_call("
            .. ctx.gen_expr(expr.func)
            .. ", {"
            .. table.concat(args, ", ")
            .. "}, {"
            .. table.concat(kw_parts, ", ")
            .. '}, {"'
            .. table.concat(params, '", "')
            .. '"})'
        end
        return "__py_call("
          .. ctx.gen_expr(expr.func)
          .. ", {"
          .. table.concat(args, ", ")
          .. "}, {"
          .. table.concat(kw_parts, ", ")
          .. "}, nil)"
      end
      if expr.func.type == ast.SUPER then
        return "__py_super(__class, self)"
      end
      return ctx.gen_expr(expr.func) .. "(" .. table.concat(args, ", ") .. ")"
    end,
    [ast.SUBSCRIPT] = function(expr)
      local target_obj = ctx.gen_expr(expr.value)
      if expr.index.type == ast.SLICE then
        local lower = expr.index.lower and ctx.gen_expr(expr.index.lower) or "nil"
        local upper = expr.index.upper and ctx.gen_expr(expr.index.upper) or "nil"
        local step = expr.index.step and ctx.gen_expr(expr.index.step) or "nil"
        return "__py_slice(" .. target_obj .. ", " .. lower .. ", " .. upper .. ", " .. step .. ")"
      end
      local idx = gen_index(expr)
      if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
        return target_obj .. "[" .. idx .. "]"
      end
      return "__py_getitem(" .. target_obj .. ", " .. idx .. ")"
    end,
    [ast.ATTRIBUTE] = function(expr)
      return ctx.gen_expr(expr.value) .. "." .. expr.attr
    end,
    [ast.LIST] = gen_list,
    [ast.SET] = gen_list,
    [ast.DICT] = function(expr)
      local items = {}
      for i = 1, #expr.keys do
        items[#items + 1] = "[" .. ctx.gen_expr(expr.keys[i]) .. "] = " .. ctx.gen_expr(expr.values[i])
      end
      return "{" .. table.concat(items, ", ") .. "}"
    end,
    [ast.TUPLE] = function(expr)
      local elements = {}
      for _, e in ipairs(expr.elements) do
        elements[#elements + 1] = ctx.gen_expr(e)
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
      local body_code = ctx.gen_expr(expr.body)
      if has_vararg and #expr.args > 0 and expr.args[#expr.args]:sub(1, 1) == "*" then
        local varname = expr.args[#expr.args]:sub(2)
        return "(function(" .. sig .. ") local " .. varname .. " = {...}; return " .. body_code .. " end)"
      end
      return "function(" .. sig .. ") return " .. body_code .. " end"
    end,
    [ast.WALRUS] = function(expr)
      local target = ctx.gen_expr(expr.target)
      local value = ctx.gen_expr(expr.value)
      return "(function() local __w = " .. value .. "; " .. target .. " = __w; return __w end)()"
    end,
    [ast.IF_EXPR] = function(expr)
      return "(function(...) if "
        .. ctx.gen_expr(expr.test)
        .. " then return "
        .. ctx.gen_expr(expr.body)
        .. " else return "
        .. ctx.gen_expr(expr.or_else)
        .. " end end)()"
    end,
    [ast.LIST_COMP] = function(expr)
      return "(function() local __res = {} "
        .. ctx.gen_comp_loops(function()
          return "__res[#__res + 1] = " .. ctx.gen_expr(expr.element) .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.SET_COMP] = function(expr)
      return "(function() local __res = {} "
        .. ctx.gen_comp_loops(function()
          return "__res[#__res + 1] = " .. ctx.gen_expr(expr.element) .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.DICT_COMP] = function(expr)
      local key = ctx.gen_expr(expr.key)
      local val = ctx.gen_expr(expr.value)
      return "(function() local __res = {} "
        .. ctx.gen_comp_loops(function()
          return "__res[" .. key .. "] = " .. val .. "; "
        end, expr.generators, 1)
        .. " return __res end)()"
    end,
    [ast.JOINED_STR] = function(expr)
      local parts = {}
      for _, v in ipairs(expr.values) do
        parts[#parts + 1] = ctx.gen_expr(v)
      end
      return table.concat(parts, " .. ")
    end,
    [ast.FORMATTED_VALUE] = function(expr)
      local val = ctx.gen_expr(expr.value)
      return "tostring(" .. val .. ")"
    end,
  }

  return expr_handlers
end
