---@diagnostic disable: undefined-field, inject-field

local ast = require("python.ast")

local optimizer = {}

local walker = require("python.ast_walker")

local function kwarg_pass(program, analysis)
  analysis.has_kwargs = false
  walker.walk_program(program, {
    early_expr = function(expr)
      if analysis.has_kwargs then return "skip" end
      if expr.type == ast.CALL and expr.keywords and #expr.keywords > 0 then
        analysis.has_kwargs = true
      end
    end,
  })
end
local function call_resolution_pass(program, analysis)
  local func_map = {}

  local function collect_funcs(body)
    for _, stmt in ipairs(body or {}) do
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
        func_map[stmt.name] = stmt
        collect_funcs(stmt.body)
      elseif stmt.type == ast.IF then
        collect_funcs(stmt.body)
        for _, elif in ipairs(stmt.elifs or {}) do collect_funcs(elif.body) end
        collect_funcs(stmt.or_else)
      elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
        collect_funcs(stmt.body)
        collect_funcs(stmt.or_else)
      elseif stmt.type == ast.TRY then
        collect_funcs(stmt.body)
        for _, handler in ipairs(stmt.handlers or {}) do collect_funcs(handler.body) end
        collect_funcs(stmt.finally_body)
      end
    end
  end
  collect_funcs(program.body)

  walker.walk_program(program, {
    early_expr = function(expr)
      if expr.type == ast.CALL and expr.keywords and #expr.keywords > 0 then
        if expr.func.type == ast.NAME then
          local func_def = func_map[expr.func.id]
          if func_def and func_def.type == ast.FUNCTION_DEF then
            expr._resolved_params = func_def.args
          end
        end
      end
    end,
  })
end

local function is_constant(expr, val)
  return expr and expr.type == ast.CONSTANT and expr.value == val
end

local function if_false_pass(program)
  local function visit_body(body)
    if not body then
      return
    end
    local i = 1
    while i <= #body do
      local stmt = body[i]
      if stmt.type == ast.IF then
        if is_constant(stmt.test, false) then
          local else_stmts = stmt.or_else or {}
          table.remove(body, i)
          for j = #else_stmts, 1, -1 do
            table.insert(body, i, else_stmts[j])
          end
        elseif is_constant(stmt.test, true) then
          local inline_stmts = stmt.body or {}
          if stmt.or_else then
            for _, s in ipairs(stmt.or_else) do
              inline_stmts[#inline_stmts + 1] = s
            end
          end
          body[i] = inline_stmts
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    end
  end

  local function visit_node(stmt)
    if not stmt then
      return
    end
    if stmt.type == ast.IF then
      visit_body(stmt.body)
      for _, elif in ipairs(stmt.elifs or {}) do
        visit_body(elif.body)
      end
      visit_body(stmt.or_else)
    elseif stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      visit_body(stmt.body)
    elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
      visit_body(stmt.body)
      visit_body(stmt.or_else)
    elseif stmt.type == ast.TRY then
      visit_body(stmt.body)
      for _, handler in ipairs(stmt.handlers or {}) do
        visit_body(handler.body)
      end
      visit_body(stmt.finally_body)
    end
  end

  local function walk(body)
    if not body then
      return
    end
    for _, stmt in ipairs(body) do
      visit_node(stmt)
    end
    visit_body(body)
  end

  walk(program.body)
end

local function while_false_pass(program)
  local function walk(body)
    if not body then
      return
    end
    local i = 1
    while i <= #body do
      local stmt = body[i]
      if stmt.type == ast.WHILE and is_constant(stmt.test, false) then
        local else_stmts = stmt.or_else or {}
        table.remove(body, i)
        for j = #else_stmts, 1, -1 do
          table.insert(body, i, else_stmts[j])
        end
      else
        i = i + 1
      end
    end
  end

  local function visit(stmt)
    if not stmt then
      return
    end
    if stmt.type == ast.IF then
      walk(stmt.body)
      for _, elif in ipairs(stmt.elifs or {}) do
        walk(elif.body)
      end
      walk(stmt.or_else)
    elseif stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      walk(stmt.body)
    elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
      walk(stmt.body)
      walk(stmt.or_else)
    elseif stmt.type == ast.TRY then
      walk(stmt.body)
      for _, handler in ipairs(stmt.handlers or {}) do
        walk(handler.body)
      end
      walk(stmt.finally_body)
    end
  end

  local function recurse(body)
    if not body then
      return
    end
    for _, stmt in ipairs(body) do
      visit(stmt)
    end
    walk(body)
  end

  recurse(program.body)
end

local function unreachable_pass(program)
  local function walk(body)
    if not body then
      return
    end
    for i, stmt in ipairs(body) do
      if stmt.type == ast.RETURN or stmt.type == ast.BREAK or stmt.type == ast.CONTINUE then
        while body[i + 1] do
          table.remove(body)
        end
        break
      end
    end
  end

  local function visit(stmt)
    if not stmt then
      return
    end
    if stmt.type == ast.IF then
      walk(stmt.body)
      for _, elif in ipairs(stmt.elifs or {}) do
        walk(elif.body)
      end
      walk(stmt.or_else)
    elseif stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      walk(stmt.body)
    elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
      walk(stmt.body)
      walk(stmt.or_else)
    elseif stmt.type == ast.TRY then
      walk(stmt.body)
      for _, handler in ipairs(stmt.handlers or {}) do
        walk(handler.body)
      end
      walk(stmt.finally_body)
    end
  end

  local function recurse(body)
    if not body then
      return
    end
    for _, stmt in ipairs(body) do
      visit(stmt)
    end
    walk(body)
  end

  recurse(program.body)
end

local function stdlib_usage_pass(program, analysis)
  analysis.used_stdlib = {}
  local used = analysis.used_stdlib

  local alias_names = {
    len = "__py_len",
    int = "__py_int",
    range = "__py_range",
    isinstance = "__py_isinstance",
    issubclass = "__py_issubclass",
  }

  walker.walk_program(program, {
    early_expr = function(expr)
      if expr.type == ast.CALL then
        if expr.keywords and #expr.keywords > 0 then
          used.__py_call = true
        end
        if expr.func.type == ast.SUPER then
          used.__py_super = true
        end
        if expr.func.type == ast.NAME then
          local alias = alias_names[expr.func.id]
          if alias then
            expr.func.id = alias
            used[alias] = true
          end
        end
        if expr.func.type == ast.ATTRIBUTE and not (expr.keywords and #expr.keywords > 0) then
          if expr.func.attr == "items" and #expr.args == 0 then
            used.__py_items = true
          elseif expr.func.attr == "endswith" and #expr.args == 1 then
            used.__py_endswith = true
          end
        end
      elseif expr.type == ast.SUBSCRIPT then
        if expr.index.type == ast.SLICE then
          used.__py_slice = true
        end
        if expr.index.type ~= ast.CONSTANT or type(expr.index.value) ~= "string" then
          used.__py_getitem = true
        end
      elseif expr.type == ast.COMPARE then
        for _, op in ipairs(expr.ops) do
          if op == "in" or op == "not in" then
            used.__py_in = true
            break
          end
        end
      elseif expr.type == ast.BIN_OP and expr.op == "*" then
        if expr.left.type == ast.LIST
          or expr.left.type == ast.SET
          or expr.left.type == ast.TUPLE
          or expr.right.type == ast.LIST
          or expr.right.type == ast.SET
          or expr.right.type == ast.TUPLE
        then
          used.__py_repeat = true
        end
      end
    end,
  })
end

---@param program ast.Program
---@param options? transpile_opts
---@return {used_stdlib?: table<string,boolean>, has_kwargs?: boolean}
function optimizer.analyze(program, options)
  options = options or {}
  local analysis = {}
  local optimize = options.optimize ~= false

  if optimize and options.kwarg_analysis ~= false then
    kwarg_pass(program, analysis)
  end
  if optimize and options.call_resolution ~= false then
    call_resolution_pass(program, analysis)
  end
  if optimize and options.if_false_prune ~= false then
    if_false_pass(program)
  end
  if optimize and options.while_false_prune ~= false then
    while_false_pass(program)
  end
  if optimize and options.unreachable_prune ~= false then
    unreachable_pass(program)
  end
  if optimize and options.stdlib_inline ~= false then
    stdlib_usage_pass(program, analysis)
  end

  return analysis
end

return optimizer
