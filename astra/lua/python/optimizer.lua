local ast = require("python.ast")

local optimizer = {}

local function kwarg_pass(prog, analysis)
  analysis.has_kwargs = false

  local function walk_expr(expr)
    if analysis.has_kwargs then return end
    if not expr or type(expr) ~= "table" then return end

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
      walk_expr(expr.left); walk_expr(expr.right)
    elseif expr.type == ast.UNARY_OP then
      walk_expr(expr.operand)
    elseif expr.type == ast.BOOL_OP then
      for _, v in ipairs(expr.values) do
        walk_expr(v)
      end
    elseif expr.type == ast.COMPARE then
      walk_expr(expr.left)
      for _, c in ipairs(expr.comparators) do
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
      for _, v in ipairs(expr.values or {}) do
        walk_expr(v)
      end
    elseif expr.type == ast.LAMBDA then
      walk_expr(expr.body)
    elseif expr.type == ast.WALRUS then
      walk_expr(expr.target); walk_expr(expr.value)
    elseif expr.type == ast.IF_EXPR then
      walk_expr(expr.test); walk_expr(expr.body); walk_expr(expr.or_else)
    elseif expr.type == ast.LIST_COMP or expr.type == ast.SET_COMP then
      walk_expr(expr.element)
      for _, g in ipairs(expr.generators or {}) do
        walk_expr(g.iterator)
        for _, if_expr in ipairs(g.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.DICT_COMP then
      walk_expr(expr.key); walk_expr(expr.value)
      for _, g in ipairs(expr.generators or {}) do
        walk_expr(g.iterator)
        for _, if_expr in ipairs(g.ifs or {}) do
          walk_expr(if_expr)
        end
      end
    elseif expr.type == ast.STARRED then
      walk_expr(expr.value)
    end
  end

  local function walk_stmt(stmt)
    if analysis.has_kwargs then return end
    if not stmt or type(stmt) ~= "table" then return end

    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.CLASS_DEF then
      for _, d in ipairs(stmt.decorators or {}) do
        walk_expr(d)
      end
      for _, s in ipairs(stmt.body or {}) do
        walk_stmt(s)
      end
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
      for _, h in ipairs(stmt.handlers or {}) do
        for _, s in ipairs(h.body or {}) do walk_stmt(s) end
      end
      if stmt.finally_body then
        for _, s in ipairs(stmt.finally_body) do walk_stmt(s) end
      end
    elseif stmt.type == ast.RETURN then
      if stmt.value then walk_expr(stmt.value) end
    elseif stmt.type == ast.ASSIGN then
      for _, t in ipairs(stmt.targets or {}) do walk_expr(t) end
      if stmt.value then walk_expr(stmt.value) end
    elseif stmt.type == ast.AUG_ASSIGN then
      walk_expr(stmt.target)
      walk_expr(stmt.value)
    elseif stmt.type == ast.EXPR_STMT then
      walk_expr(stmt.expr)
    end
  end

  for _, stmt in ipairs(prog.body or {}) do
    walk_stmt(stmt)
    if analysis.has_kwargs then break end
  end
end

function optimizer.analyze(prog, opts)
  opts = opts or {}
  local analysis = {}
  local optimize = opts.optimize ~= false

  if optimize and opts.kwarg_analysis ~= false then
    kwarg_pass(prog, analysis)
  end

  return analysis
end

return optimizer
