local ast = require("python.ast")
local walker = {}

--- Walks an AST program tree with optional callbacks for expressions and statements.
--- early_expr/early_stmt can return "skip" to prune subtree traversal.
---@param program ast.Program
---@param opts? {early_expr?: fun(expr): string?, on_expr?: fun(expr), early_stmt?: fun(stmt): string?, on_stmt?: fun(stmt)}
function walker.walk_program(program, opts)
  opts = opts or {}

  local function walk_expr(expr)
    if not expr or type(expr) ~= "table" then return end
    if opts.early_expr and opts.early_expr(expr) == "skip" then return end
    if expr.type == ast.CALL then
      walk_expr(expr.func)
      for _, arg in ipairs(expr.args or {}) do walk_expr(arg) end
      for _, kw in ipairs(expr.keywords or {}) do walk_expr(kw.value) end
    elseif expr.type == ast.BIN_OP then
      walk_expr(expr.left); walk_expr(expr.right)
    elseif expr.type == ast.UNARY_OP then walk_expr(expr.operand)
    elseif expr.type == ast.BOOL_OP then
      for _, value in ipairs(expr.values) do walk_expr(value) end
    elseif expr.type == ast.COMPARE then
      walk_expr(expr.left)
      for _, comparator in ipairs(expr.comparators) do walk_expr(comparator) end
    elseif expr.type == ast.SUBSCRIPT then
      walk_expr(expr.value); walk_expr(expr.index)
    elseif expr.type == ast.ATTRIBUTE then walk_expr(expr.value)
    elseif expr.type == ast.LIST or expr.type == ast.SET or expr.type == ast.TUPLE then
      for _, elem in ipairs(expr.elements or {}) do walk_expr(elem) end
    elseif expr.type == ast.DICT then
      for _, key in ipairs(expr.keys or {}) do walk_expr(key) end
      for _, value in ipairs(expr.values or {}) do walk_expr(value) end
    elseif expr.type == ast.LAMBDA then walk_expr(expr.body)
    elseif expr.type == ast.WALRUS then walk_expr(expr.target); walk_expr(expr.value)
    elseif expr.type == ast.IF_EXPR then
      walk_expr(expr.test); walk_expr(expr.body); walk_expr(expr.or_else)
    elseif expr.type == ast.LIST_COMP or expr.type == ast.SET_COMP then
      walk_expr(expr.element)
      for _, gen in ipairs(expr.generators or {}) do
        walk_expr(gen.iterator)
        for _, if_expr in ipairs(gen.ifs or {}) do walk_expr(if_expr) end
      end
    elseif expr.type == ast.DICT_COMP then
      walk_expr(expr.key); walk_expr(expr.value)
      for _, gen in ipairs(expr.generators or {}) do
        walk_expr(gen.iterator)
        for _, if_expr in ipairs(gen.ifs or {}) do walk_expr(if_expr) end
      end
    elseif expr.type == ast.STARRED then walk_expr(expr.value)
    elseif expr.type == ast.SLICE then
      walk_expr(expr.lower); walk_expr(expr.upper); walk_expr(expr.step)
    elseif expr.type == ast.JOINED_STR then
      for _, v in ipairs(expr.values or {}) do walk_expr(v) end
    elseif expr.type == ast.FORMATTED_VALUE then
      walk_expr(expr.value)
      if expr.format_spec then walk_expr(expr.format_spec) end
    end
    if opts.on_expr then opts.on_expr(expr) end
  end

  local function walk_stmt(stmt)
    if not stmt or type(stmt) ~= "table" then return end
    if opts.early_stmt and opts.early_stmt(stmt) == "skip" then return end
    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      for _, decorator in ipairs(stmt.decorators or {}) do walk_expr(decorator) end
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
    elseif stmt.type == ast.IF then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
      for _, elif in ipairs(stmt.elifs or {}) do
        walk_expr(elif.test)
        for _, s in ipairs(elif.body or {}) do walk_stmt(s) end
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do walk_stmt(s) end
      end
    elseif stmt.type == ast.WHILE then
      walk_expr(stmt.test)
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do walk_stmt(s) end
      end
    elseif stmt.type == ast.FOR then
      if stmt.iterator then walk_expr(stmt.iterator) end
      for _, arg in ipairs(stmt.range_args or {}) do walk_expr(arg) end
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do walk_stmt(s) end
      end
    elseif stmt.type == ast.TRY then
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
      for _, handler in ipairs(stmt.handlers or {}) do
        if handler.type then walk_expr(handler.type) end
        for _, s in ipairs(handler.body or {}) do walk_stmt(s) end
      end
      if stmt.or_else then
        for _, s in ipairs(stmt.or_else) do walk_stmt(s) end
      end
      if stmt.finally_body then
        for _, s in ipairs(stmt.finally_body) do walk_stmt(s) end
      end
    elseif stmt.type == ast.RETURN then
      if stmt.value then walk_expr(stmt.value) end
    elseif stmt.type == ast.ASSIGN then
      for _, target in ipairs(stmt.targets or {}) do walk_expr(target) end
      if stmt.value then walk_expr(stmt.value) end
    elseif stmt.type == ast.AUG_ASSIGN then
      walk_expr(stmt.target); walk_expr(stmt.value)
    elseif stmt.type == ast.EXPR_STMT then
      walk_expr(stmt.expr)
    elseif stmt.type == ast.COMMENT or stmt.type == ast.IMPORT or stmt.type == ast.IMPORT_FROM
        or stmt.type == ast.GLOBAL or stmt.type == ast.NONLOCAL or stmt.type == ast.PASS
        or stmt.type == ast.BREAK or stmt.type == ast.CONTINUE then
      -- leaf nodes, nothing to walk
    elseif stmt.type == ast.WITH then
      for _, item in ipairs(stmt.items or {}) do
        walk_expr(item.context_expr)
        if item.optional_vars then walk_expr(item.optional_vars) end
      end
      for _, s in ipairs(stmt.body or {}) do walk_stmt(s) end
    elseif stmt.type == ast.YIELD then
      if stmt.value then walk_expr(stmt.value) end
    end
    if opts.on_stmt then opts.on_stmt(stmt) end
  end

  for _, stmt in ipairs(program.body or {}) do
    walk_stmt(stmt)
  end
end

--- Walks all nested statement bodies (function/class/if/while/for/try).
--- Accepts a visitors table with optional callbacks:
---   visit_before(body, parent_type) — called pre-order (before children)
---   visit_after(body, parent_type)  — called post-order (after children)
---   visit_node(stmt, parent_type)   — called for each statement in a body
--- Useful for optimizer passes that need to scan or mutate bodies.
---@param program ast.Program
---@param visitors? {visit_before?: fun(body: ast_node[], parent_type: integer), visit_after?: fun(body: ast_node[], parent_type: integer), visit_node?: fun(stmt: ast_node, parent_type: integer)}
function walker.walk_all_bodies(program, visitors)
  visitors = visitors or {}
  local function recurse(body, parent_type)
    if not body then return end
    if visitors.visit_before then visitors.visit_before(body, parent_type) end
    for _, stmt in ipairs(body) do
      if visitors.visit_node then visitors.visit_node(stmt, parent_type) end
      if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
        recurse(stmt.body, stmt.type)
      elseif stmt.type == ast.IF then
        recurse(stmt.body, ast.IF)
        for _, elif in ipairs(stmt.elifs or {}) do recurse(elif.body, ast.IF) end
        recurse(stmt.or_else, ast.IF)
      elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
        recurse(stmt.body, stmt.type)
        recurse(stmt.or_else, stmt.type)
      elseif stmt.type == ast.TRY then
        recurse(stmt.body, ast.TRY)
        for _, handler in ipairs(stmt.handlers or {}) do recurse(handler.body, ast.TRY) end
        recurse(stmt.or_else, ast.TRY)
        recurse(stmt.finally_body, ast.TRY)
      elseif stmt.type == ast.ASYNC_FUNCTION_DEF then
        recurse(stmt.body, stmt.type)
      elseif stmt.type == ast.WITH then
        recurse(stmt.body, stmt.type)
      end
    end
    if visitors.visit_after then visitors.visit_after(body, parent_type) end
  end
  recurse(program.body, nil)
end

return walker
