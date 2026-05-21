local ast = require("python.ast")
local token = require("python.token")
local util = require("python.util")
local TK = token.TK
local token_names = token.token_names
local multiplicative_operators = token.multiplicative_operators

local parser = {}
function parser.parse(tokens)
  local pos = 1

  local function peek_token()
    return tokens[pos]
  end
  local function advance_token()
    local token = tokens[pos]
    pos = pos + 1
    return token
  end

  local peek_is, peek_not, peek_one_of, parse_block, parse_or_else_block, parse_block_body, parse_statements

  local function expect_token(kind)
    local token = peek_token()
    if not token or token.kind ~= kind then
      error(
        "expected "
          .. (token_names[kind] or kind)
          .. " got "
          .. (token and (token_names[token.kind] or token.kind) or "EOF")
          .. " at line "
          .. (token and token.line or "?")
          .. " col "
          .. (token and token.col or "?")
      )
    end
    return advance_token()
  end

  local function match_token(kind)
    local token = peek_token()
    if token and token.kind == kind then
      advance_token()
      return true
    end
    return false
  end

  local function expect_colon_newline()
    expect_token(TK.COLON)
    if peek_is(TK.NEWLINE) then
      advance_token()
    end
  end

  peek_is = function(kind)
    return peek_token() and peek_token().kind == kind
  end

  peek_not = function(kind)
    return peek_token() and peek_token().kind ~= kind
  end

  peek_one_of = function(...)
    local t = peek_token()
    if not t then
      return false
    end
    for _, k in ipairs({ ... }) do
      if t.kind == k then
        return true
      end
    end
    return false
  end

  parse_block = function()
    expect_colon_newline()
    return parse_block_body()
  end

  parse_or_else_block = function()
    if peek_is(TK.ELSE) then
      advance_token()
      return parse_block()
    end
    return nil
  end

  -- declare parser functions for Lua 5.1
  local parse_program, parse_stmt, parse_simple_stmt
  local parse_func_def, parse_class_def, parse_if, parse_while, parse_for, parse_return, parse_try
  local parse_expr, parse_lambda, parse_walrus, parse_if_expr, parse_or, parse_and, parse_not, parse_comparison
  local parse_term, parse_factor, parse_unary, parse_power, parse_primary, parse_atom
  local parse_comprehension_clauses, parse_decorators

  parse_comprehension_clauses = function()
    local generators = {}
    while true do
      local target = expect_token(TK.IDENTIFIER).value
      expect_token(TK.IN)
      local iterator = parse_or()
      local ifs = {}
      while peek_is(TK.IF) do
        advance_token()
        ifs[#ifs + 1] = parse_or()
      end
      generators[#generators + 1] = { target = target, iterator = iterator, ifs = ifs }
      if peek_is(TK.FOR) then
        advance_token()
      else
        break
      end
    end
    return generators
  end

  local function skip_continuation_tokens()
    while
      peek_token()
      and (peek_token().kind == TK.NEWLINE or peek_token().kind == TK.INDENT or peek_token().kind == TK.DEDENT)
    do
      advance_token()
    end
  end

  local function parse_call_arg_star(args, keywords)
    if peek_is(TK.DOUBLESTAR) then
      advance_token()
      args[#args + 1] = ast.Starred(parse_expr(), true)
      return
    end
    if peek_is(TK.STAR) then
      advance_token()
      args[#args + 1] = ast.Starred(parse_expr())
      return
    end
    local current_token = peek_token()
    local next_token = pos + 1 <= #tokens and tokens[pos + 1] or nil
    if current_token and current_token.kind == TK.IDENTIFIER and next_token and next_token.kind == TK.EQ then
      advance_token()
      advance_token()
      keywords[#keywords + 1] = { arg = current_token.value, value = parse_expr() }
    else
      args[#args + 1] = parse_expr()
    end
  end

  -- Parses a block of statements, skipping blank lines and
  -- dispatching to the statement handler table
  parse_statements = function()
    local body = {}
    while peek_not(TK.DEDENT) and peek_token().kind ~= TK.EOF do
      while peek_is(TK.NEWLINE) do
        advance_token()
      end
      if peek_one_of(TK.DEDENT, TK.EOF) then
        break
      end
      local stmts = parse_stmt()
      if stmts then
        for _, s in ipairs(stmts) do
          body[#body + 1] = s
        end
      end
      while peek_is(TK.NEWLINE) do
        advance_token()
      end
    end
    return body
  end

  parse_program = function()
    while peek_is(TK.NEWLINE) do
      advance_token()
    end
    return ast.Program(parse_statements())
  end

  local stmt_dispatch = {
    [TK.DEF] = function()
      return { parse_func_def() }
    end,
    [TK.CLASS] = function()
      return { parse_class_def() }
    end,
    [TK.IF] = function()
      return { parse_if() }
    end,
    [TK.WHILE] = function()
      return { parse_while() }
    end,
    [TK.FOR] = function()
      return { parse_for() }
    end,
    [TK.RETURN] = function()
      return { parse_return() }
    end,
    [TK.PASS] = function()
      advance_token()
      return { ast.Pass() }
    end,
    [TK.BREAK] = function()
      advance_token()
      return { ast.Break() }
    end,
    [TK.CONTINUE] = function()
      advance_token()
      return { ast.Continue() }
    end,
    [TK.TRY] = function()
      return { parse_try() }
    end,
  }

  parse_stmt = function()
    local token = peek_token()
    if not token then
      return nil
    end
    local handler = stmt_dispatch[token.kind]
    if handler then
      return handler()
    end
    if token.kind == TK.AT then
      local decos = parse_decorators()
      local next_kind = peek_token() and peek_token().kind
      if next_kind == TK.DEF then
        return { parse_func_def(decos) }
      elseif next_kind == TK.CLASS then
        return { parse_class_def(decos) }
      else
        error("decorator must precede function or class definition")
      end
    end
    return { parse_simple_stmt() }
  end

  parse_simple_stmt = function()
    if peek_is(TK.GLOBAL) then
      advance_token()
      local names = { expect_token(TK.IDENTIFIER).value }
      while match_token(TK.COMMA) do
        names[#names + 1] = expect_token(TK.IDENTIFIER).value
      end
      return ast.Global(names)
    end
    local first = parse_expr()
    local targets = { first }
    while peek_is(TK.COMMA) do
      advance_token()
      targets[#targets + 1] = parse_expr()
    end
    if match_token(TK.EQ) then
      local values = { parse_expr() }
      while match_token(TK.COMMA) do
        values[#values + 1] = parse_expr()
      end
      if #values == 1 then
        return ast.Assign(targets, values[1])
      else
        return ast.Assign(targets, ast.Tuple(values))
      end
    end
    local aug_ops =
      { [TK.PLUSEQ] = "+", [TK.MINUSEQ] = "-", [TK.STAREQ] = "*", [TK.SLASHEQ] = "/", [TK.PERCENTEQ] = "%" }
    local aug_kind = peek_token() and peek_token().kind
    if aug_ops[aug_kind] then
      advance_token()
      return ast.AugAssign(targets[1], aug_ops[aug_kind], parse_expr())
    else
      return ast.ExprStmt(targets[1])
    end
  end

  parse_func_def = function(decorators)
    advance_token()
    local name = expect_token(TK.IDENTIFIER)
    expect_token(TK.LPAREN)
    local args = {}
    local defaults = {}
    local vararg = nil
    local kwarg = nil
    if peek_not(TK.RPAREN) then
      local function parse_param()
        if peek_is(TK.DOUBLESTAR) then
          advance_token()
          kwarg = expect_token(TK.IDENTIFIER).value
          return true
        elseif peek_is(TK.STAR) then
          advance_token()
          if peek_not(TK.IDENTIFIER) then
            return true
          end
          vararg = expect_token(TK.IDENTIFIER).value
          return true
        else
          args[#args + 1] = expect_token(TK.IDENTIFIER).value
          if peek_is(TK.EQ) then
            advance_token()
            defaults[#args] = parse_expr()
          end
          return false
        end
      end
      parse_param()
      while match_token(TK.COMMA) do
        parse_param()
      end
    end
    expect_token(TK.RPAREN)
    local body = parse_block()
    return ast.FunctionDef(name.value, args, body, decorators, vararg, kwarg, defaults)
  end

  parse_class_def = function(decorators)
    advance_token()
    local name = expect_token(TK.IDENTIFIER).value
    local bases = {}
    if match_token(TK.LPAREN) then
      if peek_not(TK.RPAREN) then
        bases[1] = parse_expr()
        while match_token(TK.COMMA) do
          bases[#bases + 1] = parse_expr()
        end
      end
      expect_token(TK.RPAREN)
    end
    local body = parse_block()
    return ast.ClassDef(name, bases, body, decorators)
  end

  parse_decorators = function()
    local decorators = {}
    while peek_is(TK.AT) do
      advance_token()
      decorators[#decorators + 1] = parse_primary()
      if peek_is(TK.NEWLINE) then
        advance_token()
      end
    end
    return decorators
  end

  parse_if = function()
    advance_token()
    local test = parse_expr()
    local body = parse_block()
    local elifs = {}
    local or_else = nil
    while peek_is(TK.ELIF) do
      advance_token()
      local et = parse_expr()
      local elif_body = parse_block()
      elifs[#elifs + 1] = { test = et, body = elif_body }
    end
    or_else = parse_or_else_block()
    return ast.If(test, body, elifs, or_else)
  end

  parse_while = function()
    advance_token()
    local test = parse_expr()
    local body = parse_block()
    local or_else = parse_or_else_block()
    return ast.While(test, body, or_else)
  end

  parse_for = function()
    advance_token()
    local targets = { expect_token(TK.IDENTIFIER).value }
    while match_token(TK.COMMA) do
      targets[#targets + 1] = expect_token(TK.IDENTIFIER).value
    end
    expect_token(TK.IN)
    local iterator = nil
    local is_range = false
    local range_args = {}
    if peek_is(TK.IDENTIFIER) and peek_token().value == "range" then
      advance_token()
      if peek_is(TK.LPAREN) then
        advance_token()
        is_range = true
        range_args[1] = parse_expr()
        while match_token(TK.COMMA) do
          range_args[#range_args + 1] = parse_expr()
        end
        expect_token(TK.RPAREN)
      end
    else
      iterator = parse_primary()
    end
    local body = parse_block()
    local or_else = parse_or_else_block()
    return ast.For(targets, iterator, body, or_else, is_range, range_args)
  end

  parse_try = function()
    advance_token()
    local body = parse_block()
    local handlers = {}
    local finally_body = nil
    while peek_is(TK.EXCEPT) do
      advance_token()
      local exception_type = nil
      local exception_var = nil
      if peek_not(TK.COLON) then
        exception_type = parse_expr()
        if peek_is(TK.AS) then
          advance_token()
          exception_var = expect_token(TK.IDENTIFIER).value
        end
      end
      local handler_body = parse_block()
      handlers[#handlers + 1] = { type = exception_type, name = exception_var, body = handler_body }
    end
    if peek_is(TK.FINALLY) then
      advance_token()
      finally_body = parse_block()
    end
    return ast.Try(body, handlers, finally_body)
  end

  parse_return = function()
    advance_token()
    if
      peek_token()
      and peek_token().kind ~= TK.NEWLINE
      and peek_token().kind ~= TK.DEDENT
      and peek_token().kind ~= TK.EOF
    then
      return ast.Return(parse_expr())
    else
      return ast.Return(nil)
    end
  end

  parse_block_body = function()
    while peek_is(TK.NEWLINE) do
      advance_token()
    end
    expect_token(TK.INDENT)
    local body = parse_statements()
    expect_token(TK.DEDENT)
    return body
  end

  -- expression parsing
  parse_expr = function()
    return parse_lambda()
  end
  parse_lambda = function()
    if peek_is(TK.LAMBDA) then
      advance_token()
      local args = {}
      local has_vararg = false
      if peek_not(TK.COLON) then
        if peek_is(TK.STAR) then
          advance_token()
          if peek_is(TK.IDENTIFIER) then
            args[#args + 1] = "*" .. expect_token(TK.IDENTIFIER).value
          end
          has_vararg = true
        else
          args[#args + 1] = expect_token(TK.IDENTIFIER).value
        end
        while match_token(TK.COMMA) do
          if peek_is(TK.STAR) then
            advance_token()
            if peek_is(TK.IDENTIFIER) then
              args[#args + 1] = "*" .. expect_token(TK.IDENTIFIER).value
            end
            has_vararg = true
          else
            args[#args + 1] = expect_token(TK.IDENTIFIER).value
          end
        end
      end
      expect_token(TK.COLON)
      local lambda_ast = ast.Lambda(args, parse_lambda())
      if has_vararg then
        lambda_ast.has_vararg = true
      end
      return lambda_ast
    end
    return parse_walrus()
  end
  parse_walrus = function()
    local result = parse_if_expr()
    if peek_is(TK.WALRUS) then
      advance_token()
      result = ast.Walrus(result, parse_walrus())
    end
    return result
  end
  parse_if_expr = function()
    local body = parse_or()
    if peek_is(TK.IF) then
      advance_token()
      local test = parse_or()
      expect_token(TK.ELSE)
      body = ast.IfExpr(test, body, parse_if_expr())
    end
    return body
  end
  parse_or = function()
    local left = parse_and()
    while peek_is(TK.OR) do
      advance_token()
      local r = parse_and()
      left = ast.BoolOp("or", { left, r })
    end
    return left
  end
  parse_and = function()
    local left = parse_not()
    while peek_is(TK.AND) do
      advance_token()
      local r = parse_not()
      left = ast.BoolOp("and", { left, r })
    end
    return left
  end
  parse_not = function()
    if peek_is(TK.NOT) then
      advance_token()
      return ast.UnaryOp("not", parse_not())
    end
    return parse_comparison()
  end

  parse_comparison = function()
    local left = parse_term()
    local comparison_ops = {
      [TK.EQEQ] = "==",
      [TK.NOTEQ] = "!=",
      [TK.LESS] = "<",
      [TK.GREATER] = ">",
      [TK.LESSEQ] = "<=",
      [TK.GREATEREQ] = ">=",
    }
    local cmp_ops = {}
    local cmp_rights = {}
    while peek_token() do
      local current_token = peek_token()
      local op = comparison_ops[current_token.kind]
      if not op and current_token.kind == TK.IS then
        advance_token()
        if peek_is(TK.NOT) then
          advance_token()
          op = "is not"
        else
          op = "is"
        end
      elseif not op and current_token.kind == TK.IN then
        advance_token()
        op = "in"
      elseif not op and current_token.kind == TK.NOT then
        local saved_pos = pos
        advance_token()
        if peek_is(TK.IN) then
          advance_token()
          op = "not in"
        else
          pos = saved_pos
          break
        end
      elseif op then
        advance_token()
      else
        break
      end
      cmp_ops[#cmp_ops + 1] = op
      cmp_rights[#cmp_rights + 1] = parse_term()
    end
    if #cmp_ops == 0 then
      return left
    end
    return ast.Compare(left, cmp_ops, cmp_rights)
  end

  parse_term = function()
    local left = parse_factor()
    while peek_one_of(TK.PLUS, TK.MINUS) do
      local op = advance_token()
      left = ast.BinOp(left, op.value, parse_factor())
    end
    return left
  end

  parse_factor = function()
    local left = parse_unary()
    while peek_token() and multiplicative_operators[peek_token().kind] do
      local op = advance_token()
      left = ast.BinOp(left, op.value, parse_unary())
    end
    return left
  end

  parse_unary = function()
    if peek_one_of(TK.PLUS, TK.MINUS) then
      return ast.UnaryOp(advance_token().value, parse_unary())
    end
    return parse_power()
  end

  parse_power = function()
    local left = parse_primary()
    if peek_is(TK.DOUBLESTAR) then
      advance_token()
      left = ast.BinOp(left, "**", parse_unary())
    end
    return left
  end

  -- Parses chained calls, subscripts, and attribute access after a primary expression
  parse_primary = function()
    local expr = parse_atom()
    while true do
      if peek_is(TK.LPAREN) then
        advance_token()
        skip_continuation_tokens()
        local args = {}
        local keywords = {}
        if peek_not(TK.RPAREN) then
          parse_call_arg_star(args, keywords)
          while match_token(TK.COMMA) do
            parse_call_arg_star(args, keywords)
          end
        end
        skip_continuation_tokens()
        expect_token(TK.RPAREN)
        if #keywords > 0 then
          expr = ast.Call(expr, args, keywords)
        else
          expr = ast.Call(expr, args)
        end
      elseif peek_is(TK.LBRACKET) then
        advance_token()
        if peek_is(TK.COLON) then
          advance_token()
          local lower, upper, step = nil, nil, nil
          if peek_not(TK.RBRACKET) and peek_token().kind ~= TK.COLON then
            upper = parse_expr()
          end
          if peek_is(TK.COLON) then
            advance_token()
            if peek_not(TK.RBRACKET) then
              step = parse_expr()
            end
          end
          expect_token(TK.RBRACKET)
          expr = ast.Subscript(expr, ast.Slice(lower, upper, step))
        else
          local idx = parse_expr()
          if peek_is(TK.COLON) then
            advance_token()
            local upper, step = nil, nil
            if peek_not(TK.RBRACKET) and peek_token().kind ~= TK.COLON then
              upper = parse_expr()
            end
            if peek_is(TK.COLON) then
              advance_token()
              if peek_not(TK.RBRACKET) then
                step = parse_expr()
              end
            end
            expect_token(TK.RBRACKET)
            expr = ast.Subscript(expr, ast.Slice(idx, upper, step))
          else
            expect_token(TK.RBRACKET)
            expr = ast.Subscript(expr, idx)
          end
        end
      elseif peek_is(TK.DOT) then
        advance_token()
        expr = ast.Attribute(expr, expect_token(TK.IDENTIFIER).value)
      else
        break
      end
    end
    return expr
  end

  -- Parses atomic expressions: literals, identifiers, containers (list/dict/set/tuple),
  -- comprehensions, parenthesized expressions, and the super() pseudo-expression
  local function parse_paren_expr()
    advance_token()
    skip_continuation_tokens()
    local first = parse_expr()
    skip_continuation_tokens()
    if match_token(TK.COMMA) then
      local elements = { first }
      while peek_not(TK.RPAREN) do
        elements[#elements + 1] = parse_expr()
        skip_continuation_tokens()
        match_token(TK.COMMA)
        skip_continuation_tokens()
      end
      expect_token(TK.RPAREN)
      return ast.Tuple(elements)
    end
    expect_token(TK.RPAREN)
    return first
  end

  local function parse_bracket_expr()
    advance_token()
    local first = parse_expr()
    if peek_is(TK.FOR) then
      advance_token()
      local generators = parse_comprehension_clauses()
      expect_token(TK.RBRACKET)
      return ast.ListComp(first, generators)
    end
    local elements = { first }
    while match_token(TK.COMMA) do
      elements[#elements + 1] = parse_expr()
    end
    expect_token(TK.RBRACKET)
    return ast.List(elements)
  end

  local function parse_brace_expr()
    advance_token()
    skip_continuation_tokens()
    if peek_not(TK.RBRACE) then
      local first = parse_expr()
      skip_continuation_tokens()
      if peek_is(TK.COLON) then
        advance_token()
        local key = first
        skip_continuation_tokens()
        local val = parse_expr()
        skip_continuation_tokens()
        if peek_is(TK.FOR) then
          advance_token()
          local generators = parse_comprehension_clauses()
          skip_continuation_tokens()
          expect_token(TK.RBRACE)
          return ast.DictComp(key, val, generators)
        end
        local keys = { key }
        local vals = { val }
        while match_token(TK.COMMA) do
          skip_continuation_tokens()
          if peek_is(TK.RBRACE) then break end
          keys[#keys + 1] = parse_expr()
          expect_token(TK.COLON)
          skip_continuation_tokens()
          if peek_is(TK.RBRACE) then break end
          vals[#vals + 1] = parse_expr()
          skip_continuation_tokens()
        end
        skip_continuation_tokens()
        expect_token(TK.RBRACE)
        return ast.Dict(keys, vals)
      else
        if peek_is(TK.FOR) then
          advance_token()
          local generators = parse_comprehension_clauses()
          skip_continuation_tokens()
          expect_token(TK.RBRACE)
          return ast.SetComp(first, generators)
        end
        local elements = { first }
        while match_token(TK.COMMA) do
          skip_continuation_tokens()
          elements[#elements + 1] = parse_expr()
          skip_continuation_tokens()
        end
        skip_continuation_tokens()
        expect_token(TK.RBRACE)
        return ast.Set(elements)
      end
    else
      skip_continuation_tokens()
      expect_token(TK.RBRACE)
      return ast.Dict({}, {})
    end
  end

  parse_atom = function()
    local current_token = peek_token()
    if not current_token then
      error("unexpected EOF")
    end
    local atom_handlers = {
      [TK.NONE]     = function() advance_token(); return ast.Constant(nil) end,
      [TK.TRUE]     = function() advance_token(); return ast.Constant(true) end,
      [TK.FALSE]    = function() advance_token(); return ast.Constant(false) end,
      [TK.ELLIPSIS] = function() advance_token(); return ast.Constant(nil) end,
      [TK.INTEGER]  = function() advance_token(); return ast.Constant(tonumber(current_token.value)) end,
      [TK.FLOAT]    = function() advance_token(); return ast.Constant(tonumber(current_token.value)) end,
      [TK.STRING]   = function()
        advance_token()
        local val = current_token.value:sub(2, #current_token.value - 1)
        return ast.Constant(util.unescape(val))
      end,
      [TK.IDENTIFIER] = function()
        advance_token()
        if current_token.value == "super" then
          return ast.Super()
        end
        return ast.Name(current_token.value)
      end,
      [TK.LPAREN]   = parse_paren_expr,
      [TK.LBRACKET] = parse_bracket_expr,
      [TK.LBRACE]   = parse_brace_expr,
    }
    local handler = atom_handlers[current_token.kind]
    if handler then return handler() end
    error(
      "unexpected token "
        .. (token_names[current_token.kind] or current_token.kind)
        .. " ("
        .. current_token.value
        .. ") at line "
        .. current_token.line
        .. " col "
        .. current_token.col
    )
  end

  return parse_program()
end

return parser
