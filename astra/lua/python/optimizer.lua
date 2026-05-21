local ast = require("python.ast")

local optimizer = {}

local function kwarg_pass(program, analysis)
  analysis.has_kwargs = false

  local function walk_expr(expr)
    if analysis.has_kwargs then
      return
    end
    if not expr or type(expr) ~= "table" then
      return
    end
    if expr.type == ast.CALL then
      if expr.keywords and #expr.keywords > 0 then
        analysis.has_kwargs = true
        return
      end
      walk_expr(expr.func)
      for _, a in ipairs(expr.args or {}) do
        walk_expr(a)
      end
      for _, kw in ipairs(expr.keywords or {}) do
        walk_expr(kw.value)
      end
    elseif expr.type == ast.BIN_OP then
      walk_expr(expr.left)
      walk_expr(expr.right)
    elseif expr.type == ast.UNARY_OP then
      walk_expr(expr.operand)
    elseif expr.type == ast.BOOL_OP then
      for _, value in ipairs(expr.values) do
        walk_expr(v)
      end
    elseif expr.type == ast.COMPARE then
      walk_expr(expr.left)
      for _, comparator in ipairs(expr.comparators) do
        walk_expr(c)
      end
    elseif expr.type == ast.SUBSCRIPT then
      walk_expr(expr.value)
      walk_expr(expr.index)
    elseif expr.type == ast.ATTRIBUTE then
      walk_expr(expr.value)
    elseif expr.type == ast.LIST or expr.type == ast.SET or expr.type == ast.TUPLE then
      for _, e in ipairs(expr.elements or {}) do
        walk_expr(e)
      end
    elseif expr.type == ast.DICT then
      for _, k in ipairs(expr.keys or {}) do
        walk_expr(k)
      end
      for _, value in ipairs(expr.values or {}) do
        walk_expr(v)
      end
    elseif expr.type == ast.LAMBDA then
      walk_expr(expr.body)
    elseif expr.type == ast.WALRUS then
      walk_expr(expr.target)
      walk_expr(expr.value)
    elseif expr.type == ast.IF_EXPR then
      walk_expr(expr.test)
      walk_expr(expr.body)
      walk_expr(expr.or_else)
    elseif expr.type == ast.LIST_COMP or expr.type == ast.SET_COMP then
      walk_expr(expr.element)
      for _, generator in ipairs(expr.generators or {}) do
        walk_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.DICT_COMP then
      walk_expr(expr.key)
      walk_expr(expr.value)
      for _, generator in ipairs(expr.generators or {}) do
        walk_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.STARRED then
      walk_expr(expr.value)
    end
  end

  local function walk_stmt(stmt)
    if analysis.has_kwargs then
      return
    end
    if not stmt or type(stmt) ~= "table" then
      return
    end
    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      for _, decorator in ipairs(stmt.decorators or {}) do
        walk_expr(d)
      end
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
    elseif stmt.type == ast.IF then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      for _, elif in ipairs(stmt.elifs or {}) do
        walk_expr(elif.test)
        for _, s in ipairs(elif.body or {}) do
          walk_stmt(s)
        end
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.WHILE then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.FOR then
      if stmt.iterator then
        walk_expr(stmt.iterator)
      end
      for _, arg in ipairs(stmt.range_args or {}) do
        walk_expr(arg)
      end
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.TRY then
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      for _, handler in ipairs(stmt.handlers or {}) do
        for _, s in ipairs(handler.body or {}) do
          walk_stmt(s)
        end
      end
      if stmt.finally_body then
        for _, s in ipairs(stmt.finally_body) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.RETURN then
      if stmt.value then
        walk_expr(stmt.value)
      end
    elseif stmt.type == ast.ASSIGN then
      for _, target in ipairs(stmt.targets or {}) do
        walk_expr(target)
      end
      if stmt.value then
        walk_expr(stmt.value)
      end
    elseif stmt.type == ast.AUG_ASSIGN then
      walk_expr(stmt.target)
      walk_expr(stmt.value)
    elseif stmt.type == ast.EXPR_STMT then
      walk_expr(stmt.expr)
    end
  end

  for _, stmt in ipairs(program.body or {}) do
    walk_stmt(stmt)
    if analysis.has_kwargs then
      break
    end
  end
end
local function call_resolution_pass(program, analysis)
  local func_map = {}

  local function collect_funcs(body)
    for _, stmt in ipairs(body or {}) do
      if stmt.type == ast.FUNCTION_DEF then
        func_map[stmt.name] = stmt
      elseif stmt.type == ast.CLASS_DEF then
        func_map[stmt.name] = stmt
      end
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
        collect_funcs(stmt.body)
      elseif stmt.type == ast.IF then
        collect_funcs(stmt.body)
        for _, elif in ipairs(stmt.elifs or {}) do
          collect_funcs(elif.body)
        end
        collect_funcs(stmt.or_else)
      elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
        collect_funcs(stmt.body)
        collect_funcs(stmt.or_else)
      elseif stmt.type == ast.TRY then
        collect_funcs(stmt.body)
        for _, handler in ipairs(stmt.handlers or {}) do
          collect_funcs(handler.body)
        end
        collect_funcs(stmt.finally_body)
      end
    end
  end
  collect_funcs(program.body)

  local function resolve_expr(expr)
    if not expr or type(expr) ~= "table" then
      return
    end
    if expr.type == ast.CALL and expr.keywords and #expr.keywords > 0 then
      if expr.func.type == ast.NAME then
        local func_def = func_map[expr.func.id]
        if func_def and func_def.type == ast.FUNCTION_DEF then
          expr._resolved_params = func_def.args
        end
      end
    end
    if expr.type == ast.CALL then
      resolve_expr(expr.func)
      for _, a in ipairs(expr.args or {}) do
        resolve_expr(a)
      end
      for _, kw in ipairs(expr.keywords or {}) do
        resolve_expr(kw.value)
      end
    elseif expr.type == ast.BIN_OP then
      resolve_expr(expr.left)
      resolve_expr(expr.right)
    elseif expr.type == ast.UNARY_OP then
      resolve_expr(expr.operand)
    elseif expr.type == ast.BOOL_OP then
      for _, value in ipairs(expr.values) do
        resolve_expr(v)
      end
    elseif expr.type == ast.COMPARE then
      resolve_expr(expr.left)
      for _, comparator in ipairs(expr.comparators) do
        resolve_expr(c)
      end
    elseif expr.type == ast.SUBSCRIPT then
      resolve_expr(expr.value)
      resolve_expr(expr.index)
    elseif expr.type == ast.ATTRIBUTE then
      resolve_expr(expr.value)
    elseif expr.type == ast.LIST or expr.type == ast.SET or expr.type == ast.TUPLE then
      for _, e in ipairs(expr.elements or {}) do
        resolve_expr(e)
      end
    elseif expr.type == ast.DICT then
      for _, k in ipairs(expr.keys or {}) do
        resolve_expr(k)
      end
      for _, value in ipairs(expr.values or {}) do
        resolve_expr(v)
      end
    elseif expr.type == ast.LAMBDA then
      resolve_expr(expr.body)
    elseif expr.type == ast.WALRUS then
      resolve_expr(expr.target)
      resolve_expr(expr.value)
    elseif expr.type == ast.IF_EXPR then
      resolve_expr(expr.test)
      resolve_expr(expr.body)
      resolve_expr(expr.or_else)
    elseif expr.type == ast.LIST_COMP or expr.type == ast.SET_COMP then
      resolve_expr(expr.element)
      for _, generator in ipairs(expr.generators or {}) do
        resolve_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          resolve_expr(if_expr)
        end
      end
    elseif expr.type == ast.DICT_COMP then
      resolve_expr(expr.key)
      resolve_expr(expr.value)
      for _, generator in ipairs(expr.generators or {}) do
        resolve_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          resolve_expr(if_expr)
        end
      end
    elseif expr.type == ast.STARRED then
      resolve_expr(expr.value)
    end
  end

  local function resolve_body(body)
    for _, stmt in ipairs(body or {}) do
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
        resolve_body(stmt.body)
      elseif stmt.type == ast.IF then
        resolve_body(stmt.body)
        for _, elif in ipairs(stmt.elifs or {}) do
          resolve_body(elif.body)
        end
        resolve_body(stmt.or_else)
      elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
        resolve_body(stmt.body)
        resolve_body(stmt.or_else)
      elseif stmt.type == ast.TRY then
        resolve_body(stmt.body)
        for _, handler in ipairs(stmt.handlers or {}) do
          resolve_body(handler.body)
        end
        resolve_body(stmt.finally_body)
      elseif stmt.type == ast.EXPR_STMT then
        resolve_expr(stmt.expr)
      elseif stmt.type == ast.ASSIGN then
        for _, target in ipairs(stmt.targets or {}) do
          resolve_expr(target)
        end
        resolve_expr(stmt.value)
      elseif stmt.type == ast.AUG_ASSIGN then
        resolve_expr(stmt.target)
        resolve_expr(stmt.value)
      elseif stmt.type == ast.RETURN then
        if stmt.value then
          resolve_expr(stmt.value)
        end
      end
    end
  end

  resolve_body(program.body)
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

  local function walk_expr(expr)
    if not expr or type(expr) ~= "table" then
      return
    end
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
          -- isinstance/issubclass may reference int/str/chr as type arguments
          if alias == "__py_isinstance" or alias == "__py_issubclass" then
          end
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
      if
        expr.left.type == ast.LIST
        or expr.left.type == ast.SET
        or expr.left.type == ast.TUPLE
        or expr.right.type == ast.LIST
        or expr.right.type == ast.SET
        or expr.right.type == ast.TUPLE
      then
        used.__py_repeat = true
      end
    end
    if expr.type == ast.CALL then
      walk_expr(expr.func)
      for _, a in ipairs(expr.args or {}) do
        walk_expr(a)
      end
      for _, kw in ipairs(expr.keywords or {}) do
        walk_expr(kw.value)
      end
    elseif expr.type == ast.BIN_OP then
      walk_expr(expr.left)
      walk_expr(expr.right)
    elseif expr.type == ast.UNARY_OP then
      walk_expr(expr.operand)
    elseif expr.type == ast.BOOL_OP then
      for _, value in ipairs(expr.values) do
        walk_expr(v)
      end
    elseif expr.type == ast.COMPARE then
      walk_expr(expr.left)
      for _, comparator in ipairs(expr.comparators) do
        walk_expr(c)
      end
    elseif expr.type == ast.SUBSCRIPT then
      walk_expr(expr.value)
      walk_expr(expr.index)
    elseif expr.type == ast.ATTRIBUTE then
      walk_expr(expr.value)
    elseif expr.type == ast.LIST or expr.type == ast.SET or expr.type == ast.TUPLE then
      for _, e in ipairs(expr.elements or {}) do
        walk_expr(e)
      end
    elseif expr.type == ast.DICT then
      for _, k in ipairs(expr.keys or {}) do
        walk_expr(k)
      end
      for _, value in ipairs(expr.values or {}) do
        walk_expr(v)
      end
    elseif expr.type == ast.LAMBDA then
      walk_expr(expr.body)
    elseif expr.type == ast.WALRUS then
      walk_expr(expr.target)
      walk_expr(expr.value)
    elseif expr.type == ast.IF_EXPR then
      walk_expr(expr.test)
      walk_expr(expr.body)
      walk_expr(expr.or_else)
    elseif expr.type == ast.LIST_COMP or expr.type == ast.SET_COMP then
      walk_expr(expr.element)
      for _, generator in ipairs(expr.generators or {}) do
        walk_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.DICT_COMP then
      walk_expr(expr.key)
      walk_expr(expr.value)
      for _, generator in ipairs(expr.generators or {}) do
        walk_expr(generator.iterator)
        for _, if_expr in ipairs(generator.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.STARRED then
      walk_expr(expr.value)
    end
  end

  local function walk_stmt(stmt)
    if not stmt or type(stmt) ~= "table" then
      return
    end
    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      for _, decorator in ipairs(stmt.decorators or {}) do
        walk_expr(d)
      end
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
    elseif stmt.type == ast.IF then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      for _, elif in ipairs(stmt.elifs or {}) do
        walk_expr(elif.test)
        for _, s in ipairs(elif.body or {}) do
          walk_stmt(s)
        end
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.WHILE then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.FOR then
      if stmt.iterator then
        walk_expr(stmt.iterator)
      end
      for _, arg in ipairs(stmt.range_args or {}) do
        walk_expr(arg)
      end
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.TRY then
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
      for _, handler in ipairs(stmt.handlers or {}) do
        for _, s in ipairs(handler.body or {}) do
          walk_stmt(s)
        end
      end
      if stmt.finally_body then
        for _, s in ipairs(stmt.finally_body) do
          walk_stmt(s)
        end
      end
    elseif stmt.type == ast.RETURN then
      if stmt.value then
        walk_expr(stmt.value)
      end
    elseif stmt.type == ast.ASSIGN then
      for _, target in ipairs(stmt.targets or {}) do
        walk_expr(target)
      end
      if stmt.value then
        walk_expr(stmt.value)
      end
    elseif stmt.type == ast.AUG_ASSIGN then
      walk_expr(stmt.target)
      walk_expr(stmt.value)
    elseif stmt.type == ast.EXPR_STMT then
      walk_expr(stmt.expr)
    end
  end

  for _, stmt in ipairs(program.body or {}) do
    walk_stmt(stmt)
  end
end

-- Pipeline orchestrator: runs analysis passes first (read-only),
-- then pruning passes (mutate AST). Order matters:
-- kwarg_pass and call_resolution must run before pruning to see full AST.
-- Pruning must run before stdlib_usage_pass to avoid analyzing dead code.
-- Each pass can be disabled via the corresponding options flag.
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
