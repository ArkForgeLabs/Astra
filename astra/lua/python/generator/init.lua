local ast = require("python.ast")
local util = require("python.util")
local stdlib = require("python.stdlib")
local expression_gen = require("python.generator.expression")
local statement_gen = require("python.generator.statement")
local generator = {}

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
    uses_full_stdlib = false,
  }

  local function gen_index(expr)
    if expr.index.type == ast.CONSTANT then
      if type(expr.index.value) == "string" then
        return ctx.gen_expr(expr.index)
      elseif type(expr.index.value) == "number" then
        return tostring(expr.index.value + 1)
      end
    end
    return ctx.gen_expr(expr.index) .. " + 1"
  end

  gen_body = function(body)
    local i = 1
    local pending_blanks = 0
    local function flush_blanks()
      for _ = 1, pending_blanks do
        ctx.push("")
      end
      pending_blanks = 0
    end
    while i <= #body do
      if body[i].type == ast.COMMENT then
        local comment_lines = {}
        while i <= #body and body[i].type == ast.COMMENT do
          local text = body[i].value
          if text == "" then
            pending_blanks = pending_blanks + 1
          else
            flush_blanks()
            for line in text:gmatch("[^\n]+") do
              comment_lines[#comment_lines + 1] = line
            end
          end
          i = i + 1
        end
        if #comment_lines == 1 then
          ctx.push(ctx.indent() .. "-- " .. comment_lines[1])
        elseif #comment_lines > 1 then
          for _, line in ipairs(comment_lines) do
            ctx.push(ctx.indent() .. "-- " .. line)
          end
        end
      else
        flush_blanks()
        ctx.gen_stmt(body[i])
        i = i + 1
      end
    end
    pending_blanks = 0
  end

  with_indent = function(fn)
    indent_level = indent_level + 1
    fn()
    indent_level = indent_level - 1
  end

  gen_comp_loops = function(inner_fn, generators, idx, depth)
    depth = depth or 1
    if idx > #generators then
      return inner_fn()
    end
    local gen = generators[idx]
    local indent = string.rep("    ", depth)
    local result = "\n" .. indent .. "for _, " .. gen.target .. " in ipairs(" .. ctx.gen_expr(gen.iterator) .. ") do"
    local inner = gen_comp_loops(inner_fn, generators, idx + 1, depth + 1)
    for _, if_expr in ipairs(gen.ifs or {}) do
      result = result .. "\n" .. indent .. "    if " .. ctx.gen_expr(if_expr) .. " then"
      result = result .. inner
      result = result .. "\n" .. indent .. "    end"
    end
    if #(gen.ifs or {}) == 0 then
      result = result .. inner
    end
    result = result .. "\n" .. indent .. "end"
    return result
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
    return expr_handlers[expr.type](expr)
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
    stmt_handlers[stmt.type](stmt)
  end

  gen_body(prog.body)
  local user_body = table.concat(parts, "\n")

  ctx.uses_full_stdlib = false
  local used = (analysis or {}).used_stdlib
  local preamble_parts = {}
  if used then
    local used_count = 0
    for _ in pairs(used) do used_count = used_count + 1 end
    if used_count > 5 then
      ctx.uses_full_stdlib = true
      preamble_parts[#preamble_parts + 1] = "require('python.stdlib')"
    else
      preamble_parts[#preamble_parts + 1] = "local chr, ord, str, int = string.char, string.byte, tostring, tonumber"
      preamble_parts[#preamble_parts + 1] = "if not table.unpack then table.unpack = unpack end"
      for _, name in ipairs({
        "__py_slice", "__py_slice_assign", "__py_in", "__py_repeat", "__py_range",
        "__py_items", "__py_super", "__py_getitem",
        "__py_isinstance", "__py_issubclass", "__py_call",
        "__py_exception_classes", "__py_exception_match",
        "__py_bitwise_ops",
      }) do
        if used[name] then
          preamble_parts[#preamble_parts + 1] = stdlib.__inline_functions[name]
        end
      end
    end
  else
    ctx.uses_full_stdlib = true
    preamble_parts[#preamble_parts + 1] = "require('python.stdlib')"
  end

  local preamble = table.concat(preamble_parts, "\n")
  return preamble .. "\n" .. user_body
end

return generator
