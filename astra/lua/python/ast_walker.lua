local ast = require("python.ast")

local walker = {}

-- Walks the entire program AST, calling callbacks for each node.
-- opts.early_expr(expr) -- called before children; return "skip" to skip children
-- opts.on_expr(expr)    -- called after children
-- opts.early_stmt(stmt) -- called before children; return "skip" to skip children
-- opts.on_stmt(stmt)    -- called after children
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
        for _, s in ipairs(handler.body or {}) do walk_stmt(s) end
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
    end
    if opts.on_stmt then opts.on_stmt(stmt) end
  end

  for _, stmt in ipairs(program.body or {}) do
    walk_stmt(stmt)
  end
end

-- Walks into nested statement bodies without walking expressions
-- Used by pruning passes that only modify statement lists in-place
-- fn(body) is called for each nested body found
function walker.walk_stmt_bodies(body, fn)
  if not body then return end
  for _, stmt in ipairs(body) do
    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      fn(stmt.body)
    elseif stmt.type == ast.IF then
      fn(stmt.body)
      for _, elif in ipairs(stmt.elifs or {}) do fn(elif.body) end
      fn(stmt.or_else)
    elseif stmt.type == ast.WHILE or stmt.type == ast.FOR then
      fn(stmt.body)
      fn(stmt.or_else)
    elseif stmt.type == ast.TRY then
      fn(stmt.body)
      for _, handler in ipairs(stmt.handlers or {}) do fn(handler.body) end
      fn(stmt.finally_body)
    end
  end
end

return walker
