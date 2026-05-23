--- Parser context shared between expression and statement parsers.
-- Creates a fresh state object for each parse invocation, providing
-- all token-manipulation helpers (peek, advance, match, expect, etc.).
local token = require("python.token")
local TK = token.TK
local token_names = token.token_names

--- Creates a fresh parser state from a token stream.  The state holds
-- the current position and all helpers consumed by the parse functions.
---@param tokens table  Array of token objects from the tokenizer
---@return table  State with .tokens, .position, and helper methods
local function create_state(tokens)
  local state = {
    tokens = tokens,
    position = 1,
  }

  function state:peek_token()
    return self.tokens[self.position]
  end

  function state:advance_token()
    local tok = self.tokens[self.position]
    self.position = self.position + 1
    return tok
  end

  function state:match_token(kind)
    local tok = self:peek_token()
    if tok and tok.kind == kind then
      self:advance_token()
      return true
    end
    return false
  end

  function state:expect_token(kind)
    local tok = self:peek_token()
    if not tok or tok.kind ~= kind then
      error(
        "expected "
          .. (token_names[kind] or kind)
          .. " got "
          .. (tok and (token_names[tok.kind] or tok.kind) or "EOF")
          .. " at line "
          .. (tok and tok.line or "?")
          .. " col "
          .. (tok and tok.col or "?")
      )
    end
    return self:advance_token()
  end

  function state:peek_is(kind)
    local tok = self:peek_token()
    return tok and tok.kind == kind
  end

  function state:peek_not(kind)
    local tok = self:peek_token()
    return tok and tok.kind ~= kind
  end

  function state:peek_one_of(...)
    local tok = self:peek_token()
    if not tok then
      return false
    end
    for _, k in ipairs({ ... }) do
      if tok.kind == k then
        return true
      end
    end
    return false
  end

  return state
end

return { create_state = create_state }
