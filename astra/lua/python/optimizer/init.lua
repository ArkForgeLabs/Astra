local ast = require("python.ast")
local stdlib = require("python.stdlib")
local walker = require("python.optimizer.ast_walker")
local optimizer = {}

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

function optimizer.kwarg_pass(program)
  program._has_kwargs = false
  walker.walk_program(program, {
    early_expr = function(expr)
      if expr.type == ast.CALL and expr.keywords and #expr.keywords > 0 then
        program._has_kwargs = true
        return "skip"
      end
    end,
  })
end

function optimizer.if_false_pass(program)
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
        else
          i = i + 1
        end
      end
    end,
  })
end

function optimizer.while_false_pass(program)
  walker.walk_all_bodies(program, {
    visit_after = function(body)
      if not body then return end
      local i = 1
      while i <= #body do
        local stmt = body[i]
        if stmt.type == ast.WHILE and is_constant(stmt.test, false) then
          replace_with_else(body, i, stmt)
        else
          i = i + 1
        end
      end
    end,
  })
end

function optimizer.unreachable_pass(program)
  walker.walk_all_bodies(program, {
    visit_after = function(body)
      if not body then return end
      for i, stmt in ipairs(body) do
        if stmt.type == ast.RETURN or stmt.type == ast.BREAK or stmt.type == ast.CONTINUE then
          while body[i + 1] do
            table.remove(body)
          end
          break
        end
      end
    end,
  })
end

function optimizer.stdlib_usage_pass(program, analysis)
  analysis.used_stdlib = {}
  local used = analysis.used_stdlib
  walker.walk_program(program, {
    early_expr = function(expr)
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
      end
    end,
  })
end

function optimizer.analyze(program, options)
  options = options or {}
  local analysis = {}
  local optimize = options.optimize ~= false
  if optimize and options.kwarg_analysis ~= false then optimizer.kwarg_pass(program) end
  if optimize and options.call_resolution ~= false then optimizer.call_resolution_pass(program) end
  if optimize and options.if_false_prune ~= false then optimizer.if_false_pass(program) end
  if optimize and options.while_false_prune ~= false then optimizer.while_false_pass(program) end
  if optimize and options.unreachable_prune ~= false then optimizer.unreachable_pass(program) end
  if optimize and options.stdlib_inline ~= false then optimizer.stdlib_usage_pass(program, analysis) end
  return analysis
end

return optimizer
