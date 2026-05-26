local ast = require("python.ast")
local stdlib = require("python.stdlib")
local walker = require("python.optimizer.ast_walker")
local optimizer = {}

---@class Analysis
---@field used_stdlib table<string, boolean>|nil  -- stdlib functions used in the program
local Analysis = {}
function Analysis:new()
  return setmetatable({}, { __index = self })
end

local function is_constant(expr, value)
  return expr and expr.type == ast.CONSTANT and expr.value == value
end

local function replace_with_else(body, i, stmt)
  local else_stmts = stmt.or_else or {}
  table.remove(body, i)
  for j = #else_stmts, 1, -1 do
    table.insert(body, i, else_stmts[j])
  end
end

--- Resolve keyword argument names to parameter positions for known local functions.
--- When f(a=1, b=2) calls a function defined in the same module, this pass maps
--- keyword names to positional slots so the generator can emit a correctly-ordered argument list.
---@param program ast.Program
function optimizer.call_resolution_pass(program)
  local func_map = {}
  walker.walk_all_bodies(program, {
    visit_before = function(body)
      if not body then return end
      for _, stmt in ipairs(body) do
        if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
          func_map[stmt.name] = stmt
        end
      end
    end,
  })
  walker.walk_program(program, {
    early_expr = function(expr)
      if expr.type ~= ast.CALL or not expr.keywords or #expr.keywords == 0 then return end
      local callee = expr.func
      if callee.type ~= ast.NAME or not func_map[callee.id] then return end
      local func_def = func_map[callee.id]
      local resolved = {}
      for _, kw in ipairs(expr.keywords) do
        for _, param_name in ipairs(func_def.args) do
          if kw.arg == param_name then
            resolved[#resolved + 1] = param_name
            break
          end
        end
      end
      if #resolved > 0 then
        expr._resolved_params = resolved
      end
    end,
  })
end

--- Combined dead code elimination pass:
--- prunes constant if/while branches and removes unreachable code after return/break/continue.
--- Replaces three separate walks: if_false_pass + while_false_pass + unreachable_pass.
---@param program ast.Program
function optimizer.dead_code_pass(program)
  walker.walk_all_bodies(program, {
    visit_after = function(body)
      if not body then return end
      local i = 1
      while i <= #body do
        local stmt = body[i]
        if stmt.type == ast.IF then
          if is_constant(stmt.test, false) then
            replace_with_else(body, i, stmt)
          elseif is_constant(stmt.test, true) then
            local inline_stmts = stmt.body or {}
            if stmt.or_else then
              for _, s in ipairs(stmt.or_else) do
                inline_stmts[#inline_stmts + 1] = s
              end
            end
            table.remove(body, i)
            for j = #inline_stmts, 1, -1 do
              table.insert(body, i, inline_stmts[j])
            end
          else
            i = i + 1
          end
        elseif stmt.type == ast.WHILE and is_constant(stmt.test, false) then
          replace_with_else(body, i, stmt)
        else
          i = i + 1
        end
      end
      for i, stmt in ipairs(body) do
        if stmt.type == ast.RETURN or stmt.type == ast.BREAK or stmt.type == ast.CONTINUE then
          local j = i + 1
          while j <= #body do
            if body[j].type == ast.COMMENT then
              j = j + 1
            else
              table.remove(body, j)
            end
          end
          break
        end
      end
    end,
  })
end

--- Combined usage analysis pass: stamps generator functions and collects stdlib usage.
--- Replaces two separate walks (generator_pass + stdlib_usage_pass).
---@param program ast.Program
---@param analysis Analysis
function optimizer.usage_pass(program, analysis)
  analysis.used_stdlib = {}
  local used = analysis.used_stdlib
  local function_stack = {}
  local function stamp_enclosing()
    for _, fn in ipairs(function_stack) do
      fn._is_generator = true
    end
  end
  walker.walk_program(program, {
    early_expr = function(expr)
      if expr.type == ast.YIELD then stamp_enclosing() end
      if expr.type == ast.CALL then
        if expr.keywords and #expr.keywords > 0 then used.__py_call = true end
        if expr.func.type == ast.SUPER then used.__py_super = true end
        if expr.func.type == ast.NAME then
          local alias = stdlib.aliases[expr.func.id]
          if alias then expr.func.id = alias; used[alias] = true end
        end
        if expr.func.type == ast.ATTRIBUTE and not (expr.keywords and #expr.keywords > 0) then
          if expr.func.attr == "items" and #expr.args == 0 then
            used.__py_items = true
          elseif expr.func.attr == "endswith" and #expr.args == 1 then
            used.__py_endswith = true
          end
        end
      elseif expr.type == ast.SUBSCRIPT then
        if expr.index.type == ast.SLICE then used.__py_slice = true; used.__py_slice_assign = true end
        if expr.index.type ~= ast.CONSTANT or type(expr.index.value) ~= "string" then
          used.__py_getitem = true
        end
      elseif expr.type == ast.COMPARE then
        for _, op in ipairs(expr.ops) do
          if op == "in" or op == "not in" then used.__py_in = true; break end
        end
      elseif expr.type == ast.BIN_OP and expr.op == "*" then
        if expr.left.type == ast.LIST or expr.left.type == ast.SET
          or expr.right.type == ast.LIST or expr.right.type == ast.SET then
          used.__py_repeat = true
        end
      elseif expr.type == ast.BIN_OP then
        local bitwise_ops = { ["|"] = true, ["^"] = true, ["&"] = true, ["<<"] = true, [">>"] = true }
        if bitwise_ops[expr.op] then
          used.__py_bitwise_ops = true
        end
      elseif expr.type == ast.UNARY_OP and expr.op == "~" then
        used.__py_bitwise_ops = true
      end
    end,
    early_stmt = function(stmt)
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.ASYNC_FUNCTION_DEF then
        table.insert(function_stack, stmt)
      elseif stmt.type == ast.YIELD then
        stamp_enclosing()
      end
      if stmt.type == ast.TRY then
        for _, handler in ipairs(stmt.handlers or {}) do
          if handler.type then
            used.__py_exception_match = true
            used.__py_exception_classes = true
            break
          end
        end
      elseif stmt.type == ast.RAISE and stmt.exc then
        used.__py_exception_match = true
        used.__py_exception_classes = true
      end
    end,
    on_stmt = function(stmt)
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.ASYNC_FUNCTION_DEF then
        table.remove(function_stack)
      end
    end,
  })
end

---@param program ast.Program
---@param options? table
---@return Analysis
function optimizer.analyze(program, options)
  options = options or {}
  local analysis = Analysis:new()
  local optimize = options.optimize ~= false
  if optimize and options.call_resolution ~= false then optimizer.call_resolution_pass(program) end
  if optimize and options.dead_code_prune ~= false then optimizer.dead_code_pass(program) end
  if optimize and options.stdlib_inline ~= false then optimizer.usage_pass(program, analysis) end
  return analysis
end

return optimizer
