-- Python-to-Lua transpiler for Astra

local TK = {
  NEWLINE = 1,
  INDENT = 2,
  DEDENT = 3,
  IDENTIFIER = 5,
  INTEGER = 6,
  FLOAT = 7,
  STRING = 8,
  PLUS = 9,
  MINUS = 10,
  STAR = 11,
  SLASH = 12,
  DOUBLESLASH = 13,
  PERCENT = 14,
  DOUBLESTAR = 15,
  EQEQ = 16,
  NOTEQ = 17,
  LESS = 18,
  GREATER = 19,
  LESSEQ = 20,
  GREATEREQ = 21,
  EQ = 22,
  PLUSEQ = 23,
  MINUSEQ = 24,
  STAREQ = 25,
  SLASHEQ = 26,
  PERCENTEQ = 27,
  LPAREN = 28,
  RPAREN = 29,
  LBRACKET = 30,
  RBRACKET = 31,
  LBRACE = 32,
  RBRACE = 33,
  COLON = 34,
  COMMA = 35,
  DOT = 36,
  SEMI = 37,
  DEF = 38,
  IF = 39,
  ELIF = 40,
  ELSE = 41,
  WHILE = 42,
  FOR = 43,
  IN = 44,
  RETURN = 45,
  AND = 46,
  OR = 47,
  NOT = 48,
  IS = 49,
  PASS = 50,
  BREAK = 51,
  CONTINUE = 52,
  NONE = 53,
  TRUE = 54,
  FALSE = 55,
  EOF = 56,
  WALRUS = 57,
  ELLIPSIS = 58,
  LAMBDA = 59,
  TRY = 60,
  EXCEPT = 61,
  FINALLY = 62,
  GLOBAL = 63,
  AS = 64,
}

local token_names = {}
for name, id in pairs(TK) do
  token_names[id] = name
end

local keyword_token_map = {
  def = TK.DEF,
  ["if"] = TK.IF,
  elif = TK.ELIF,
  ["else"] = TK.ELSE,
  ["while"] = TK.WHILE,
  ["for"] = TK.FOR,
  ["in"] = TK.IN,
  ["return"] = TK.RETURN,
  ["and"] = TK.AND,
  ["or"] = TK.OR,
  ["not"] = TK.NOT,
  is = TK.IS,
  pass = TK.PASS,
  ["break"] = TK.BREAK,
  continue = TK.CONTINUE,
  None = TK.NONE,
  True = TK.TRUE,
  False = TK.FALSE,
  lambda = TK.LAMBDA,
  ["try"] = TK.TRY,
  ["except"] = TK.EXCEPT,
  ["finally"] = TK.FINALLY,
  ["global"] = TK.GLOBAL,
  ["as"] = TK.AS,
}

local two_character_tokens = {
  ["=="] = TK.EQEQ,
  ["!="] = TK.NOTEQ,
  ["<="] = TK.LESSEQ,
  [">="] = TK.GREATEREQ,
  ["//"] = TK.DOUBLESLASH,
  ["**"] = TK.DOUBLESTAR,
  ["+="] = TK.PLUSEQ,
  ["-="] = TK.MINUSEQ,
  ["*="] = TK.STAREQ,
  ["/="] = TK.SLASHEQ,
  ["%="] = TK.PERCENTEQ,
  [":="] = TK.WALRUS,
  ["..."] = TK.ELLIPSIS,
}

local single_character_tokens = {
  ["+"] = TK.PLUS,
  ["-"] = TK.MINUS,
  ["*"] = TK.STAR,
  ["/"] = TK.SLASH,
  ["%"] = TK.PERCENT,
  ["="] = TK.EQ,
  ["<"] = TK.LESS,
  [">"] = TK.GREATER,
  ["("] = TK.LPAREN,
  [")"] = TK.RPAREN,
  ["["] = TK.LBRACKET,
  ["]"] = TK.RBRACKET,
  ["{"] = TK.LBRACE,
  ["}"] = TK.RBRACE,
  [":"] = TK.COLON,
  [","] = TK.COMMA,
  ["."] = TK.DOT,
  [";"] = TK.SEMI,
}

local multiplicative_operators = {
  [TK.STAR] = true,
  [TK.SLASH] = true,
  [TK.DOUBLESLASH] = true,
  [TK.PERCENT] = true,
}

local function tokenize(source)
  local tokens = {}
  local line = 1
  local col = 1
  local i = 1
  local n = #source
  local indent_stack = { 0 }
  local at_line_start = true
  local bracket_depth = 0
  local continuation = false

  local close_brackets = {
    [TK.RPAREN] = true,
    [TK.RBRACKET] = true,
    [TK.RBRACE] = true,
  }
  local open_brackets = {
    [TK.LPAREN] = true,
    [TK.LBRACKET] = true,
    [TK.LBRACE] = true,
  }

  local function advance_char()
    i = i + 1
    col = col + 1
  end

  local function emit_token(kind, value)
    tokens[#tokens + 1] = { kind = kind, value = value or kind, line = line, col = col }
    if open_brackets[kind] then
      bracket_depth = bracket_depth + 1
    elseif close_brackets[kind] then
      bracket_depth = bracket_depth - 1
    end
  end

  while i <= n do
    local ch = source:sub(i, i)

    if ch == "\n" then
      if bracket_depth > 0 then
        i = i + 1
        line = line + 1
        col = 1
      else
        emit_token(TK.NEWLINE, "\n")
        line = line + 1
        col = 1
        i = i + 1
        at_line_start = true
      end
    elseif at_line_start then
      if ch == " " or ch == "\t" then
        local indent_count = 0
        local indent_char = ch
        while i <= n do
          local c = source:sub(i, i)
          if c == " " or c == "\t" then
            indent_count = indent_count + (c ~= indent_char and (c == "\t" and 4 or 1) or 1)
            advance_char()
          else
            break
          end
        end
        local cur = indent_stack[#indent_stack]
        local nx = i <= n and source:sub(i, i) or ""
        if nx ~= "\n" and nx ~= "" then
          if indent_count > cur then
            emit_token(TK.INDENT)
            indent_stack[#indent_stack + 1] = indent_count
          elseif indent_count < cur then
            while #indent_stack > 1 and indent_stack[#indent_stack] > indent_count do
              emit_token(TK.DEDENT)
              indent_stack[#indent_stack] = nil
            end
          end
        end
        at_line_start = false
      else
        while #indent_stack > 1 do
          emit_token(TK.DEDENT)
          indent_stack[#indent_stack] = nil
        end
        at_line_start = false
      end
    elseif ch == "#" then
      while i <= n and source:sub(i, i) ~= "\n" do
        advance_char()
      end
    elseif ch == '"' or ch == "'" then
      local quote_char = ch
      local start_index = i
      advance_char()
      if source:sub(i, i + 1) == quote_char .. quote_char then
        i = i + 2
        col = col + 2
        while i <= n do
          if source:sub(i, i + 2) == quote_char .. quote_char .. quote_char then
            i = i + 3
            col = col + 3
            break
          end
          if source:sub(i, i) == "\n" then
            line = line + 1
            col = 1
          else
            col = col + 1
          end
          i = i + 1
        end
        emit_token(TK.STRING, source:sub(start_index, i - 1))
      else
        while i <= n do
          local c = source:sub(i, i)
          if c == "\\" then
            i = i + 2
            col = col + 2
          elseif c == quote_char then
            advance_char()
            break
          else
            advance_char()
          end
        end
        emit_token(TK.STRING, source:sub(start_index, i - 1))
      end
    elseif ch >= "0" and ch <= "9" then
      local start_index = i
      local is_float = false
      advance_char()
      while i <= n do
        local c = source:sub(i, i)
        if c >= "0" and c <= "9" then
          advance_char()
        elseif c == "." then
          is_float = true
          advance_char()
        elseif c == "e" or c == "E" then
          is_float = true
          advance_char()
          if source:sub(i, i) == "+" or source:sub(i, i) == "-" then
            advance_char()
          end
        else
          break
        end
      end
      emit_token(is_float and TK.FLOAT or TK.INTEGER, source:sub(start_index, i - 1))
    elseif (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_" then
      local start_index = i
      advance_char()
      while i <= n do
        local c = source:sub(i, i)
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" then
          advance_char()
        else
          break
        end
      end
      local word = source:sub(start_index, i - 1)
      emit_token(keyword_token_map[word] or TK.IDENTIFIER, word)
    else
      local next_two = i + 1 <= n and source:sub(i, i + 1) or ""
      local next_three = i + 2 <= n and source:sub(i, i + 2) or ""

      if two_character_tokens[next_three] then
        emit_token(two_character_tokens[next_three], next_three)
        i = i + 3
        col = col + 3
      elseif two_character_tokens[next_two] then
        emit_token(two_character_tokens[next_two], next_two)
        i = i + 2
        col = col + 2
      elseif single_character_tokens[ch] then
        emit_token(single_character_tokens[ch], ch)
        advance_char()
      elseif ch == " " or ch == "\t" or ch == "\r" then
        advance_char()
      elseif ch == "\\" then
        local next_char = i + 1 <= n and source:sub(i + 1, i + 1) or ""
        if next_char == "\n" then
          i = i + 2
          line = line + 1
          col = 1
          continuation = true
        elseif next_char == "\r" and i + 2 <= n and source:sub(i + 2, i + 2) == "\n" then
          i = i + 3
          line = line + 1
          col = 1
          continuation = true
        else
          error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. ch)
        end
      else
        error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. ch)
      end
    end
  end

  while #indent_stack > 1 do
    emit_token(TK.DEDENT)
    indent_stack[#indent_stack] = nil
  end
  emit_token(TK.EOF)
  return tokens
end

-- ============================================================
-- Parser
-- ============================================================

local function parse(tokens)
  local pos = 1

  local function peek_token()
    return tokens[pos]
  end
  local function advance_token()
    local token = tokens[pos]
    pos = pos + 1
    return token
  end

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
    if peek_token() and peek_token().kind == TK.NEWLINE then
      advance_token()
    end
  end

  -- declare parser functions for Lua 5.1
  local parse_program, parse_stmt, parse_simple_stmt
  local parse_func_def, parse_if, parse_while, parse_for, parse_return, parse_try, parse_block_body
  local parse_expr, parse_lambda, parse_walrus, parse_if_expr, parse_or
  local parse_and, parse_not, parse_comparison
  local parse_term, parse_factor, parse_unary, parse_power, parse_primary, parse_atom
  local unescape_string, parse_comma_list, parse_comprehension_clauses

  parse_comma_list = function(end_kind)
    local items = {}
    if peek_token() and peek_token().kind ~= end_kind then
      items[#items + 1] = parse_expr()
      while match_token(TK.COMMA) do
        items[#items + 1] = parse_expr()
      end
    end
    return items
  end

  parse_comprehension_clauses = function()
    local gens = {}
    while true do
      local target = expect_token(TK.IDENTIFIER).value
      expect_token(TK.IN)
      local iter = parse_or()
      local ifs = {}
      while peek_token() and peek_token().kind == TK.IF do
        advance_token()
        ifs[#ifs + 1] = parse_or()
      end
      gens[#gens + 1] = { target = target, iter = iter, ifs = ifs }
      if peek_token() and peek_token().kind == TK.FOR then
        advance_token()
      else
        break
      end
    end
    return gens
  end

  parse_program = function()
    local body = {}
    while peek_token() and peek_token().kind == TK.NEWLINE do
      advance_token()
    end
    while peek_token() and peek_token().kind ~= TK.EOF and peek_token().kind ~= TK.DEDENT do
      while peek_token() and peek_token().kind == TK.NEWLINE do
        advance_token()
      end
      if peek_token() and (peek_token().kind == TK.DEDENT or peek_token().kind == TK.EOF) then
        break
      end
      local stmts = parse_stmt()
      if stmts then
        for _, s in ipairs(stmts) do
          body[#body + 1] = s
        end
      end
      while peek_token() and peek_token().kind == TK.NEWLINE do
        advance_token()
      end
      if peek_token() and peek_token().kind == TK.DEDENT then
        break
      end
    end
    return { type = "Program", body = body }
  end

  parse_stmt = function()
    local token = peek_token()
    if not token then
      return nil
    end
    if token.kind == TK.DEF then
      return { parse_func_def() }
    elseif token.kind == TK.IF then
      return { parse_if() }
    elseif token.kind == TK.WHILE then
      return { parse_while() }
    elseif token.kind == TK.FOR then
      return { parse_for() }
    elseif token.kind == TK.RETURN then
      return { parse_return() }
    elseif token.kind == TK.PASS then
      advance_token()
      return { { type = "Pass" } }
    elseif token.kind == TK.BREAK then
      advance_token()
      return { { type = "Break" } }
    elseif token.kind == TK.CONTINUE then
      advance_token()
      return { { type = "Continue" } }
    elseif token.kind == TK.TRY then
      return { parse_try() }
    else
      return { parse_simple_stmt() }
    end
  end

  parse_simple_stmt = function()
    if peek_token() and peek_token().kind == TK.GLOBAL then
      advance_token()
      local names = { expect_token(TK.IDENTIFIER).value }
      while match_token(TK.COMMA) do
        names[#names + 1] = expect_token(TK.IDENTIFIER).value
      end
      return { type = "Global", names = names }
    end
    local first = parse_expr()
    local targets = { first }
    while peek_token() and peek_token().kind == TK.COMMA do
      advance_token()
      targets[#targets + 1] = parse_expr()
    end
    if match_token(TK.EQ) then
      local values = { parse_expr() }
      while match_token(TK.COMMA) do
        values[#values + 1] = parse_expr()
      end
      if #values == 1 then
        return { type = "Assign", targets = targets, value = values[1] }
      else
        return { type = "Assign", targets = targets, value = { type = "Tuple", elts = values } }
      end
    elseif match_token(TK.PLUSEQ) then
      return { type = "AugAssign", target = targets[1], op = "+", value = parse_expr() }
    elseif match_token(TK.MINUSEQ) then
      return { type = "AugAssign", target = targets[1], op = "-", value = parse_expr() }
    elseif match_token(TK.STAREQ) then
      return { type = "AugAssign", target = targets[1], op = "*", value = parse_expr() }
    elseif match_token(TK.SLASHEQ) then
      return { type = "AugAssign", target = targets[1], op = "/", value = parse_expr() }
    elseif match_token(TK.PERCENTEQ) then
      return { type = "AugAssign", target = targets[1], op = "%", value = parse_expr() }
    else
      return { type = "ExprStmt", expr = targets[1] }
    end
  end

  parse_func_def = function()
    advance_token()
    local name = expect_token(TK.IDENTIFIER)
    expect_token(TK.LPAREN)
    local args = {}
    if peek_token() and peek_token().kind ~= TK.RPAREN then
      args[#args + 1] = expect_token(TK.IDENTIFIER).value
      if peek_token() and peek_token().kind == TK.EQ then
        advance_token()
        parse_expr()
      end
      while match_token(TK.COMMA) do
        args[#args + 1] = expect_token(TK.IDENTIFIER).value
        if peek_token() and peek_token().kind == TK.EQ then
          advance_token()
          parse_expr()
        end
      end
    end
    expect_token(TK.RPAREN)
    expect_colon_newline()
    return { type = "FunctionDef", name = name.value, args = args, body = parse_block_body() }
  end

  parse_if = function()
    advance_token()
    local test = parse_expr()
    expect_colon_newline()
    local body = parse_block_body()
    local elifs = {}
    local orelse = nil
    while peek_token() and peek_token().kind == TK.ELIF do
      advance_token()
      local et = parse_expr()
      expect_colon_newline()
      elifs[#elifs + 1] = { test = et, body = parse_block_body() }
    end
    if peek_token() and peek_token().kind == TK.ELSE then
      advance_token()
      expect_colon_newline()
      orelse = parse_block_body()
    end
    return { type = "If", test = test, body = body, elifs = elifs, orelse = orelse }
  end

  parse_while = function()
    advance_token()
    local test = parse_expr()
    expect_colon_newline()
    local body = parse_block_body()
    local orelse = nil
    if peek_token() and peek_token().kind == TK.ELSE then
      advance_token()
      expect_colon_newline()
      orelse = parse_block_body()
    end
    return { type = "While", test = test, body = body, orelse = orelse }
  end

  parse_for = function()
    advance_token()
    local target = expect_token(TK.IDENTIFIER).value
    expect_token(TK.IN)
    local iter = nil
    local is_range = false
    local range_args = {}
    if peek_token() and peek_token().kind == TK.IDENTIFIER and peek_token().value == "range" then
      advance_token()
      if peek_token() and peek_token().kind == TK.LPAREN then
        advance_token()
        is_range = true
        range_args[1] = parse_expr()
        while match_token(TK.COMMA) do
          range_args[#range_args + 1] = parse_expr()
        end
        expect_token(TK.RPAREN)
      end
    else
      iter = parse_primary()
    end
    expect_colon_newline()
    local body = parse_block_body()
    local orelse = nil
    if peek_token() and peek_token().kind == TK.ELSE then
      advance_token()
      expect_colon_newline()
      orelse = parse_block_body()
    end
    return {
      type = "For",
      target = target,
      iter = iter,
      body = body,
      orelse = orelse,
      is_range = is_range,
      range_args = range_args,
    }
  end

  parse_try = function()
    advance_token()
    expect_colon_newline()
    local body = parse_block_body()
    local handlers = {}
    local finalbody = nil
    while peek_token() and peek_token().kind == TK.EXCEPT do
      advance_token()
      local exc_type = nil
      local exc_var = nil
      if peek_token() and peek_token().kind ~= TK.COLON then
        exc_type = parse_expr()
        if peek_token() and peek_token().kind == TK.AS then
          advance_token()
          exc_var = expect_token(TK.IDENTIFIER).value
        end
      end
      expect_colon_newline()
      handlers[#handlers + 1] = { type = exc_type, name = exc_var, body = parse_block_body() }
    end
    if peek_token() and peek_token().kind == TK.FINALLY then
      advance_token()
      expect_colon_newline()
      finalbody = parse_block_body()
    end
    return { type = "Try", body = body, handlers = handlers, finalbody = finalbody }
  end

  parse_return = function()
    advance_token()
    if
      peek_token()
      and peek_token().kind ~= TK.NEWLINE
      and peek_token().kind ~= TK.DEDENT
      and peek_token().kind ~= TK.EOF
    then
      return { type = "Return", value = parse_expr() }
    else
      return { type = "Return", value = nil }
    end
  end

  parse_block_body = function()
    while peek_token() and peek_token().kind == TK.NEWLINE do
      advance_token()
    end
    expect_token(TK.INDENT)
    local body = {}
    while peek_token() and peek_token().kind ~= TK.DEDENT and peek_token().kind ~= TK.EOF do
      while peek_token() and peek_token().kind == TK.NEWLINE do
        advance_token()
      end
      if peek_token() and (peek_token().kind == TK.DEDENT or peek_token().kind == TK.EOF) then
        break
      end
      local stmts = parse_stmt()
      if stmts then
        for _, s in ipairs(stmts) do
          body[#body + 1] = s
        end
      end
      while peek_token() and peek_token().kind == TK.NEWLINE do
        advance_token()
      end
    end
    expect_token(TK.DEDENT)
    return body
  end

  -- expression parsing
  parse_expr = function()
    return parse_lambda()
  end
  parse_lambda = function()
    if peek_token() and peek_token().kind == TK.LAMBDA then
      advance_token()
      local args = {}
      if peek_token() and peek_token().kind ~= TK.COLON then
        args[#args + 1] = expect_token(TK.IDENTIFIER).value
        while match_token(TK.COMMA) do
          args[#args + 1] = expect_token(TK.IDENTIFIER).value
        end
      end
      expect_token(TK.COLON)
      return { type = "Lambda", args = args, body = parse_lambda() }
    end
    return parse_walrus()
  end
  parse_walrus = function()
    local result = parse_if_expr()
    if peek_token() and peek_token().kind == TK.WALRUS then
      advance_token()
      result = { type = "Walrus", target = result, value = parse_walrus() }
    end
    return result
  end
  parse_if_expr = function()
    local body = parse_or()
    if peek_token() and peek_token().kind == TK.IF then
      advance_token()
      local test = parse_or()
      expect_token(TK.ELSE)
      body = { type = "IfExpr", test = test, body = body, orelse = parse_if_expr() }
    end
    return body
  end
  parse_or = function()
    local left = parse_and()
    while peek_token() and peek_token().kind == TK.OR do
      advance_token()
      local r = parse_and()
      left = { type = "BoolOp", op = "or", values = { left, r } }
    end
    return left
  end
  parse_and = function()
    local left = parse_not()
    while peek_token() and peek_token().kind == TK.AND do
      advance_token()
      local r = parse_not()
      left = { type = "BoolOp", op = "and", values = { left, r } }
    end
    return left
  end
  parse_not = function()
    if peek_token() and peek_token().kind == TK.NOT then
      advance_token()
      return { type = "UnaryOp", op = "not", operand = parse_not() }
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
        if peek_token() and peek_token().kind == TK.NOT then
          advance_token()
          op = "is not"
        else
          op = "is"
        end
      elseif not op and current_token.kind == TK.IN then
        advance_token()
        op = "in"
      elseif not op and current_token.kind == TK.NOT then
        local saved = pos
        advance_token()
        if peek_token() and peek_token().kind == TK.IN then
          advance_token()
          op = "not in"
        else
          pos = saved
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
    return { type = "Compare", left = left, ops = cmp_ops, comparators = cmp_rights }
  end

  parse_term = function()
    local left = parse_factor()
    while peek_token() and (peek_token().kind == TK.PLUS or peek_token().kind == TK.MINUS) do
      local op = advance_token()
      left = { type = "BinOp", left = left, op = op.value, right = parse_factor() }
    end
    return left
  end

  parse_factor = function()
    local left = parse_unary()
    while peek_token() and multiplicative_operators[peek_token().kind] do
      local op = advance_token()
      left = { type = "BinOp", left = left, op = op.value, right = parse_unary() }
    end
    return left
  end

  parse_unary = function()
    if peek_token() and (peek_token().kind == TK.PLUS or peek_token().kind == TK.MINUS) then
      return { type = "UnaryOp", op = advance_token().value, operand = parse_unary() }
    end
    return parse_power()
  end

  parse_power = function()
    local left = parse_primary()
    if peek_token() and peek_token().kind == TK.DOUBLESTAR then
      advance_token()
      left = { type = "BinOp", left = left, op = "**", right = parse_unary() }
    end
    return left
  end

  parse_primary = function()
    local expr = parse_atom()
    while true do
      local function skip_continue_tokens()
        while
          peek_token()
          and (peek_token().kind == TK.NEWLINE or peek_token().kind == TK.INDENT or peek_token().kind == TK.DEDENT)
        do
          advance_token()
        end
      end
      if peek_token() and peek_token().kind == TK.LPAREN then
        advance_token()
        skip_continue_tokens()
        local args = {}
        local keywords = {}
        local function parse_call_arg()
          local saved = pos
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
        if peek_token() and peek_token().kind ~= TK.RPAREN then
          parse_call_arg()
          while match_token(TK.COMMA) do
            parse_call_arg()
          end
        end
        skip_continue_tokens()
        expect_token(TK.RPAREN)
        if #keywords > 0 then
          expr = { type = "Call", func = expr, args = args, keywords = keywords }
        else
          expr = { type = "Call", func = expr, args = args }
        end
      elseif peek_token() and peek_token().kind == TK.LBRACKET then
        advance_token()
        if peek_token() and peek_token().kind == TK.COLON then
          advance_token()
          local lower, upper, step = nil, nil, nil
          if peek_token() and peek_token().kind ~= TK.RBRACKET and peek_token().kind ~= TK.COLON then
            upper = parse_expr()
          end
          if peek_token() and peek_token().kind == TK.COLON then
            advance_token()
            if peek_token() and peek_token().kind ~= TK.RBRACKET then
              step = parse_expr()
            end
          end
          expect_token(TK.RBRACKET)
          expr =
            { type = "Subscript", value = expr, index = { type = "Slice", lower = lower, upper = upper, step = step } }
        else
          local idx = parse_expr()
          if peek_token() and peek_token().kind == TK.COLON then
            advance_token()
            local upper, step = nil, nil
            if peek_token() and peek_token().kind ~= TK.RBRACKET and peek_token().kind ~= TK.COLON then
              upper = parse_expr()
            end
            if peek_token() and peek_token().kind == TK.COLON then
              advance_token()
              if peek_token() and peek_token().kind ~= TK.RBRACKET then
                step = parse_expr()
              end
            end
            expect_token(TK.RBRACKET)
            expr =
              { type = "Subscript", value = expr, index = { type = "Slice", lower = idx, upper = upper, step = step } }
          else
            expect_token(TK.RBRACKET)
            expr = { type = "Subscript", value = expr, index = idx }
          end
        end
      elseif peek_token() and peek_token().kind == TK.DOT then
        advance_token()
        expr = { type = "Attribute", value = expr, attr = expect_token(TK.IDENTIFIER).value }
      else
        break
      end
    end
    return expr
  end

  parse_atom = function()
    local current_token = peek_token()
    if not current_token then
      error("unexpected EOF")
    end
    if current_token.kind == TK.NONE then
      advance_token()
      return { type = "Constant", value = nil }
    elseif current_token.kind == TK.TRUE then
      advance_token()
      return { type = "Constant", value = true }
    elseif current_token.kind == TK.FALSE then
      advance_token()
      return { type = "Constant", value = false }
    elseif current_token.kind == TK.ELLIPSIS then
      advance_token()
      return { type = "Constant", value = nil }
    elseif current_token.kind == TK.INTEGER or current_token.kind == TK.FLOAT then
      advance_token()
      return { type = "Constant", value = tonumber(current_token.value) }
    elseif current_token.kind == TK.STRING then
      advance_token()
      local val = current_token.value:sub(2, #current_token.value - 1)
      return { type = "Constant", value = unescape_string(val) }
    elseif current_token.kind == TK.IDENTIFIER then
      advance_token()
      if current_token.value == "None" then
        return { type = "Constant", value = nil }
      elseif current_token.value == "True" then
        return { type = "Constant", value = true }
      elseif current_token.value == "False" then
        return { type = "Constant", value = false }
      end
      return { type = "Name", id = current_token.value }
    elseif current_token.kind == TK.LPAREN then
      advance_token()
      while
        peek_token()
        and (peek_token().kind == TK.NEWLINE or peek_token().kind == TK.INDENT or peek_token().kind == TK.DEDENT)
      do
        advance_token()
      end
      local e = parse_expr()
      while
        peek_token()
        and (peek_token().kind == TK.NEWLINE or peek_token().kind == TK.INDENT or peek_token().kind == TK.DEDENT)
      do
        advance_token()
      end
      expect_token(TK.RPAREN)
      return e
    elseif current_token.kind == TK.LBRACKET then
      advance_token()
      local first = parse_expr()
      if peek_token() and peek_token().kind == TK.FOR then
        advance_token()
        local gens = parse_comprehension_clauses()
        expect_token(TK.RBRACKET)
        return { type = "ListComp", elt = first, generators = gens }
      end
      local elts = { first }
      while match_token(TK.COMMA) do
        elts[#elts + 1] = parse_expr()
      end
      expect_token(TK.RBRACKET)
      return { type = "List", elts = elts }
    elseif current_token.kind == TK.LBRACE then
      advance_token()
      local function skip_newlines()
        while
          peek_token()
          and (peek_token().kind == TK.NEWLINE or peek_token().kind == TK.INDENT or peek_token().kind == TK.DEDENT)
        do
          advance_token()
        end
      end
      skip_newlines()
      if peek_token() and peek_token().kind ~= TK.RBRACE then
        local first = parse_expr()
        skip_newlines()
        if peek_token() and peek_token().kind == TK.COLON then
          advance_token()
          local key = first
          skip_newlines()
          local val = parse_expr()
          skip_newlines()
          if peek_token() and peek_token().kind == TK.FOR then
            advance_token()
            local gens = parse_comprehension_clauses()
            skip_newlines()
            expect_token(TK.RBRACE)
            return { type = "DictComp", key = key, value = val, generators = gens }
          end
          local keys = { key }
          local vals = { val }
          while match_token(TK.COMMA) do
            skip_newlines()
            if peek_token() and peek_token().kind == TK.RBRACE then
              break
            end
            keys[#keys + 1] = parse_expr()
            expect_token(TK.COLON)
            skip_newlines()
            if peek_token() and peek_token().kind == TK.RBRACE then
              break
            end
            vals[#vals + 1] = parse_expr()
            skip_newlines()
          end
          skip_newlines()
          expect_token(TK.RBRACE)
          return { type = "Dict", keys = keys, values = vals }
        else
          if peek_token() and peek_token().kind == TK.FOR then
            advance_token()
            local gens = parse_comprehension_clauses()
            skip_newlines()
            expect_token(TK.RBRACE)
            return { type = "SetComp", elt = first, generators = gens }
          end
          local elts = { first }
          while match_token(TK.COMMA) do
            skip_newlines()
            elts[#elts + 1] = parse_expr()
            skip_newlines()
          end
          skip_newlines()
          expect_token(TK.RBRACE)
          return { type = "Set", elts = elts }
        end
      else
        skip_newlines()
        expect_token(TK.RBRACE)
        return { type = "Set", elts = {} }
      end
    end
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

  unescape_string = function(s)
    s = s:gsub("\\\\", "\\")
    s = s:gsub("\\n", "\n")
    s = s:gsub("\\t", "\t")
    s = s:gsub('\\"', '"')
    s = s:gsub("\\'", "'")
    return s
  end

  return parse_program()
end
-- ============================================================
-- Code Generator
-- ============================================================

local function generate(ast)
  local indent_level = 0
  local parts = {}

  local function indent()
    return string.rep("    ", indent_level)
  end
  local function push(s)
    parts[#parts + 1] = s
  end

  -- pre-declare recursive functions for Lua 5.1
  local gen_body, with_indent, gen_str, gen_expr, gen_stmt
  local gen_comprehension_loops, gen_dictcomp_loops

  gen_body = function(body)
    for _, s in ipairs(body) do
      gen_stmt(s)
    end
  end

  with_indent = function(fn)
    indent_level = indent_level + 1
    fn()
    indent_level = indent_level - 1
  end

  gen_str = function(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\t", "\\t")
    s = s:gsub('"', '\\"')
    s = s:gsub("'", "\\'")
    return '"' .. s .. '"'
  end

  gen_comprehension_loops = function(elt, gens, idx)
    if idx > #gens then
      return "__res[#__res + 1] = " .. gen_expr(elt) .. "; "
    end
    local g = gens[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iter) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_comprehension_loops(elt, gens, idx + 1)
    for _ in ipairs(g.ifs or {}) do
      code = code .. "end "
    end
    code = code .. "end "
    return code
  end
  gen_dictcomp_loops = function(key, val, gens, idx)
    if idx > #gens then
      return "__res[" .. key .. "] = " .. val .. "; "
    end
    local g = gens[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iter) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_dictcomp_loops(key, val, gens, idx + 1)
    for _ in ipairs(g.ifs or {}) do
      code = code .. "end "
    end
    code = code .. "end "
    return code
  end

  gen_expr = function(expr)
    if expr.type == "Constant" then
      local v = expr.value
      if v == nil then
        return "nil"
      end
      if v == true then
        return "true"
      end
      if v == false then
        return "false"
      end
      if type(v) == "string" then
        return gen_str(v)
      end
      return tostring(v)
    elseif expr.type == "Name" then
      return expr.id
    elseif expr.type == "BinOp" then
      local l = gen_expr(expr.left)
      local r = gen_expr(expr.right)
      if expr.op == "**" then
        return "(" .. l .. " ^ " .. r .. ")"
      elseif expr.op == "//" then
        return "math.floor(" .. l .. " / " .. r .. ")"
      elseif
        expr.op == "+"
        and (
          (expr.left.type == "Constant" and type(expr.left.value) == "string")
          or (expr.right.type == "Constant" and type(expr.right.value) == "string")
        )
      then
        return "(" .. l .. " .. " .. r .. ")"
      elseif expr.op == "*" then
        if expr.left.type == "Constant" and type(expr.left.value) == "string" then
          return "string.rep(" .. l .. ", " .. r .. ")"
        end
        if expr.right.type == "Constant" and type(expr.right.value) == "string" then
          return "string.rep(" .. r .. ", " .. l .. ")"
        end
        if
          expr.left.type == "List"
          or expr.left.type == "Set"
          or expr.right.type == "List"
          or expr.right.type == "Set"
        then
          return "__py_repeat(" .. l .. ", " .. r .. ")"
        end
        return "(" .. l .. " * " .. r .. ")"
      else
        return "(" .. l .. " " .. expr.op .. " " .. r .. ")"
      end
    elseif expr.type == "UnaryOp" then
      return "(" .. expr.op .. " " .. gen_expr(expr.operand) .. ")"
    elseif expr.type == "BoolOp" then
      local vals = {}
      for _, v in ipairs(expr.values) do
        vals[#vals + 1] = gen_expr(v)
      end
      return table.concat(vals, " " .. expr.op .. " ")
    elseif expr.type == "Compare" then
      local function compare_values(l, op, r)
        if op == "!=" then
          return "(" .. l .. " ~= " .. r .. ")"
        elseif op == "is" then
          return "(" .. l .. " == " .. r .. ")"
        elseif op == "is not" then
          return "(" .. l .. " ~= " .. r .. ")"
        elseif op == "in" then
          return "__py_in(" .. r .. ", " .. l .. ")"
        elseif op == "not in" then
          return "not __py_in(" .. r .. ", " .. l .. ")"
        else
          return "(" .. l .. " " .. op .. " " .. r .. ")"
        end
      end
      if #expr.ops == 1 then
        return compare_values(gen_expr(expr.left), expr.ops[1], gen_expr(expr.comparators[1]))
      else
        local parts = {}
        local prev = gen_expr(expr.left)
        for i = 1, #expr.ops do
          local r = gen_expr(expr.comparators[i])
          parts[#parts + 1] = compare_values(prev, expr.ops[i], r)
          prev = r
        end
        return table.concat(parts, " and ")
      end
    elseif expr.type == "Call" then
      local args = {}
      for _, a in ipairs(expr.args) do
        args[#args + 1] = gen_expr(a)
      end
      if expr.keywords and #expr.keywords > 0 then
        local keyword_parts = {}
        for _, kw in ipairs(expr.keywords) do
          keyword_parts[#keyword_parts + 1] = "[" .. gen_str(kw.arg) .. "] = " .. gen_expr(kw.value)
        end
        args[#args + 1] = "{" .. table.concat(keyword_parts, ", ") .. "}"
      end
      return gen_expr(expr.func) .. "(" .. table.concat(args, ", ") .. ")"
    elseif expr.type == "Subscript" then
      local v = gen_expr(expr.value)
      if expr.index.type == "Slice" then
        local lower = expr.index.lower and gen_expr(expr.index.lower) or "nil"
        local upper = expr.index.upper and gen_expr(expr.index.upper) or "nil"
        local step = expr.index.step and gen_expr(expr.index.step) or "nil"
        return "__py_slice(" .. v .. ", " .. lower .. ", " .. upper .. ", " .. step .. ")"
      end
      local idx = gen_expr(expr.index)
      if expr.index.type == "Constant" and type(expr.index.value) == "string" then
        return v .. "[" .. idx .. "]"
      end
      return v .. "[" .. idx .. " + 1]"
    elseif expr.type == "Attribute" then
      return gen_expr(expr.value) .. "." .. expr.attr
    elseif expr.type == "List" then
      local elts = {}
      for _, e in ipairs(expr.elts) do
        elts[#elts + 1] = gen_expr(e)
      end
      return "{" .. table.concat(elts, ", ") .. "}"
    elseif expr.type == "Dict" then
      local items = {}
      for i = 1, #expr.keys do
        items[#items + 1] = "[" .. gen_expr(expr.keys[i]) .. "] = " .. gen_expr(expr.values[i])
      end
      return "{" .. table.concat(items, ", ") .. "}"
    elseif expr.type == "Set" then
      local elts = {}
      for _, e in ipairs(expr.elts) do
        elts[#elts + 1] = gen_expr(e)
      end
      return "{" .. table.concat(elts, ", ") .. "}"
    elseif expr.type == "Tuple" then
      local elts = {}
      for _, e in ipairs(expr.elts) do
        elts[#elts + 1] = gen_expr(e)
      end
      return table.concat(elts, ", ")
    elseif expr.type == "Lambda" then
      return "function(" .. table.concat(expr.args, ", ") .. ") return " .. gen_expr(expr.body) .. " end"
    elseif expr.type == "Walrus" then
      local t = gen_expr(expr.target)
      local v = gen_expr(expr.value)
      return "(function() local __w = " .. v .. "; " .. t .. " = __w; return __w end)()"
    elseif expr.type == "IfExpr" then
      return "(function(...) if "
        .. gen_expr(expr.test)
        .. " then return "
        .. gen_expr(expr.body)
        .. " else return "
        .. gen_expr(expr.orelse)
        .. " end end)()"
    elseif expr.type == "ListComp" or expr.type == "SetComp" then
      return "(function() local __res = {} "
        .. gen_comprehension_loops(expr.elt, expr.generators, 1)
        .. " return __res end)()"
    elseif expr.type == "DictComp" then
      local key = gen_expr(expr.key)
      local val = gen_expr(expr.value)
      return "(function() local __res = {} "
        .. gen_dictcomp_loops(key, val, expr.generators, 1)
        .. " return __res end)()"
    end
    error("unknown expression type: " .. expr.type)
  end

  gen_stmt = function(stmt)
    if stmt.type == "FunctionDef" then
      push(indent() .. "function " .. stmt.name .. "(" .. table.concat(stmt.args, ", ") .. ")")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "end")
    elseif stmt.type == "If" then
      push(indent() .. "if " .. gen_expr(stmt.test) .. " then")
      with_indent(function()
        gen_body(stmt.body)
      end)
      for _, elif in ipairs(stmt.elifs) do
        push(indent() .. "elseif " .. gen_expr(elif.test) .. " then")
        with_indent(function()
          gen_body(elif.body)
        end)
      end
      if stmt.orelse then
        push(indent() .. "else")
        with_indent(function()
          gen_body(stmt.orelse)
        end)
      end
      push(indent() .. "end")
    elseif stmt.type == "While" then
      push(indent() .. "while " .. gen_expr(stmt.test) .. " do")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "::__continue::")
      push(indent() .. "end")
      if stmt.orelse then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.orelse)
        end)
        push(indent() .. "end")
      end
    elseif stmt.type == "For" then
      if stmt.is_range then
        local n = #stmt.range_args
        local s = gen_expr(stmt.range_args[1])
        local st = n == 1 and "0" or s
        local sp = gen_expr(stmt.range_args[n == 1 and 1 or 2])
        local step = n == 3 and gen_expr(stmt.range_args[3]) or "1"
        push(indent() .. "for " .. stmt.target .. " = " .. st .. ", " .. sp .. " - 1, " .. step .. " do")
      else
        push(indent() .. "for _, " .. stmt.target .. " in ipairs(" .. gen_expr(stmt.iter) .. ") do")
      end
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "::__continue::")
      push(indent() .. "end")
      if stmt.orelse then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.orelse)
        end)
        push(indent() .. "end")
      end
    elseif stmt.type == "Return" then
      if stmt.value then
        push(indent() .. "return " .. gen_expr(stmt.value))
      else
        push(indent() .. "return")
      end
    elseif stmt.type == "Assign" then
      local function flatten_targets(tt)
        local result = {}
        for _, t in ipairs(tt) do
          if t.type == "List" or t.type == "Tuple" then
            for _, e in ipairs(t.elts) do
              result[#result + 1] = gen_expr(e)
            end
          else
            result[#result + 1] = gen_expr(t)
          end
        end
        return result
      end
      local target_expressions = flatten_targets(stmt.targets)
      push(indent() .. table.concat(target_expressions, ", ") .. " = " .. gen_expr(stmt.value))
    elseif stmt.type == "AugAssign" then
      local t = gen_expr(stmt.target)
      push(indent() .. t .. " = " .. t .. " " .. stmt.op .. " " .. gen_expr(stmt.value))
    elseif stmt.type == "ExprStmt" then
      if stmt.expr.type == "Constant" and type(stmt.expr.value) == "string" then
        -- docstring: skip
      elseif stmt.expr.type == "Name" then
        -- bare Name (e.g. `sys` from failed `import sys`): skip
      elseif stmt.expr.type == "Module" then
        -- bare import: skip
      else
        push(indent() .. gen_expr(stmt.expr))
      end
    elseif stmt.type == "Global" then
    elseif stmt.type == "Pass" then
    elseif stmt.type == "Break" then
      push(indent() .. "break")
    elseif stmt.type == "Continue" then
      push(indent() .. "goto __continue")
    elseif stmt.type == "Try" then
      push(indent() .. "local __py_ok, __py_err = pcall(function()")
      with_indent(function()
        gen_body(stmt.body)
      end)
      push(indent() .. "end)")
      if #stmt.handlers > 0 then
        push(indent() .. "if not __py_ok then")
        with_indent(function()
          for _, h in ipairs(stmt.handlers) do
            if h.name then
              push(indent() .. "local " .. h.name .. " = __py_err")
            end
          end
          -- execute the first matching handler
          for _, h in ipairs(stmt.handlers) do
            if h.type then
              -- type-checked except: for now, just always execute
            end
            gen_body(h.body)
          end
        end)
        push(indent() .. "end")
      end
      if stmt.finalbody then
        push(indent() .. "do")
        with_indent(function()
          gen_body(stmt.finalbody)
        end)
        push(indent() .. "end")
      end
    else
      error("unknown statement type: " .. stmt.type)
    end
  end

  -- runtime helpers preamble
  push("do")
  push("chr = string.char")
  push("ord = string.byte")
  push("local function __py_len(x) return #x end")
  push("len = __py_len")
  push("local function __py_int(x) return type(x) == 'number' and math.floor(x) or tonumber(x) end")
  push("int = __py_int")
  push("function __py_slice(tbl, start, stop, step)")
  push("    local s, e, st = start, stop, step or 1")
  push("    local n = #tbl")
  push("    if st > 0 then")
  push("        if s == nil then s = 0 end")
  push("        if e == nil then e = n end")
  push("        s = s + 1")
  push("        local result = {}")
  push("        for i = s, e, st do result[#result + 1] = tbl[i] end")
  push("        return result")
  push("    elseif st < 0 then")
  push("        if s == nil then s = n - 1 end")
  push("        if e == nil then e = -1 end")
  push("        s = s + 1")
  push("        e = e + 1")
  push("        local result = {}")
  push("        for i = s, e, st do result[#result + 1] = tbl[i] end")
  push("        return result")
  push("    end")
  push("    return {}")
  push("end")
  push("function __py_in(container, item)")
  push('    if type(container) == "table" then')
  push("        for _, __v in ipairs(container) do if __v == item then return true end end")
  push("        return false")
  push('    elseif type(container) == "string" then')
  push("        return string.find(container, item, 1, true) ~= nil")
  push("    end")
  push("    return false")
  push("end")
  push("function __py_repeat(val, n)")
  push("    local res = {}")
  push("    for _ = 1, n do")
  push("        res[#res + 1] = val")
  push("    end")
  push("    return res")
  push("end")
  push("function __py_range(...)")
  push("    local start, stop, step")
  push('    if select("#", ...) == 1 then start, stop, step = 0, (...), 1')
  push('    elseif select("#", ...) == 2 then start, stop, step = (...), select(2, ...), 1')
  push("    else start, stop, step = (...), select(2, ...), select(3, ...) end")
  push("    local result = {}")
  push("    if step > 0 then for i = start, stop - 1, step do result[#result + 1] = i end")
  push("    end")
  push("    if step < 0 then for i = start, stop + 1, step do result[#result + 1] = i end")
  push("    end")
  push("    return result")
  push("end")
  push("range = __py_range")
  push("end")

  gen_body(ast.body)
  return table.concat(parts, "\n")
end

-- ============================================================
-- Public API
-- ============================================================

local python = {}

function python.transpile(source)
  -- Strip trailing whitespace and remove blank lines
  local lines = {}
  for line in source:gmatch("[^\n]+") do
    line = line:match("^(.-)%s*$")
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  source = table.concat(lines, "\n")
  local tokens = tokenize(source)
  local ast = parse(tokens)
  local lua_code = generate(ast)
  python.last_code = lua_code
  return lua_code
end

function python.run(source)
  local lua_code = python.transpile(source)
  local fn, err = load(lua_code, "=python")
  if not fn then
    error("Python runtime error: " .. tostring(err))
  end
  return fn()
end

return python
