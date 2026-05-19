local token = require("python.token")
local TK = token.TK
local keyword_token_map = token.keyword_token_map
local two_character_tokens = token.two_character_tokens
local single_character_tokens = token.single_character_tokens

local tokenizer = {}
function tokenizer.tokenize(source)
  local tokens = {}
  local line = 1
  local col = 1
  local i = 1
  local n = #source
  local indent_stack = { 0 }
  local at_line_start = true
  local bracket_depth = 0

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

  local function is_string_prefix(word)
    local lower = word:lower()
    return lower == "f"
      or lower == "r"
      or lower == "b"
      or lower == "u"
      or lower == "rf"
      or lower == "fr"
      or lower == "rb"
      or lower == "br"
  end

  local function read_quoted_string(start_index, quote_char)
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
      read_quoted_string(i, ch)
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
      local next_char = i <= n and source:sub(i, i) or ""
      if (next_char == '"' or next_char == "'") and is_string_prefix(word) then
        read_quoted_string(start_index + #word, next_char)
      else
        emit_token(keyword_token_map[word] or TK.IDENTIFIER, word)
      end
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
        elseif next_char == "\r" and i + 2 <= n and source:sub(i + 2, i + 2) == "\n" then
          i = i + 3
          line = line + 1
          col = 1
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

return tokenizer
