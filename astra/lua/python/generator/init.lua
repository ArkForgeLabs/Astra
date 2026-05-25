local ast = require("python.ast")
local util = require("python.util")
local stdlib = require("python.stdlib")
local expression_gen = require("python.generator.expression")
local statement_gen = require("python.generator.statement")
local generator = {}

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
---@param analysis? {used_stdlib?: table, has_kwargs?: boolean}
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

  local gen_body, with_indent, gen_expr, gen_stmt
  local gen_comp_loops
  local gen_subscript_target

  local ctx = {
    push = push,
    indent = indent,
    analysis = analysis,
    indent_level = indent_level,
  }

  local function gen_index(expr)
    local idx = ctx.gen_expr(expr.index)
    if expr.index.type == ast.CONSTANT and type(expr.index.value) == "string" then
      return idx
    end
    return idx .. " + 1"
  end

  gen_body = function(body)
    local i = 1
    while i <= #body do
      if body[i].type == ast.COMMENT then
        local comment_lines = {}
        while i <= #body and body[i].type == ast.COMMENT do
          local text = body[i].value
          if text ~= "" then
            for line in text:gmatch("[^\n]+") do
              comment_lines[#comment_lines + 1] = line
            end
          end
          i = i + 1
        end
        if #comment_lines == 1 then
          ctx.push(ctx.indent() .. "-- " .. comment_lines[1])
        elseif #comment_lines > 1 then
          ctx.push(ctx.indent() .. "--[[ " .. table.concat(comment_lines, " ") .. " ]]")
        end
      else
        ctx.gen_stmt(body[i])
        i = i + 1
      end
    end
  end

  with_indent = function(fn)
    indent_level = indent_level + 1
    fn()
    indent_level = indent_level - 1
  end

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

  ctx.gen_body = gen_body
  ctx.with_indent = with_indent
  ctx.gen_index = gen_index
  ctx.is_lua_module = is_lua_module
  ctx.gen_comp_loops = gen_comp_loops

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
      if expr.index.type == ast.SLICE then
        return ctx.gen_expr(expr)
      end
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

  gen_body(prog.body)
  local user_body = table.concat(parts, "\n")

  local used = (analysis or {}).used_stdlib
  local preamble_parts = {}
  if used then
    preamble_parts[#preamble_parts + 1] = "local chr, ord, str, int = string.char, string.byte, tostring, tonumber"
    preamble_parts[#preamble_parts + 1] = "if not table.unpack then table.unpack = unpack end"
    for _, name in ipairs({
      "__py_slice", "__py_slice_assign", "__py_in", "__py_repeat", "__py_range",
      "__py_items", "__py_super", "__py_getitem",
      "__py_isinstance", "__py_issubclass", "__py_call",
    }) do
      if used[name] then
        preamble_parts[#preamble_parts + 1] = stdlib.__inline_functions[name]
      end
    end
  else
    preamble_parts[#preamble_parts + 1] = "require('python.stdlib')"
  end

  local preamble = table.concat(preamble_parts, "\n")
  return preamble .. "\n" .. user_body
end

return generator
