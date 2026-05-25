local ast = require("python.ast")
local TK = require("python.token").TK

return function(state, expr)
  local stmt = {}

  local function expect_colon_newline()
    state:expect_token(TK.COLON)
    while state:peek_is(TK.COMMENT) do
      state:advance_token()
    end
    if state:peek_is(TK.NEWLINE) then
      state:advance_token()
    end
  end

  local function parse_block(parse_block_body)
    expect_colon_newline()
    return parse_block_body()
  end

  local function parse_or_else_block(parse_block_body)
    if state:peek_is(TK.ELSE) then
      state:advance_token()
      return parse_block(parse_block_body)
    end
    return nil
  end

  stmt.parse_func_def = function(decorators, parse_block_body)
    state:advance_token()
    local name = state:expect_token(TK.IDENTIFIER)
    state:expect_token(TK.LPAREN)
    local args = {}
    local defaults = {}
    local vararg = nil
    local kwarg = nil
    if state:peek_not(TK.RPAREN) then
      local function parse_param()
        if state:peek_is(TK.DOUBLESTAR) then
          state:advance_token()
          kwarg = state:expect_token(TK.IDENTIFIER).value
          return true
        elseif state:peek_is(TK.STAR) then
          state:advance_token()
          if state:peek_not(TK.IDENTIFIER) then
            return true
          end
          vararg = state:expect_token(TK.IDENTIFIER).value
          return true
        else
          args[#args + 1] = state:expect_token(TK.IDENTIFIER).value
          if state:peek_is(TK.EQ) then
            state:advance_token()
            defaults[#args] = expr.parse_expr()
          end
          return false
        end
      end
      parse_param()
      while state:match_token(TK.COMMA) do
        parse_param()
      end
    end
    state:expect_token(TK.RPAREN)
    local body = parse_block(parse_block_body)
    return ast.FunctionDef(name.value, args, body, decorators, vararg, kwarg, defaults)
  end

  stmt.parse_class_def = function(decorators, parse_block_body)
    state:advance_token()
    local name = state:expect_token(TK.IDENTIFIER).value
    local bases = {}
    if state:match_token(TK.LPAREN) then
      if state:peek_not(TK.RPAREN) then
        bases[1] = expr.parse_expr()
        while state:match_token(TK.COMMA) do
          bases[#bases + 1] = expr.parse_expr()
        end
      end
      state:expect_token(TK.RPAREN)
    end
    local body = parse_block(parse_block_body)
    return ast.ClassDef(name, bases, body, decorators)
  end

  stmt.parse_decorators = function()
    local decorators = {}
    while state:peek_is(TK.AT) do
      state:advance_token()
      decorators[#decorators + 1] = expr.parse_primary()
      while state:peek_one_of(TK.NEWLINE, TK.COMMENT) do
        state:advance_token()
      end
    end
    return decorators
  end

  stmt.parse_if = function(parse_block_body)
    state:advance_token()
    local test = expr.parse_expr()
    local body = parse_block(parse_block_body)
    local elifs = {}
    local or_else = nil
    while state:peek_is(TK.ELIF) do
      state:advance_token()
      local et = expr.parse_expr()
      local elif_body = parse_block(parse_block_body)
      elifs[#elifs + 1] = { test = et, body = elif_body }
    end
    or_else = parse_or_else_block(parse_block_body)
    return ast.If(test, body, elifs, or_else)
  end

  stmt.parse_while = function(parse_block_body)
    state:advance_token()
    local test = expr.parse_expr()
    local body = parse_block(parse_block_body)
    local or_else = parse_or_else_block(parse_block_body)
    return ast.While(test, body, or_else)
  end

  stmt.parse_for = function(parse_block_body)
    state:advance_token()
    local targets = { state:expect_token(TK.IDENTIFIER).value }
    while state:match_token(TK.COMMA) do
      targets[#targets + 1] = state:expect_token(TK.IDENTIFIER).value
    end
    state:expect_token(TK.IN)
    local iterator = nil
    local is_range = false
    local range_args = {}
    if state:peek_is(TK.IDENTIFIER) and state:peek_token().value == "range" then
      state:advance_token()
      if state:peek_is(TK.LPAREN) then
        state:advance_token()
        is_range = true
        range_args[1] = expr.parse_expr()
        while state:match_token(TK.COMMA) do
          range_args[#range_args + 1] = expr.parse_expr()
        end
        state:expect_token(TK.RPAREN)
      end
    else
      iterator = expr.parse_primary()
    end
    local body = parse_block(parse_block_body)
    local or_else = parse_or_else_block(parse_block_body)
    return ast.For(targets, iterator, body, or_else, is_range, range_args)
  end

  stmt.parse_try = function(parse_block_body)
    state:advance_token()
    local body = parse_block(parse_block_body)
    local handlers = {}
    local finally_body = nil
    while state:peek_is(TK.EXCEPT) do
      state:advance_token()
      local exception_type = nil
      local exception_var = nil
      if state:peek_not(TK.COLON) then
        exception_type = expr.parse_expr()
        if state:peek_is(TK.AS) then
          state:advance_token()
          exception_var = state:expect_token(TK.IDENTIFIER).value
        end
      end
      local handler_body = parse_block(parse_block_body)
      handlers[#handlers + 1] = { type = exception_type, name = exception_var, body = handler_body }
    end
    local or_else = nil
    if state:peek_is(TK.ELSE) then
      state:advance_token()
      or_else = parse_block(parse_block_body)
    end
    if state:peek_is(TK.FINALLY) then
      state:advance_token()
      finally_body = parse_block(parse_block_body)
    end
    return ast.Try(body, handlers, finally_body, or_else)
  end

  stmt.parse_import_name = function()
    local name_parts = { state:expect_token(TK.IDENTIFIER).value }
    while state:match_token(TK.DOT) do
      name_parts[#name_parts + 1] = state:expect_token(TK.IDENTIFIER).value
    end
    local name = table.concat(name_parts, ".")
    local as_name = nil
    if state:match_token(TK.AS) then
      as_name = state:expect_token(TK.IDENTIFIER).value
    end
    return { name = name, as_name = as_name }
  end

  stmt.parse_import_stmt = function()
    if state:peek_is(TK.IMPORT) then
      state:advance_token()
      local names = { stmt.parse_import_name() }
      while state:match_token(TK.COMMA) do
        names[#names + 1] = stmt.parse_import_name()
      end
      return { ast.Import(names) }
    else
      state:advance_token()
      local module_parts = { state:expect_token(TK.IDENTIFIER).value }
      while state:match_token(TK.DOT) do
        module_parts[#module_parts + 1] = state:expect_token(TK.IDENTIFIER).value
      end
      local module_name = table.concat(module_parts, ".")
      state:expect_token(TK.IMPORT)
      local names = {}
      if state:peek_is(TK.STAR) then
        state:advance_token()
        names = { { name = "*", as_name = nil } }
      else
        names[#names + 1] = stmt.parse_import_name()
        while state:match_token(TK.COMMA) do
          names[#names + 1] = stmt.parse_import_name()
        end
      end
      return { ast.ImportFrom(module_name, names) }
    end
  end

  stmt.parse_return = function()
    state:advance_token()
    if
      state:peek_token()
      and state:peek_token().kind ~= TK.NEWLINE
      and state:peek_token().kind ~= TK.DEDENT
      and state:peek_token().kind ~= TK.EOF
    then
      local first = expr.parse_expr()
      if state:peek_is(TK.COMMA) then
        local elements = { first }
        while state:peek_is(TK.COMMA) do
          state:advance_token()
          elements[#elements + 1] = expr.parse_expr()
        end
        return ast.Return(ast.Tuple(elements))
      end
      return ast.Return(first)
    else
      return ast.Return(nil)
    end
  end

  stmt.parse_raise = function()
    state:advance_token()
    if
      state:peek_token()
      and state:peek_token().kind ~= TK.NEWLINE
      and state:peek_token().kind ~= TK.DEDENT
      and state:peek_token().kind ~= TK.EOF
    then
      local exc = expr.parse_expr()
      local cause = nil
      if state:peek_is(TK.FROM) then
        state:advance_token()
        cause = expr.parse_expr()
      end
      return ast.Raise(exc, cause)
    else
      return ast.Raise(nil, nil)
    end
  end

  stmt.parse_assert = function()
    state:advance_token()
    local test = expr.parse_expr()
    local message = nil
    if state:peek_is(TK.COMMA) then
      state:advance_token()
      message = expr.parse_expr()
    end
    return ast.Assert(test, message)
  end

  stmt.parse_del = function()
    state:advance_token()
    local target = expr.parse_expr()
    return ast.Del(target)
  end

  stmt.parse_nonlocal = function()
    state:advance_token()
    local names = { state:expect_token(TK.IDENTIFIER).value }
    while state:match_token(TK.COMMA) do
      names[#names + 1] = state:expect_token(TK.IDENTIFIER).value
    end
    return ast.Nonlocal(names)
  end

  stmt.parse_with = function(parse_block_body)
    state:advance_token()
    local items = {}
    local context_expr = expr.parse_expr()
    local optional_vars = nil
    if state:peek_is(TK.AS) then
      state:advance_token()
      optional_vars = expr.parse_expr()
    end
    items[1] = { context_expr = context_expr, optional_vars = optional_vars }
    while state:match_token(TK.COMMA) do
      context_expr = expr.parse_expr()
      optional_vars = nil
      if state:peek_is(TK.AS) then
        state:advance_token()
        optional_vars = expr.parse_expr()
      end
      items[#items + 1] = { context_expr = context_expr, optional_vars = optional_vars }
    end
    local body = parse_block(parse_block_body)
    return ast.With(items, body)
  end

  stmt.parse_yield = function()
    state:advance_token()
    if
      state:peek_token()
      and state:peek_token().kind ~= TK.NEWLINE
      and state:peek_token().kind ~= TK.DEDENT
      and state:peek_token().kind ~= TK.EOF
    then
      return ast.Yield(expr.parse_expr())
    else
      return ast.Yield(nil)
    end
  end

  stmt.parse_async_function_def = function(decorators, parse_block_body)
    state:advance_token()
    local func = stmt.parse_func_def(decorators, parse_block_body)
    return ast.AsyncFunctionDef(func.name, func.args, func.body, func.decorators, func.vararg, func.kwarg, func.defaults)
  end

  stmt.parse_simple_stmt = function()
    if state:peek_is(TK.GLOBAL) then
      state:advance_token()
      local names = { state:expect_token(TK.IDENTIFIER).value }
      while state:match_token(TK.COMMA) do
        names[#names + 1] = state:expect_token(TK.IDENTIFIER).value
      end
      return ast.Global(names)
    end
    local first = expr.parse_expr()
    local targets = { first }
    while state:peek_is(TK.COMMA) do
      state:advance_token()
      targets[#targets + 1] = expr.parse_expr()
    end
    if state:match_token(TK.EQ) then
      local values = { expr.parse_expr() }
      local chain = false
      while state:match_token(TK.EQ) do
        chain = true
        for _, v in ipairs(values) do
          targets[#targets + 1] = v
        end
        values = { expr.parse_expr() }
      end
      while state:match_token(TK.COMMA) do
        values[#values + 1] = expr.parse_expr()
      end
      local assign
      if #values == 1 then
        assign = ast.Assign(targets, values[1])
      else
        assign = ast.Assign(targets, ast.Tuple(values))
      end
      assign.chain = chain
      return assign
    end
    local aug_ops =
      { [TK.PLUSEQ] = "+", [TK.MINUSEQ] = "-", [TK.STAREQ] = "*", [TK.SLASHEQ] = "/", [TK.PERCENTEQ] = "%",
        [TK.DOUBLESTAREQ] = "**", [TK.DOUBLESLASHEQ] = "//",
        [TK.PIPEEQ] = "|", [TK.CARETEQ] = "^", [TK.AMPERSANDEQ] = "&",
        [TK.LEFTSHIFTEQ] = "<<", [TK.RIGHTSHIFTEQ] = ">>" }
    local aug_kind = state:peek_token() and state:peek_token().kind
    if aug_ops[aug_kind] then
      state:advance_token()
      return ast.AugAssign(targets[1], aug_ops[aug_kind], expr.parse_expr())
    else
      return ast.ExprStmt(targets[1])
    end
  end

  local stmt_dispatch = {
    [TK.DEF] = function(parse_block_body)
      return { stmt.parse_func_def(nil, parse_block_body) }
    end,
    [TK.CLASS] = function(parse_block_body)
      return { stmt.parse_class_def(nil, parse_block_body) }
    end,
    [TK.IF] = function(parse_block_body)
      return { stmt.parse_if(parse_block_body) }
    end,
    [TK.WHILE] = function(parse_block_body)
      return { stmt.parse_while(parse_block_body) }
    end,
    [TK.FOR] = function(parse_block_body)
      return { stmt.parse_for(parse_block_body) }
    end,
    [TK.RETURN] = function()
      return { stmt.parse_return() }
    end,
    [TK.PASS] = function()
      state:advance_token()
      return { ast.Pass() }
    end,
    [TK.BREAK] = function()
      state:advance_token()
      return { ast.Break() }
    end,
    [TK.CONTINUE] = function()
      state:advance_token()
      return { ast.Continue() }
    end,
    [TK.TRY] = function(parse_block_body)
      return { stmt.parse_try(parse_block_body) }
    end,
    [TK.RAISE] = function()
      return { stmt.parse_raise() }
    end,
    [TK.ASSERT] = function()
      return { stmt.parse_assert() }
    end,
    [TK.DEL] = function()
      return { stmt.parse_del() }
    end,
    [TK.NONLOCAL] = function()
      return { stmt.parse_nonlocal() }
    end,
    [TK.WITH] = function(parse_block_body)
      return { stmt.parse_with(parse_block_body) }
    end,
    [TK.ASYNC] = function(parse_block_body)
      if state.tokens[state.position + 1] and state.tokens[state.position + 1].kind == TK.DEF then
        return { stmt.parse_async_function_def(nil, parse_block_body) }
      end
      error("async can only precede def")
    end,
    [TK.YIELD] = function()
      return { stmt.parse_yield() }
    end,
    [TK.IMPORT] = function()
      return stmt.parse_import_stmt()
    end,
    [TK.FROM] = function()
      return stmt.parse_import_stmt()
    end,
  }

  stmt.parse_stmt = function(parse_block_body)
    local token = state:peek_token()
    if not token then
      return nil
    end
    local handler = stmt_dispatch[token.kind]
    if handler then
      return handler(parse_block_body)
    end
    if token.kind == TK.AT then
      local decos = stmt.parse_decorators()
      local next_kind = state:peek_token() and state:peek_token().kind
      if next_kind == TK.DEF then
        return { stmt.parse_func_def(decos, parse_block_body) }
      elseif next_kind == TK.CLASS then
        return { stmt.parse_class_def(decos, parse_block_body) }
      else
        error("decorator must precede function or class definition")
      end
    end
    return { stmt.parse_simple_stmt() }
  end

  return stmt
end
