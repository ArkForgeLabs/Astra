local token = require("python.token")
local TK = token.TK
local keyword_token_map = token.keyword_token_map
local multi_character_tokens = token.multi_character_tokens
local single_character_tokens = token.single_character_tokens

local tokenizer = {}
---@param source string
---@return token_obj[]
function tokenizer.tokenize(source)
  local tokens = {}
  local line = 1
  local col = 1
  local source_pos = 1
  local source_len = #source
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
    source_pos = source_pos + 1
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
    if source:sub(source_pos, source_pos + 1) == quote_char .. quote_char then
      source_pos = source_pos + 2
      col = col + 2
      while source_pos <= source_len do
        if source:sub(source_pos, source_pos + 2) == quote_char .. quote_char .. quote_char then
          source_pos = source_pos + 3
          col = col + 3
          break
        end
        if source:sub(source_pos, source_pos) == "\n" then
          line = line + 1
          col = 1
        else
          col = col + 1
        end
        source_pos = source_pos + 1
      end
      emit_token(TK.STRING, source:sub(start_index, source_pos - 1))
    else
      while source_pos <= source_len do
        local c = source:sub(source_pos, source_pos)
        if c == "\\" then
          source_pos = source_pos + 2
          col = col + 2
        elseif c == quote_char then
          advance_char()
          break
        else
          advance_char()
        end
      end
      emit_token(TK.STRING, source:sub(start_index, source_pos - 1))
    end
  end

  while source_pos <= source_len do
    local char = source:sub(source_pos, source_pos)

    if char == "\n" then
      if bracket_depth > 0 then
        source_pos = source_pos + 1
        line = line + 1
        col = 1
      else
        emit_token(TK.NEWLINE, "\n")
        line = line + 1
        col = 1
        source_pos = source_pos + 1
        at_line_start = true
      end
    elseif at_line_start then
      if char == " " or char == "\t" then
        local indent_count = 0
        local indent_char = char
        while source_pos <= source_len do
          local c = source:sub(source_pos, source_pos)
          if c == " " or c == "\t" then
            indent_count = indent_count + (c ~= indent_char and (c == "\t" and 4 or 1) or 1)
            advance_char()
          else
            break
          end
        end
        local current_indent = indent_stack[#indent_stack]
        local next_char = source_pos <= source_len and source:sub(source_pos, source_pos) or ""
        if next_char ~= "\n" and next_char ~= "" then
          if indent_count > current_indent then
            emit_token(TK.INDENT)
            indent_stack[#indent_stack + 1] = indent_count
          elseif indent_count < current_indent then
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
    elseif char == "#" then
      local start = source_pos + 1
      while source_pos <= source_len and source:sub(source_pos, source_pos) ~= "\n" do
        advance_char()
      end
      local text = source:sub(start, source_pos - 1)
      text = text:match("^%s*(.-)%s*$") or ""
      emit_token(TK.COMMENT, text)
    elseif char == '"' or char == "'" then
      read_quoted_string(source_pos, char)
    elseif char >= "0" and char <= "9" then
      local start_index = source_pos
      local is_float = false
      advance_char()
      while source_pos <= source_len do
        local c = source:sub(source_pos, source_pos)
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
      emit_token(is_float and TK.FLOAT or TK.INTEGER, source:sub(start_index, source_pos - 1))
    elseif (char >= "a" and char <= "z") or (char >= "A" and char <= "Z") or char == "_" then
      local start_index = source_pos
      advance_char()
      while source_pos <= source_len do
        local c = source:sub(source_pos, source_pos)
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" then
          advance_char()
        else
          break
        end
      end
      local word = source:sub(start_index, source_pos - 1)
      local next_char = source_pos <= source_len and source:sub(source_pos, source_pos) or ""
      if (next_char == '"' or next_char == "'") and is_string_prefix(word) then
        read_quoted_string(start_index + #word, next_char)
      else
        emit_token(keyword_token_map[word] or TK.IDENTIFIER, word)
      end
    else
      local next_two = source_pos + 1 <= source_len and source:sub(source_pos, source_pos + 1) or ""
      local next_three = source_pos + 2 <= source_len and source:sub(source_pos, source_pos + 2) or ""

      if multi_character_tokens[next_three] then
        emit_token(multi_character_tokens[next_three], next_three)
        source_pos = source_pos + 3
        col = col + 3
      elseif multi_character_tokens[next_two] then
        emit_token(multi_character_tokens[next_two], next_two)
        source_pos = source_pos + 2
        col = col + 2
      elseif single_character_tokens[char] then
        emit_token(single_character_tokens[char], char)
        advance_char()
      elseif char == " " or char == "\t" or char == "\r" then
        advance_char()
      elseif char == "\\" then
        local next_char = source_pos + 1 <= source_len and source:sub(source_pos + 1, source_pos + 1) or ""
        if next_char == "\n" then
          source_pos = source_pos + 2
          line = line + 1
          col = 1
        elseif
          next_char == "\r"
          and source_pos + 2 <= source_len
          and source:sub(source_pos + 2, source_pos + 2) == "\n"
        then
          source_pos = source_pos + 3
          line = line + 1
          col = 1
        else
          error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. char)
        end
      else
        error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. char)
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
