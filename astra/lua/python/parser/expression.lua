local ast = require("python.ast")
local token = require("python.token")
local tokenizer = require("python.tokenizer")
local util = require("python.util")
local TK = token.TK
local token_names = token.token_names
local multiplicative_operators = token.multiplicative_operators

return function(state, top_parse)
  local expr = {}

  local function skip_continuation_tokens()
    while
      state:peek_token()
      and (
        state:peek_token().kind == TK.NEWLINE
        or state:peek_token().kind == TK.INDENT
        or state:peek_token().kind == TK.DEDENT
        or state:peek_token().kind == TK.COMMENT
      )
    do
      state:advance_token()
    end
  end

  local function parse_comprehension_clauses()
    local generators = {}
    while true do
      local target = state:expect_token(TK.IDENTIFIER).value
      state:expect_token(TK.IN)
      local iterator = expr.parse_or()
      local ifs = {}
      while state:peek_is(TK.IF) do
        state:advance_token()
        ifs[#ifs + 1] = expr.parse_or()
      end
      generators[#generators + 1] = { target = target, iterator = iterator, ifs = ifs }
      if state:peek_is(TK.FOR) then
        state:advance_token()
      else
        break
      end
    end
    return generators
  end

  local function parse_call_arg_star(args, keywords)
    if state:peek_is(TK.DOUBLESTAR) then
      state:advance_token()
      args[#args + 1] = ast.Starred(expr.parse_expr(), true)
      return
    end
    if state:peek_is(TK.STAR) then
      state:advance_token()
      args[#args + 1] = ast.Starred(expr.parse_expr())
      return
    end
    local current_token = state:peek_token()
    local next_token = state.position + 1 > #state.tokens and nil or state.tokens[state.position + 1]
    if current_token and current_token.kind == TK.IDENTIFIER and next_token and next_token.kind == TK.EQ then
      state:advance_token()
      state:advance_token()
      keywords[#keywords + 1] = { arg = current_token.value, value = expr.parse_expr() }
    else
      args[#args + 1] = expr.parse_expr()
    end
  end

  ---@return ast_node
  expr.parse_expr = function()
    return expr.parse_lambda()
  end

  expr.parse_lambda = function()
    if state:peek_is(TK.LAMBDA) then
      state:advance_token()
      local args = {}
      local has_vararg = false
      if state:peek_not(TK.COLON) then
        if state:peek_is(TK.STAR) then
          state:advance_token()
          if state:peek_is(TK.IDENTIFIER) then
            args[#args + 1] = "*" .. state:expect_token(TK.IDENTIFIER).value
          end
          has_vararg = true
        else
          args[#args + 1] = state:expect_token(TK.IDENTIFIER).value
        end
        while state:match_token(TK.COMMA) do
          if state:peek_is(TK.STAR) then
            state:advance_token()
            if state:peek_is(TK.IDENTIFIER) then
              args[#args + 1] = "*" .. state:expect_token(TK.IDENTIFIER).value
            end
            has_vararg = true
          else
            args[#args + 1] = state:expect_token(TK.IDENTIFIER).value
          end
        end
      end
      state:expect_token(TK.COLON)
      local lambda_ast = ast.Lambda(args, expr.parse_lambda())
      if has_vararg then
        lambda_ast.has_vararg = true
      end
      return lambda_ast
    end
    return expr.parse_walrus()
  end

  expr.parse_walrus = function()
    local result = expr.parse_if_expr()
    if state:peek_is(TK.WALRUS) then
      state:advance_token()
      result = ast.Walrus(result, expr.parse_walrus())
    end
    return result
  end

  expr.parse_if_expr = function()
    local body = expr.parse_or()
    if state:peek_is(TK.IF) then
      state:advance_token()
      local test = expr.parse_or()
      state:expect_token(TK.ELSE)
      body = ast.IfExpr(test, body, expr.parse_if_expr())
    end
    return body
  end

  expr.parse_or = function()
    local left = expr.parse_and()
    while state:peek_is(TK.OR) do
      state:advance_token()
      local right_expr = expr.parse_and()
      left = ast.BoolOp("or", { left, right_expr })
    end
    return left
  end

  expr.parse_and = function()
    local left = expr.parse_not()
    while state:peek_is(TK.AND) do
      state:advance_token()
      local right_expr = expr.parse_not()
      left = ast.BoolOp("and", { left, right_expr })
    end
    return left
  end

  expr.parse_not = function()
    if state:peek_is(TK.NOT) then
      state:advance_token()
      return ast.UnaryOp("not", expr.parse_not())
    end
    return expr.parse_comparison()
  end

  expr.parse_comparison = function()
    local left = expr.parse_bit_or()
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
    while state:peek_token() do
      local current_token = state:peek_token()
      local op = comparison_ops[current_token.kind]
      if not op and current_token.kind == TK.IS then
        state:advance_token()
        if state:peek_is(TK.NOT) then
          state:advance_token()
          op = "is not"
        else
          op = "is"
        end
      elseif not op and current_token.kind == TK.IN then
        state:advance_token()
        op = "in"
      elseif not op and current_token.kind == TK.NOT then
        local saved_pos = state.position
        state:advance_token()
        if state:peek_is(TK.IN) then
          state:advance_token()
          op = "not in"
        else
          state.position = saved_pos
          break
        end
      elseif op then
        state:advance_token()
      else
        break
      end
      cmp_ops[#cmp_ops + 1] = op
      cmp_rights[#cmp_rights + 1] = expr.parse_term()
    end
    if #cmp_ops == 0 then
      return left
    end
    return ast.Compare(left, cmp_ops, cmp_rights)
  end

  expr.parse_bit_or = function()
    local left = expr.parse_bit_xor()
    while state:peek_is(TK.PIPE) do
      state:advance_token()
      left = ast.BinOp(left, "|", expr.parse_bit_xor())
    end
    return left
  end

  expr.parse_bit_xor = function()
    local left = expr.parse_bit_and()
    while state:peek_is(TK.CARET) do
      state:advance_token()
      left = ast.BinOp(left, "^", expr.parse_bit_and())
    end
    return left
  end

  expr.parse_bit_and = function()
    local left = expr.parse_shift()
    while state:peek_is(TK.AMPERSAND) do
      state:advance_token()
      left = ast.BinOp(left, "&", expr.parse_shift())
    end
    return left
  end

  expr.parse_shift = function()
    local left = expr.parse_term()
    while state:peek_one_of(TK.LEFTSHIFT, TK.RIGHTSHIFT) do
      local op = state:advance_token()
      left = ast.BinOp(left, op.value, expr.parse_term())
    end
    return left
  end

  expr.parse_term = function()
    local left = expr.parse_factor()
    while state:peek_one_of(TK.PLUS, TK.MINUS) do
      local op = state:advance_token()
      left = ast.BinOp(left, op.value, expr.parse_factor())
    end
    return left
  end

  expr.parse_factor = function()
    local left = expr.parse_unary()
    while state:peek_token() and multiplicative_operators[state:peek_token().kind] do
      local op = state:advance_token()
      left = ast.BinOp(left, op.value, expr.parse_unary())
    end
    return left
  end

  expr.parse_unary = function()
    if state:peek_one_of(TK.PLUS, TK.MINUS, TK.TILDE) then
      return ast.UnaryOp(state:advance_token().value, expr.parse_unary())
    end
    return expr.parse_power()
  end

  expr.parse_power = function()
    local left = expr.parse_primary()
    if state:peek_is(TK.DOUBLESTAR) then
      state:advance_token()
      left = ast.BinOp(left, "**", expr.parse_unary())
    end
    return left
  end

  expr.parse_primary = function()
    local atom = expr.parse_atom()
    while true do
      if state:peek_is(TK.LPAREN) then
        state:advance_token()
        skip_continuation_tokens()
        local args = {}
        local keywords = {}
        if state:peek_not(TK.RPAREN) then
          parse_call_arg_star(args, keywords)
          while state:match_token(TK.COMMA) do
            parse_call_arg_star(args, keywords)
          end
        end
        skip_continuation_tokens()
        state:expect_token(TK.RPAREN)
        if #keywords > 0 then
          atom = ast.Call(atom, args, keywords)
        else
          atom = ast.Call(atom, args)
        end
      elseif state:peek_is(TK.LBRACKET) then
        state:advance_token()
        if state:peek_is(TK.COLON) then
          state:advance_token()
          local lower, upper, step = nil, nil, nil
          if state:peek_not(TK.RBRACKET) and state:peek_token().kind ~= TK.COLON then
            upper = expr.parse_expr()
          end
          if state:peek_is(TK.COLON) then
            state:advance_token()
            if state:peek_not(TK.RBRACKET) then
              step = expr.parse_expr()
            end
          end
          state:expect_token(TK.RBRACKET)
          atom = ast.Subscript(atom, ast.Slice(lower, upper, step))
        else
          local idx = expr.parse_expr()
          if state:peek_is(TK.COLON) then
            state:advance_token()
            local upper, step = nil, nil
            if state:peek_not(TK.RBRACKET) and state:peek_token().kind ~= TK.COLON then
              upper = expr.parse_expr()
            end
            if state:peek_is(TK.COLON) then
              state:advance_token()
              if state:peek_not(TK.RBRACKET) then
                step = expr.parse_expr()
              end
            end
            state:expect_token(TK.RBRACKET)
            atom = ast.Subscript(atom, ast.Slice(idx, upper, step))
          else
            state:expect_token(TK.RBRACKET)
            atom = ast.Subscript(atom, idx)
          end
        end
      elseif state:peek_is(TK.DOT) then
        state:advance_token()
        atom = ast.Attribute(atom, state:expect_token(TK.IDENTIFIER).value)
      else
        break
      end
    end
    return atom
  end

  local function parse_paren_expr()
    state:advance_token()
    skip_continuation_tokens()
    local first = expr.parse_expr()
    skip_continuation_tokens()
    if state:match_token(TK.COMMA) then
      local elements = { first }
      while state:peek_not(TK.RPAREN) do
        elements[#elements + 1] = expr.parse_expr()
        skip_continuation_tokens()
        state:match_token(TK.COMMA)
        skip_continuation_tokens()
      end
      state:expect_token(TK.RPAREN)
      return ast.Tuple(elements)
    end
    state:expect_token(TK.RPAREN)
    return first
  end

  local function parse_bracket_expr()
    state:advance_token()
    skip_continuation_tokens()
    if state:peek_is(TK.RBRACKET) then
      state:expect_token(TK.RBRACKET)
      return ast.List({})
    end
    local first = expr.parse_expr()
    if state:peek_is(TK.FOR) then
      state:advance_token()
      local generators = parse_comprehension_clauses()
      state:expect_token(TK.RBRACKET)
      return ast.ListComp(first, generators)
    end
    local elements = { first }
    while state:match_token(TK.COMMA) do
      elements[#elements + 1] = expr.parse_expr()
    end
    state:expect_token(TK.RBRACKET)
    return ast.List(elements)
  end

  local function parse_brace_expr()
    state:advance_token()
    skip_continuation_tokens()
    if state:peek_not(TK.RBRACE) then
      local first = expr.parse_expr()
      skip_continuation_tokens()
      if state:peek_is(TK.COLON) then
        state:advance_token()
        local key = first
        skip_continuation_tokens()
        local dict_value = expr.parse_expr()
        skip_continuation_tokens()
        if state:peek_is(TK.FOR) then
          state:advance_token()
          local generators = parse_comprehension_clauses()
          skip_continuation_tokens()
          state:expect_token(TK.RBRACE)
          return ast.DictComp(key, dict_value, generators)
        end
        local keys = { key }
        local dict_values = { dict_value }
        while state:match_token(TK.COMMA) do
          skip_continuation_tokens()
          if state:peek_is(TK.RBRACE) then break end
          keys[#keys + 1] = expr.parse_expr()
          state:expect_token(TK.COLON)
          skip_continuation_tokens()
          if state:peek_is(TK.RBRACE) then break end
          dict_values[#dict_values + 1] = expr.parse_expr()
          skip_continuation_tokens()
        end
        skip_continuation_tokens()
        state:expect_token(TK.RBRACE)
        return ast.Dict(keys, dict_values)
      else
        if state:peek_is(TK.FOR) then
          state:advance_token()
          local generators = parse_comprehension_clauses()
          skip_continuation_tokens()
          state:expect_token(TK.RBRACE)
          return ast.SetComp(first, generators)
        end
        local elements = { first }
        while state:match_token(TK.COMMA) do
          skip_continuation_tokens()
          elements[#elements + 1] = expr.parse_expr()
          skip_continuation_tokens()
        end
        skip_continuation_tokens()
        state:expect_token(TK.RBRACE)
        return ast.Set(elements)
      end
    else
      skip_continuation_tokens()
      state:expect_token(TK.RBRACE)
      return ast.Dict({}, {})
    end
  end

  ---@return ast_node
  expr.parse_atom = function()
    local current_token = state:peek_token()
    if not current_token then
      error("unexpected EOF")
    end
    local atom_handlers = {
      [TK.NONE]     = function() state:advance_token(); return ast.Constant(nil) end,
      [TK.TRUE]     = function() state:advance_token(); return ast.Constant(true) end,
      [TK.FALSE]    = function() state:advance_token(); return ast.Constant(false) end,
      [TK.ELLIPSIS] = function() state:advance_token(); return ast.Constant(nil) end,
      [TK.INTEGER]  = function() state:advance_token(); return ast.Constant(tonumber(current_token.value)) end,
      [TK.FLOAT]    = function() state:advance_token(); return ast.Constant(tonumber(current_token.value)) end,
      [TK.STRING]   = function()
        state:advance_token()
        local value = current_token.value
        if value:sub(1, 3) == '"""' or value:sub(1, 3) == "'''" then
          value = value:sub(4, #value - 3)
        else
          value = value:sub(2, #value - 1)
        end
        return ast.Constant(util.unescape(value))
      end,
      [TK.IDENTIFIER] = function()
        state:advance_token()
        if current_token.value == "super" then
          return ast.Super()
        end
        return ast.Name(current_token.value)
      end,
      [TK.FSTRING_START] = function()
        state:advance_token()
        local values = {}
        while state:peek_token() and state:peek_token().kind ~= TK.FSTRING_END do
          if state:peek_is(TK.FSTRING_MIDDLE) then
            local tok = state:advance_token()
            values[#values + 1] = ast.Constant(tok.value)
          elseif state:peek_is(TK.FSTRING_EXPR) then
            local tok = state:advance_token()
            local info = tok.value
            local sub_tokens = tokenizer.tokenize(info.expr)
            local sub_prog = top_parse(sub_tokens)
            local sub_expr = nil
            if sub_prog and sub_prog.body and #sub_prog.body > 0 then
              local first = sub_prog.body[1]
              if first.type == ast.EXPR_STMT then
                sub_expr = first.expr
              end
            end
            if not sub_expr then
              sub_expr = ast.Constant(nil)
            end
            values[#values + 1] = ast.FormattedValue(sub_expr, info.conversion, info.format_spec)
          else
            state:advance_token()
          end
        end
        state:advance_token()
        return ast.JoinedStr(values)
      end,
      [TK.LPAREN]   = parse_paren_expr,
      [TK.LBRACKET] = parse_bracket_expr,
      [TK.LBRACE]   = parse_brace_expr,
      [TK.AWAIT] = function()
        state:advance_token()
        return ast.Await(expr.parse_expr())
      end,
      [TK.YIELD] = function()
        state:advance_token()
        if state:peek_token() and state:peek_token().kind ~= TK.NEWLINE and state:peek_token().kind ~= TK.RPAREN then
          return ast.Yield(expr.parse_expr())
        end
        return ast.Yield(nil)
      end,
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

  return expr
end