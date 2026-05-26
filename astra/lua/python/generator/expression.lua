local ast = require("python.ast")
local util = require("python.util")

local precedence = {
  ["**"] = 10,
  ["//"] = 9, ["*"] = 9,
  ["/"] = 8, ["%"] = 8,
  ["+"] = 7, ["-"] = 7,
  ["<<"] = 6, [">>"] = 6,
  ["&"] = 5,
  ["^"] = 4,
  ["|"] = 3,
}

local simple_types = {
  [ast.CONSTANT] = true,
  [ast.NAME] = true,
  [ast.CALL] = true,
  [ast.ATTRIBUTE] = true,
  [ast.SUPER] = true,
}

local function needs_paren(child, parent_op)
  if simple_types[child.type] then return false end
  if child.type == ast.BIN_OP then
    local child_prec = precedence[child.op] or 0
    local parent_prec = precedence[parent_op] or 0
    return child_prec < parent_prec
  end
  return true
end

return function(ctx)
  local binop_gen = {
    ["**"] = function(l, r) return l .. " ^ " .. r end,
    ["//"] = function(l, r, ln, rn)
      if needs_paren(ln, "//") then l = "(" .. l .. ")" end
      if needs_paren(rn, "//") then r = "(" .. r .. ")" end
      return "math.floor(" .. l .. " / " .. r .. ")"
    end,
    ["+"]  = function(l, r, ln, rn)
      if (ln.type == ast.CONSTANT and type(ln.value) == "string")
      or (rn.type == ast.CONSTANT and type(rn.value) == "string") then
        return l .. " .. " .. r
      end
      if needs_paren(ln, "+") then l = "(" .. l .. ")" end
      if needs_paren(rn, "+") then r = "(" .. r .. ")" end
      return l .. " + " .. r
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
      if needs_paren(ln, "*") then l = "(" .. l .. ")" end
      if needs_paren(rn, "*") then r = "(" .. r .. ")" end
      return l .. " * " .. r
    end,
    ["%"]  = function(l, r, ln, rn)
      if ln.type == ast.CONSTANT and type(ln.value) == "string" then
        return "string.format(" .. l .. ", " .. r .. ")"
      end
      if needs_paren(ln, "%") then l = "(" .. l .. ")" end
      if needs_paren(rn, "%") then r = "(" .. r .. ")" end
      return l .. " % " .. r
    end,
    ["|"]  = function(l, r) return "__py_bor(" .. l .. ", " .. r .. ")" end,
    ["^"]  = function(l, r) return "__py_bxor(" .. l .. ", " .. r .. ")" end,
    ["&"]  = function(l, r) return "__py_band(" .. l .. ", " .. r .. ")" end,
    ["<<"] = function(l, r) return "__py_lshift(" .. l .. ", " .. r .. ")" end,
    [">>"] = function(l, r) return "__py_rshift(" .. l .. ", " .. r .. ")" end,
  }

  ---@type table<string, fun(left: string, right: string): string>
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

  ---@param left string
  ---@param op string
  ---@param right string
  ---@return string
  local function compare_values(left, op, right)
    local handler = compare_handlers[op]
    if handler then
      return handler(left, right)
    end
    return left .. " " .. op .. " " .. right
  end

  ---@param expr ast_node
  ---@return string
  local function gen_list(expr)
    local elements = {}
    for _, e in ipairs(expr.elements) do
      elements[#elements + 1] = ctx.gen_expr(e)
    end
    return "{" .. table.concat(elements, ", ") .. "}"
  end

  ---@type table<string, fun(expr: ast_node): string>
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
      local l = ctx.gen_expr(expr.left)
      local r = ctx.gen_expr(expr.right)
      if needs_paren(expr.left, expr.op) then l = "(" .. l .. ")" end
      if needs_paren(expr.right, expr.op) then r = "(" .. r .. ")" end
      return l .. " " .. expr.op .. " " .. r
    end,
    [ast.UNARY_OP] = function(expr)
      if expr.op == "~" then
        return "__py_bnot(" .. ctx.gen_expr(expr.operand) .. ")"
      end
      return expr.op .. " " .. ctx.gen_expr(expr.operand)
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
          local arg_expr = ctx.gen_expr(expr.args[1])
          return "(getmetatable("
            .. arg_expr
            .. ") and getmetatable("
            .. arg_expr
            .. ").__len and getmetatable("
            .. arg_expr
            .. ").__len("
            .. arg_expr
            .. ") or #"
            .. arg_expr
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
        local params_str = (params and #params > 0)
          and ('{"' .. table.concat(params, '", "') .. '"}')
          or "nil"
        -- Two code paths for __py_call:
        -- - params table: known callee → keywords merged into positional slots by name (correct Python semantics)
        -- - nil: unknown callee → all positional + keyword values passed in declaration order (conservative fallback)
        return "__py_call("
          .. ctx.gen_expr(expr.func)
          .. ", {"
          .. table.concat(args, ", ")
          .. "}, {"
          .. table.concat(kw_parts, ", ")
          .. "}, "
          .. params_str
          .. ")"
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
      local idx = ctx.gen_index(expr)
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
      return "(function() local __walrus_value = " .. value .. "; " .. target .. " = __walrus_value; return __walrus_value end)()"
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
      return "(function()\n    local __res = {}"
        .. ctx.gen_comp_loops(function()
          return "    __res[#__res + 1] = " .. ctx.gen_expr(expr.element)
        end, expr.generators, 1)
        .. "\n    return __res\nend)()"
    end,
    [ast.SET_COMP] = function(expr)
      return "(function()\n    local __res = {}"
        .. ctx.gen_comp_loops(function()
          return "    __res[#__res + 1] = " .. ctx.gen_expr(expr.element)
        end, expr.generators, 1)
        .. "\n    return __res\nend)()"
    end,
    [ast.DICT_COMP] = function(expr)
      local key = ctx.gen_expr(expr.key)
      local val = ctx.gen_expr(expr.value)
      return "(function()\n    local __res = {}"
        .. ctx.gen_comp_loops(function()
          return "    __res[" .. key .. "] = " .. val
        end, expr.generators, 1)
        .. "\n    return __res\nend)()"
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
    [ast.AWAIT] = function(expr)
      return "(" .. ctx.gen_expr(expr.value) .. "):await()"
    end,
    [ast.YIELD] = function(expr)
      if expr.value then
        return "coroutine.yield(" .. ctx.gen_expr(expr.value) .. ")"
      end
      return "coroutine.yield()"
    end,
  }

  return setmetatable(expr_handlers, {
    __index = function(_, type)
      error("unknown expression type: " .. type)
    end,
  })
end
