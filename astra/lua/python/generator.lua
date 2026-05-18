local generator = {}
function generator.generate(ast)
  local indent_level = 0
  local parts = {}

  local function indent()
    return string.rep("    ", indent_level)
  end
  local function push(s)
    parts[#parts + 1] = s
  end

  -- pre-declare recursive functions for Lua 5.1
  local gen_body, with_indent, gen_str, gen_expr, gen_stmt
  local gen_comprehension_loops, gen_dictcomp_loops

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

  gen_str = function(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\t", "\\t")
    s = s:gsub('"', '\\"')
    s = s:gsub("'", "\\'")
    return '"' .. s .. '"'
  end

  gen_comprehension_loops = function(element, generators, idx)
    if idx > #generators then
      return "__res[#__res + 1] = " .. gen_expr(element) .. "; "
    end
    local g = generators[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iterator) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_comprehension_loops(element, generators, idx + 1)
    for _ in ipairs(g.ifs or {}) do
      code = code .. "end "
    end
    code = code .. "end "
    return code
  end
  gen_dictcomp_loops = function(key, val, generators, idx)
    if idx > #generators then
      return "__res[" .. key .. "] = " .. val .. "; "
    end
    local g = generators[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iterator) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_dictcomp_loops(key, val, generators, idx + 1)
    for _ in ipairs(g.ifs or {}) do
      code = code .. "end "
    end
    code = code .. "end "
    return code
  end

  local function compare_values(l, op, r)
    if op == "!=" then
      return "(" .. l .. " ~= " .. r .. ")"
    elseif op == "is" then
      return "(" .. l .. " == " .. r .. ")"
    elseif op == "is not" then
      return "(" .. l .. " ~= " .. r .. ")"
    elseif op == "in" then
      return "__py_in(" .. r .. ", " .. l .. ")"
    elseif op == "not in" then
      return "not __py_in(" .. r .. ", " .. l .. ")"
    else
      return "(" .. l .. " " .. op .. " " .. r .. ")"
    end
  end

  gen_expr = function(expr)
    if expr.type == "Constant" then
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
        return gen_str(v)
      end
      return tostring(v)
    elseif expr.type == "Name" then
      return expr.id
    elseif expr.type == "BinOp" then
      local l = gen_expr(expr.left)
      local r = gen_expr(expr.right)
      if expr.op == "**" then
        return "(" .. l .. " ^ " .. r .. ")"
      elseif expr.op == "//" then
        return "math.floor(" .. l .. " / " .. r .. ")"
      elseif
        expr.op == "+"
        and (
          (expr.left.type == "Constant" and type(expr.left.value) == "string")
          or (expr.right.type == "Constant" and type(expr.right.value) == "string")
        )
      then
        return "(" .. l .. " .. " .. r .. ")"
      elseif expr.op == "*" then
        if expr.left.type == "Constant" and type(expr.left.value) == "string" then
          return "string.rep(" .. l .. ", " .. r .. ")"
        end
        if expr.right.type == "Constant" and type(expr.right.value) == "string" then
          return "string.rep(" .. r .. ", " .. l .. ")"
        end
        if
          expr.left.type == "List"
          or expr.left.type == "Set"
          or expr.right.type == "List"
          or expr.right.type == "Set"
        then
          return "__py_repeat(" .. l .. ", " .. r .. ")"
        end
        return "(" .. l .. " * " .. r .. ")"
      else
        return "(" .. l .. " " .. expr.op .. " " .. r .. ")"
      end
    elseif expr.type == "UnaryOp" then
      return "(" .. expr.op .. " " .. gen_expr(expr.operand) .. ")"
    elseif expr.type == "BoolOp" then
      local vals = {}
      for _, v in ipairs(expr.values) do
        vals[#vals + 1] = gen_expr(v)
      end
      return table.concat(vals, " " .. expr.op .. " ")
    elseif expr.type == "Compare" then
      if #expr.ops == 1 then
        return compare_values(gen_expr(expr.left), expr.ops[1], gen_expr(expr.comparators[1]))
      else
        local parts = {}
        local prev = gen_expr(expr.left)
        for i = 1, #expr.ops do
          local r = gen_expr(expr.comparators[i])
          parts[#parts + 1] = compare_values(prev, expr.ops[i], r)
          prev = r
        end
        return table.concat(parts, " and ")
      end
    elseif expr.type == "Call" then
      local args = {}
      for _, a in ipairs(expr.args) do
        args[#args + 1] = gen_expr(a)
      end
      if expr.keywords and #expr.keywords > 0 then
        local keyword_parts = {}
        for _, kw in ipairs(expr.keywords) do
          keyword_parts[#keyword_parts + 1] = "[" .. gen_str(kw.arg) .. "] = " .. gen_expr(kw.value)
        end
        args[#args + 1] = "{" .. table.concat(keyword_parts, ", ") .. "}"
      end
      return gen_expr(expr.func) .. "(" .. table.concat(args, ", ") .. ")"
    elseif expr.type == "Subscript" then
      local v = gen_expr(expr.value)
      if expr.index.type == "Slice" then
        local lower = expr.index.lower and gen_expr(expr.index.lower) or "nil"
        local upper = expr.index.upper and gen_expr(expr.index.upper) or "nil"
        local step = expr.index.step and gen_expr(expr.index.step) or "nil"
        return "__py_slice(" .. v .. ", " .. lower .. ", " .. upper .. ", " .. step .. ")"
      end
      local idx = gen_expr(expr.index)
      if expr.index.type == "Constant" and type(expr.index.value) == "string" then
        return v .. "[" .. idx .. "]"
      end
      return v .. "[" .. idx .. " + 1]"
    elseif expr.type == "Attribute" then
      return gen_expr(expr.value) .. "." .. expr.attr
    elseif expr.type == "List" then
      local elements = {}
      for _, e in ipairs(expr.elements) do
        elements[#elements + 1] = gen_expr(e)
      end
      return "{" .. table.concat(elements, ", ") .. "}"
    elseif expr.type == "Dict" then
      local items = {}
      for i = 1, #expr.keys do
        items[#items + 1] = "[" .. gen_expr(expr.keys[i]) .. "] = " .. gen_expr(expr.values[i])
      end
      return "{" .. table.concat(items, ", ") .. "}"
    elseif expr.type == "Set" then
      local elements = {}
      for _, e in ipairs(expr.elements) do
        elements[#elements + 1] = gen_expr(e)
      end
      return "{" .. table.concat(elements, ", ") .. "}"
    elseif expr.type == "Tuple" then
      local elements = {}
      for _, e in ipairs(expr.elements) do
        elements[#elements + 1] = gen_expr(e)
      end
      return table.concat(elements, ", ")
    elseif expr.type == "Lambda" then
      return "function(" .. table.concat(expr.args, ", ") .. ") return " .. gen_expr(expr.body) .. " end"
    elseif expr.type == "Walrus" then
      local t = gen_expr(expr.target)
      local v = gen_expr(expr.value)
      return "(function() local __w = " .. v .. "; " .. t .. " = __w; return __w end)()"
    elseif expr.type == "IfExpr" then
      return "(function(...) if "
        .. gen_expr(expr.test)
        .. " then return "
        .. gen_expr(expr.body)
        .. " else return "
        .. gen_expr(expr.or_else)
        .. " end end)()"
    elseif expr.type == "ListComp" or expr.type == "SetComp" then
      return "(function() local __res = {} "
        .. gen_comprehension_loops(expr.element, expr.generators, 1)
        .. " return __res end)()"
    elseif expr.type == "DictComp" then
      local key = gen_expr(expr.key)
      local val = gen_expr(expr.value)
      return "(function() local __res = {} "
        .. gen_dictcomp_loops(key, val, expr.generators, 1)
        .. " return __res end)()"
    end
    error("unknown expression type: " .. expr.type)
  end

  local function flatten_targets(tt)
    local result = {}
    for _, t in ipairs(tt) do
      if t.type == "List" or t.type == "Tuple" then
        for _, e in ipairs(t.elements) do
          result[#result + 1] = gen_expr(e)
        end
      else
        result[#result + 1] = gen_expr(t)
      end
    end
    return result
  end

  gen_stmt = function(stmt)
    if stmt.type == "FunctionDef" then
      push(indent() .. "function " .. stmt.name .. "(" .. table.concat(stmt.args, ", ") .. ")")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "end")
    elseif stmt.type == "If" then
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
    elseif stmt.type == "While" then
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
    elseif stmt.type == "For" then
      if stmt.is_range then
        local n = #stmt.range_args
        local s = gen_expr(stmt.range_args[1])
        local st = n == 1 and "0" or s
        local sp = gen_expr(stmt.range_args[n == 1 and 1 or 2])
        local step = n == 3 and gen_expr(stmt.range_args[3]) or "1"
        push(indent() .. "for " .. stmt.target .. " = " .. st .. ", " .. sp .. " - 1, " .. step .. " do")
      else
        push(indent() .. "for _, " .. stmt.target .. " in ipairs(" .. gen_expr(stmt.iterator) .. ") do")
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
    elseif stmt.type == "Return" then
      if stmt.value then
        push(indent() .. "return " .. gen_expr(stmt.value))
      else
        push(indent() .. "return")
      end
    elseif stmt.type == "Assign" then
      local target_expressions = flatten_targets(stmt.targets)
      push(indent() .. table.concat(target_expressions, ", ") .. " = " .. gen_expr(stmt.value))
    elseif stmt.type == "AugAssign" then
      local t = gen_expr(stmt.target)
      push(indent() .. t .. " = " .. t .. " " .. stmt.op .. " " .. gen_expr(stmt.value))
    elseif stmt.type == "ExprStmt" then
      if stmt.expr.type == "Constant" and type(stmt.expr.value) == "string" then
        -- docstring: skip
      elseif stmt.expr.type == "Name" then
        -- bare Name (e.g. `sys` from failed `import sys`): skip
      elseif stmt.expr.type == "Module" then
        -- bare import: skip
      else
        push(indent() .. gen_expr(stmt.expr))
      end
    elseif stmt.type == "Global" then
    elseif stmt.type == "Pass" then
    elseif stmt.type == "Break" then
      push(indent() .. "break")
    elseif stmt.type == "Continue" then
      push(indent() .. "goto __continue")
    elseif stmt.type == "Try" then
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
          end
          -- execute the first matching handler
          for _, h in ipairs(stmt.handlers) do
            if h.type then
              -- type-checked except: for now, just always execute
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
    else
      error("unknown statement type: " .. stmt.type)
    end
  end

  -- runtime helpers preamble
  push("do")
  push("chr = string.char")
  push("ord = string.byte")
  push("local function __py_len(x) return #x end")
  push("len = __py_len")
  push("local function __py_int(x) return type(x) == 'number' and math.floor(x) or tonumber(x) end")
  push("int = __py_int")
  push("function __py_slice(tbl, start, stop, step)")
  push("    local s, e, st = start, stop, step or 1")
  push("    local n = #tbl")
  push("    if st > 0 then")
  push("        if s == nil then s = 0 end")
  push("        if e == nil then e = n end")
  push("        s = s + 1")
  push("        local result = {}")
  push("        for i = s, e, st do result[#result + 1] = tbl[i] end")
  push("        return result")
  push("    elseif st < 0 then")
  push("        if s == nil then s = n - 1 end")
  push("        if e == nil then e = -1 end")
  push("        s = s + 1")
  push("        e = e + 1")
  push("        local result = {}")
  push("        for i = s, e, st do result[#result + 1] = tbl[i] end")
  push("        return result")
  push("    end")
  push("    return {}")
  push("end")
  push("function __py_in(container, item)")
  push('    if type(container) == "table" then')
  push("        for _, __v in ipairs(container) do if __v == item then return true end end")
  push("        return false")
  push('    elseif type(container) == "string" then')
  push("        return string.find(container, item, 1, true) ~= nil")
  push("    end")
  push("    return false")
  push("end")
  push("function __py_repeat(val, n)")
  push("    local res = {}")
  push("    for _ = 1, n do")
  push("        res[#res + 1] = val")
  push("    end")
  push("    return res")
  push("end")
  push("function __py_range(...)")
  push("    local start, stop, step")
  push('    if select("#", ...) == 1 then start, stop, step = 0, (...), 1')
  push('    elseif select("#", ...) == 2 then start, stop, step = (...), select(2, ...), 1')
  push("    else start, stop, step = (...), select(2, ...), select(3, ...) end")
  push("    local result = {}")
  push("    if step > 0 then for i = start, stop - 1, step do result[#result + 1] = i end")
  push("    end")
  push("    if step < 0 then for i = start, stop + 1, step do result[#result + 1] = i end")
  push("    end")
  push("    return result")
  push("end")
  push("range = __py_range")
  push("end")

  gen_body(ast.body)
  return table.concat(parts, "\n")
end

-- ============================================================
-- Public API
-- ============================================================

return generator
