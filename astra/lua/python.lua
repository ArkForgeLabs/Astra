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

local tk_name = {}
for name, id in pairs(TK) do
  tk_name[id] = name
end

local keyword_tokens = {
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

local token_om = {
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

local token_sm = {
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

local token_mm = {
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

  local function ac()
    i = i + 1
    col = col + 1
  end

  local function emit_tk(kind, value)
    tokens[#tokens + 1] = { kind = kind, value = value or kind, line = line, col = col }
  end

  while i <= n do
    local ch = source:sub(i, i)

    if ch == "\n" then
      emit_tk(TK.NEWLINE, "\n")
      line = line + 1
      col = 1
      i = i + 1
      at_line_start = true
    elseif at_line_start then
      if ch == " " or ch == "\t" then
        local indent_count = 0
        local indent_char = ch
        while i <= n do
          local c = source:sub(i, i)
          if c == " " or c == "\t" then
            indent_count = indent_count + (c ~= indent_char and (c == "\t" and 4 or 1) or 1)
            ac()
          else
            break
          end
        end
        local cur = indent_stack[#indent_stack]
        local nx = i <= n and source:sub(i, i) or ""
        if nx ~= "\n" and nx ~= "" then
          if indent_count > cur then
            emit_tk(TK.INDENT)
            indent_stack[#indent_stack + 1] = indent_count
          elseif indent_count < cur then
            while #indent_stack > 1 and indent_stack[#indent_stack] > indent_count do
              emit_tk(TK.DEDENT)
              indent_stack[#indent_stack] = nil
            end
          end
        end
        at_line_start = false
      else
        while #indent_stack > 1 do
          emit_tk(TK.DEDENT)
          indent_stack[#indent_stack] = nil
        end
        at_line_start = false
      end
    elseif ch == "#" then
      while i <= n and source:sub(i, i) ~= "\n" do
        ac()
      end
    elseif ch == '"' or ch == "'" then
      local q = ch
      local si = i
      ac()
      if source:sub(i, i + 1) == q .. q then
        i = i + 2
        col = col + 2
        while i <= n do
          if source:sub(i, i + 2) == q .. q .. q then
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
        emit_tk(TK.STRING, source:sub(si, i - 1))
      else
        while i <= n do
          local c = source:sub(i, i)
          if c == "\\" then
            i = i + 2
            col = col + 2
          elseif c == q then
            ac()
            break
          else
            ac()
          end
        end
        emit_tk(TK.STRING, source:sub(si, i - 1))
      end
    elseif ch >= "0" and ch <= "9" then
      local si = i
      local isf = false
      ac()
      while i <= n do
        local c = source:sub(i, i)
        if c >= "0" and c <= "9" then
          ac()
        elseif c == "." then
          isf = true
          ac()
        elseif c == "e" or c == "E" then
          isf = true
          ac()
          if source:sub(i, i) == "+" or source:sub(i, i) == "-" then
            ac()
          end
        else
          break
        end
      end
      emit_tk(isf and TK.FLOAT or TK.INTEGER, source:sub(si, i - 1))
    elseif (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_" then
      local si = i
      ac()
      while i <= n do
        local c = source:sub(i, i)
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" then
          ac()
        else
          break
        end
      end
      local w = source:sub(si, i - 1)
      emit_tk(keyword_tokens[w] or TK.IDENTIFIER, w)
    else
      local t2 = i + 1 <= n and source:sub(i, i + 1) or ""
      local t3 = i + 2 <= n and source:sub(i, i + 2) or ""

      if token_om[t3] then
        emit_tk(token_om[t3], t3)
        i = i + 3
        col = col + 3
      elseif token_om[t2] then
        emit_tk(token_om[t2], t2)
        i = i + 2
        col = col + 2
      elseif token_sm[ch] then
        emit_tk(token_sm[ch], ch)
        ac()
      elseif ch == " " or ch == "\t" or ch == "\r" then
        ac()
      elseif ch == "\\" then
        local nc = i + 1 <= n and source:sub(i + 1, i + 1) or ""
        if nc == "\n" then
          i = i + 2
          line = line + 1
          col = 1
        elseif nc == "\r" and i + 2 <= n and source:sub(i + 2, i + 2) == "\n" then
          i = i + 3
          line = line + 1
          col = 1
        elseif nc == "\r" and i + 2 <= n and source:sub(i + 2, i + 2) == "\n" then
          i = i + 3
          line = line + 1
          col = 1
          at_line_start = true
        else
          error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. ch)
        end
      else
        error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. ch)
      end
    end
  end

  while #indent_stack > 1 do
    emit_tk(TK.DEDENT)
    indent_stack[#indent_stack] = nil
  end
  emit_tk(TK.EOF)
  return tokens
end

-- ============================================================
-- Parser
-- ============================================================

local function parse(tokens)
  local pos = 1

  local function pk()
    return tokens[pos]
  end
  local function ad()
    local t = tokens[pos]
    pos = pos + 1
    return t
  end

  local function ex(kind)
    local t = pk()
    if not t or t.kind ~= kind then
      error(
        "expected "
          .. (tk_name[kind] or kind)
          .. " got "
          .. (t and (tk_name[t.kind] or t.kind) or "EOF")
          .. " at line "
          .. (t and t.line or "?")
          .. " col "
          .. (t and t.col or "?")
      )
    end
    return ad()
  end

  local function ma(kind)
    local t = pk()
    if t and t.kind == kind then
      ad()
      return true
    end
    return false
  end

  local function ecs()
    ex(TK.COLON)
    if pk() and pk().kind == TK.NEWLINE then
      ad()
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
    if pk() and pk().kind ~= end_kind then
      items[#items + 1] = parse_expr()
      while ma(TK.COMMA) do
        items[#items + 1] = parse_expr()
      end
    end
    return items
  end

  parse_comprehension_clauses = function()
    local gens = {}
    while true do
      local target = ex(TK.IDENTIFIER).value
      ex(TK.IN)
      local iter = parse_or()
      local ifs = {}
      while pk() and pk().kind == TK.IF do
        ad()
        ifs[#ifs + 1] = parse_or()
      end
      gens[#gens + 1] = { target = target, iter = iter, ifs = ifs }
      if pk() and pk().kind == TK.FOR then
        ad()
      else
        break
      end
    end
    return gens
  end

  parse_program = function()
    local body = {}
    while pk() and pk().kind == TK.NEWLINE do
      ad()
    end
    while pk() and pk().kind ~= TK.EOF and pk().kind ~= TK.DEDENT do
      local stmts = parse_stmt()
      if stmts then
        for _, s in ipairs(stmts) do
          body[#body + 1] = s
        end
      end
      while pk() and pk().kind == TK.NEWLINE do
        ad()
      end
      if pk() and pk().kind == TK.DEDENT then
        break
      end
    end
    return { type = "Program", body = body }
  end

  parse_stmt = function()
    local t = pk()
    if not t then
      return nil
    end
    if t.kind == TK.DEF then
      return { parse_func_def() }
    elseif t.kind == TK.IF then
      return { parse_if() }
    elseif t.kind == TK.WHILE then
      return { parse_while() }
    elseif t.kind == TK.FOR then
      return { parse_for() }
    elseif t.kind == TK.RETURN then
      return { parse_return() }
    elseif t.kind == TK.PASS then
      ad()
      return { { type = "Pass" } }
    elseif t.kind == TK.BREAK then
      ad()
      return { { type = "Break" } }
    elseif t.kind == TK.CONTINUE then
      ad()
      return { { type = "Continue" } }
    elseif t.kind == TK.TRY then
      return { parse_try() }
    else
      return { parse_simple_stmt() }
    end
  end

  parse_simple_stmt = function()
    if pk() and pk().kind == TK.GLOBAL then
      ad()
      local names = { ex(TK.IDENTIFIER).value }
      while ma(TK.COMMA) do
        names[#names + 1] = ex(TK.IDENTIFIER).value
      end
      return { type = "Global", names = names }
    end
    local first = parse_expr()
    local targets = { first }
    while pk() and pk().kind == TK.COMMA do
      ad()
      targets[#targets + 1] = parse_expr()
    end
    if ma(TK.EQ) then
      local values = { parse_expr() }
      while ma(TK.COMMA) do
        values[#values + 1] = parse_expr()
      end
      if #values == 1 then
        return { type = "Assign", targets = targets, value = values[1] }
      else
        return { type = "Assign", targets = targets, value = { type = "Tuple", elts = values } }
      end
    elseif ma(TK.PLUSEQ) then
      return { type = "AugAssign", target = targets[1], op = "+", value = parse_expr() }
    elseif ma(TK.MINUSEQ) then
      return { type = "AugAssign", target = targets[1], op = "-", value = parse_expr() }
    elseif ma(TK.STAREQ) then
      return { type = "AugAssign", target = targets[1], op = "*", value = parse_expr() }
    elseif ma(TK.SLASHEQ) then
      return { type = "AugAssign", target = targets[1], op = "/", value = parse_expr() }
    elseif ma(TK.PERCENTEQ) then
      return { type = "AugAssign", target = targets[1], op = "%", value = parse_expr() }
    else
      return { type = "ExprStmt", expr = targets[1] }
    end
  end

  parse_func_def = function()
    ad()
    local name = ex(TK.IDENTIFIER)
    ex(TK.LPAREN)
    local args = {}
    if pk() and pk().kind ~= TK.RPAREN then
      args[#args + 1] = ex(TK.IDENTIFIER).value
      if pk() and pk().kind == TK.EQ then
        ad()
        parse_expr()
      end
      while ma(TK.COMMA) do
        args[#args + 1] = ex(TK.IDENTIFIER).value
        if pk() and pk().kind == TK.EQ then
          ad()
          parse_expr()
        end
      end
    end
    ex(TK.RPAREN)
    ecs()
    return { type = "FunctionDef", name = name.value, args = args, body = parse_block_body() }
  end

  parse_if = function()
    ad()
    local test = parse_expr()
    ecs()
    local body = parse_block_body()
    local elifs = {}
    local orelse = nil
    while pk() and pk().kind == TK.ELIF do
      ad()
      local et = parse_expr()
      ecs()
      elifs[#elifs + 1] = { test = et, body = parse_block_body() }
    end
    if pk() and pk().kind == TK.ELSE then
      ad()
      ecs()
      orelse = parse_block_body()
    end
    return { type = "If", test = test, body = body, elifs = elifs, orelse = orelse }
  end

  parse_while = function()
    ad()
    local test = parse_expr()
    ecs()
    local body = parse_block_body()
    local orelse = nil
    if pk() and pk().kind == TK.ELSE then
      ad()
      ecs()
      orelse = parse_block_body()
    end
    return { type = "While", test = test, body = body, orelse = orelse }
  end

  parse_for = function()
    ad()
    local target = ex(TK.IDENTIFIER).value
    ex(TK.IN)
    local iter = nil
    local is_range = false
    local range_args = {}
    if pk() and pk().kind == TK.IDENTIFIER and pk().value == "range" then
      ad()
      if pk() and pk().kind == TK.LPAREN then
        ad()
        is_range = true
        range_args[1] = parse_expr()
        while ma(TK.COMMA) do
          range_args[#range_args + 1] = parse_expr()
        end
        ex(TK.RPAREN)
      end
    else
      iter = parse_primary()
    end
    ecs()
    local body = parse_block_body()
    local orelse = nil
    if pk() and pk().kind == TK.ELSE then
      ad()
      ecs()
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
    ad()
    ecs()
    local body = parse_block_body()
    local handlers = {}
    local finalbody = nil
    while pk() and pk().kind == TK.EXCEPT do
      ad()
      local exc_type = nil
      local exc_var = nil
      if pk() and pk().kind ~= TK.COLON then
        exc_type = parse_expr()
        if pk() and pk().kind == TK.AS then
          ad()
          exc_var = ex(TK.IDENTIFIER).value
        end
      end
      ecs()
      handlers[#handlers + 1] = { type = exc_type, name = exc_var, body = parse_block_body() }
    end
    if pk() and pk().kind == TK.FINALLY then
      ad()
      ecs()
      finalbody = parse_block_body()
    end
    return { type = "Try", body = body, handlers = handlers, finalbody = finalbody }
  end

  parse_return = function()
    ad()
    if pk() and pk().kind ~= TK.NEWLINE and pk().kind ~= TK.DEDENT and pk().kind ~= TK.EOF then
      return { type = "Return", value = parse_expr() }
    else
      return { type = "Return", value = nil }
    end
  end

  parse_block_body = function()
    while pk() and pk().kind == TK.NEWLINE do
      ad()
    end
    ex(TK.INDENT)
    local body = {}
    while pk() and pk().kind ~= TK.DEDENT and pk().kind ~= TK.EOF do
      local stmts = parse_stmt()
      if stmts then
        for _, s in ipairs(stmts) do
          body[#body + 1] = s
        end
      end
      while pk() and pk().kind == TK.NEWLINE do
        ad()
      end
    end
    ex(TK.DEDENT)
    return body
  end

  -- expression parsing
  parse_expr = function()
    return parse_lambda()
  end
  parse_lambda = function()
    if pk() and pk().kind == TK.LAMBDA then
      ad()
      local args = {}
      if pk() and pk().kind ~= TK.COLON then
        args[#args + 1] = ex(TK.IDENTIFIER).value
        while ma(TK.COMMA) do
          args[#args + 1] = ex(TK.IDENTIFIER).value
        end
      end
      ex(TK.COLON)
      return { type = "Lambda", args = args, body = parse_lambda() }
    end
    return parse_walrus()
  end
  parse_walrus = function()
    local result = parse_if_expr()
    if pk() and pk().kind == TK.WALRUS then
      ad()
      result = { type = "Walrus", target = result, value = parse_walrus() }
    end
    return result
  end
  parse_if_expr = function()
    local body = parse_or()
    if pk() and pk().kind == TK.IF then
      ad()
      local test = parse_or()
      ex(TK.ELSE)
      body = { type = "IfExpr", test = test, body = body, orelse = parse_if_expr() }
    end
    return body
  end
  parse_or = function()
    local left = parse_and()
    while pk() and pk().kind == TK.OR do
      ad()
      local r = parse_and()
      left = { type = "BoolOp", op = "or", values = { left, r } }
    end
    return left
  end
  parse_and = function()
    local left = parse_not()
    while pk() and pk().kind == TK.AND do
      ad()
      local r = parse_not()
      left = { type = "BoolOp", op = "and", values = { left, r } }
    end
    return left
  end
  parse_not = function()
    if pk() and pk().kind == TK.NOT then
      ad()
      return { type = "UnaryOp", op = "not", operand = parse_not() }
    end
    return parse_comparison()
  end

  parse_comparison = function()
    local left = parse_term()
    local om = {
      [TK.EQEQ] = "==",
      [TK.NOTEQ] = "!=",
      [TK.LESS] = "<",
      [TK.GREATER] = ">",
      [TK.LESSEQ] = "<=",
      [TK.GREATEREQ] = ">=",
    }
    local cmp_ops = {}
    local cmp_rights = {}
    while pk() do
      local t = pk()
      local op = om[t.kind]
      if not op and t.kind == TK.IS then
        ad()
        if pk() and pk().kind == TK.NOT then
          ad()
          op = "is not"
        else
          op = "is"
        end
      elseif not op and t.kind == TK.IN then
        ad()
        op = "in"
      elseif not op and t.kind == TK.NOT then
        local saved = pos
        ad()
        if pk() and pk().kind == TK.IN then
          ad()
          op = "not in"
        else
          pos = saved
          break
        end
      elseif op then
        ad()
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
    while pk() and (pk().kind == TK.PLUS or pk().kind == TK.MINUS) do
      local op = ad()
      left = { type = "BinOp", left = left, op = op.value, right = parse_factor() }
    end
    return left
  end

  parse_factor = function()
    local left = parse_unary()
    while pk() and token_mm[pk().kind] do
      local op = ad()
      left = { type = "BinOp", left = left, op = op.value, right = parse_unary() }
    end
    return left
  end

  parse_unary = function()
    if pk() and (pk().kind == TK.PLUS or pk().kind == TK.MINUS) then
      return { type = "UnaryOp", op = ad().value, operand = parse_unary() }
    end
    return parse_power()
  end

  parse_power = function()
    local left = parse_primary()
    if pk() and pk().kind == TK.DOUBLESTAR then
      ad()
      left = { type = "BinOp", left = left, op = "**", right = parse_unary() }
    end
    return left
  end

  parse_primary = function()
    local expr = parse_atom()
    while true do
      if pk() and pk().kind == TK.LPAREN then
        ad()
        local args = {}
        local keywords = {}
        local function parse_call_arg()
          local saved = pos
          local t = pk()
          local t2 = pos + 1 <= #tokens and tokens[pos + 1] or nil
          if t and t.kind == TK.IDENTIFIER and t2 and t2.kind == TK.EQ then
            ad()
            ad()
            keywords[#keywords + 1] = { arg = t.value, value = parse_expr() }
          else
            args[#args + 1] = parse_expr()
          end
        end
        if pk() and pk().kind ~= TK.RPAREN then
          parse_call_arg()
          while ma(TK.COMMA) do
            parse_call_arg()
          end
        end
        ex(TK.RPAREN)
        if #keywords > 0 then
          expr = { type = "Call", func = expr, args = args, keywords = keywords }
        else
          expr = { type = "Call", func = expr, args = args }
        end
      elseif pk() and pk().kind == TK.LBRACKET then
        ad()
        if pk() and pk().kind == TK.COLON then
          ad()
          local lower, upper, step = nil, nil, nil
          if pk() and pk().kind ~= TK.RBRACKET and pk().kind ~= TK.COLON then
            upper = parse_expr()
          end
          if pk() and pk().kind == TK.COLON then
            ad()
            if pk() and pk().kind ~= TK.RBRACKET then
              step = parse_expr()
            end
          end
          ex(TK.RBRACKET)
          expr =
            { type = "Subscript", value = expr, index = { type = "Slice", lower = lower, upper = upper, step = step } }
        else
          local idx = parse_expr()
          if pk() and pk().kind == TK.COLON then
            ad()
            local upper, step = nil, nil
            if pk() and pk().kind ~= TK.RBRACKET and pk().kind ~= TK.COLON then
              upper = parse_expr()
            end
            if pk() and pk().kind == TK.COLON then
              ad()
              if pk() and pk().kind ~= TK.RBRACKET then
                step = parse_expr()
              end
            end
            ex(TK.RBRACKET)
            expr =
              { type = "Subscript", value = expr, index = { type = "Slice", lower = idx, upper = upper, step = step } }
          else
            ex(TK.RBRACKET)
            expr = { type = "Subscript", value = expr, index = idx }
          end
        end
      elseif pk() and pk().kind == TK.DOT then
        ad()
        expr = { type = "Attribute", value = expr, attr = ex(TK.IDENTIFIER).value }
      else
        break
      end
    end
    return expr
  end

  parse_atom = function()
    local t = pk()
    if not t then
      error("unexpected EOF")
    end
    if t.kind == TK.NONE then
      ad()
      return { type = "Constant", value = nil }
    elseif t.kind == TK.TRUE then
      ad()
      return { type = "Constant", value = true }
    elseif t.kind == TK.FALSE then
      ad()
      return { type = "Constant", value = false }
    elseif t.kind == TK.ELLIPSIS then
      ad()
      return { type = "Constant", value = nil }
    elseif t.kind == TK.INTEGER or t.kind == TK.FLOAT then
      ad()
      return { type = "Constant", value = tonumber(t.value) }
    elseif t.kind == TK.STRING then
      ad()
      local val = t.value:sub(2, #t.value - 1)
      return { type = "Constant", value = unescape_string(val) }
    elseif t.kind == TK.IDENTIFIER then
      ad()
      if t.value == "None" then
        return { type = "Constant", value = nil }
      elseif t.value == "True" then
        return { type = "Constant", value = true }
      elseif t.value == "False" then
        return { type = "Constant", value = false }
      end
      return { type = "Name", id = t.value }
    elseif t.kind == TK.LPAREN then
      ad()
      local e = parse_expr()
      ex(TK.RPAREN)
      return e
    elseif t.kind == TK.LBRACKET then
      ad()
      local first = parse_expr()
      if pk() and pk().kind == TK.FOR then
        ad()
        local gens = parse_comprehension_clauses()
        ex(TK.RBRACKET)
        return { type = "ListComp", elt = first, generators = gens }
      end
      local elts = { first }
      while ma(TK.COMMA) do
        elts[#elts + 1] = parse_expr()
      end
      ex(TK.RBRACKET)
      return { type = "List", elts = elts }
    elseif t.kind == TK.LBRACE then
      ad()
      local function snl()
        while pk() and (pk().kind == TK.NEWLINE or pk().kind == TK.INDENT or pk().kind == TK.DEDENT) do
          ad()
        end
      end
      snl()
      if pk() and pk().kind ~= TK.RBRACE then
        local first = parse_expr()
        snl()
        if pk() and pk().kind == TK.COLON then
          ad()
          local key = first
          snl()
          local val = parse_expr()
          snl()
          if pk() and pk().kind == TK.FOR then
            ad()
            local gens = parse_comprehension_clauses()
            snl()
            ex(TK.RBRACE)
            return { type = "DictComp", key = key, value = val, generators = gens }
          end
          local keys = { key }
          local vals = { val }
          while ma(TK.COMMA) do
            snl()
            if pk() and pk().kind == TK.RBRACE then
              break
            end
            keys[#keys + 1] = parse_expr()
            ex(TK.COLON)
            snl()
            if pk() and pk().kind == TK.RBRACE then
              break
            end
            vals[#vals + 1] = parse_expr()
            snl()
          end
          snl()
          ex(TK.RBRACE)
          return { type = "Dict", keys = keys, values = vals }
        else
          if pk() and pk().kind == TK.FOR then
            ad()
            local gens = parse_comprehension_clauses()
            snl()
            ex(TK.RBRACE)
            return { type = "SetComp", elt = first, generators = gens }
          end
          local elts = { first }
          while ma(TK.COMMA) do
            snl()
            elts[#elts + 1] = parse_expr()
            snl()
          end
          snl()
          ex(TK.RBRACE)
          return { type = "Set", elts = elts }
        end
      else
        snl()
        ex(TK.RBRACE)
        return { type = "Set", elts = {} }
      end
    end
    error(
      "unexpected token "
        .. (tk_name[t.kind] or t.kind)
        .. " ("
        .. t.value
        .. ") at line "
        .. t.line
        .. " col "
        .. t.col
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
  local gen_comp_loops, gen_comp_loops_dc

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

  gen_comp_loops = function(elt, gens, idx)
    if idx > #gens then
      return "__res[#__res + 1] = " .. gen_expr(elt) .. "; "
    end
    local g = gens[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iter) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_comp_loops(elt, gens, idx + 1)
    for _ in ipairs(g.ifs or {}) do
      code = code .. "end "
    end
    code = code .. "end "
    return code
  end
  gen_comp_loops_dc = function(key, val, gens, idx)
    if idx > #gens then
      return "__res[" .. key .. "] = " .. val .. "; "
    end
    local g = gens[idx]
    local code = "for _, " .. g.target .. " in ipairs(" .. gen_expr(g.iter) .. ") do "
    for _, if_expr in ipairs(g.ifs or {}) do
      code = code .. "if " .. gen_expr(if_expr) .. " then "
    end
    code = code .. gen_comp_loops_dc(key, val, gens, idx + 1)
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
      local function cmp(l, op, r)
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
        return cmp(gen_expr(expr.left), expr.ops[1], gen_expr(expr.comparators[1]))
      else
        local parts = {}
        local prev = gen_expr(expr.left)
        for i = 1, #expr.ops do
          local r = gen_expr(expr.comparators[i])
          parts[#parts + 1] = cmp(prev, expr.ops[i], r)
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
        local kw_parts = {}
        for _, kw in ipairs(expr.keywords) do
          kw_parts[#kw_parts + 1] = "[" .. gen_str(kw.arg) .. "] = " .. gen_expr(kw.value)
        end
        args[#args + 1] = "{" .. table.concat(kw_parts, ", ") .. "}"
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
      return "(function() local __res = {} " .. gen_comp_loops(expr.elt, expr.generators, 1) .. " return __res end)()"
    elseif expr.type == "DictComp" then
      local key = gen_expr(expr.key)
      local val = gen_expr(expr.value)
      return "(function() local __res = {} "
        .. gen_comp_loops_dc(key, val, expr.generators, 1)
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
      local ts = flatten_targets(stmt.targets)
      push(indent() .. table.concat(ts, ", ") .. " = " .. gen_expr(stmt.value))
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
      push(indent() .. "-- global " .. table.concat(stmt.names, ", "))
    elseif stmt.type == "Pass" then
      push(indent() .. "-- pass")
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
