local ast = require("python.ast")
local TK = require("python.token").TK
local parser_context = require("python.parser.context")
local expression_parser = require("python.parser.expression")
local statement_parser = require("python.parser.statement")

local parser = {}

function parser.parse(tokens)
  local state = parser_context.create_state(tokens)
  local parse_block_body, parse_statements
  local stmt

  local function expect_colon_newline()
    state:expect_token(TK.COLON)
    while state:peek_is(TK.COMMENT) do
      state:advance_token()
    end
    if state:peek_is(TK.NEWLINE) then
      state:advance_token()
    end
  end

  local expr = expression_parser(state, parser.parse)

  parse_statements = function()
    local body = {}
    while state:peek_not(TK.DEDENT) and state:peek_token().kind ~= TK.EOF do
      while state:peek_is(TK.NEWLINE) do
        state:advance_token()
      end
      if state:peek_one_of(TK.DEDENT, TK.EOF) then
        break
      end
      if state:peek_is(TK.COMMENT) then
        local comment_lines = {}
        local blank_count = 0
        while state:peek_is(TK.COMMENT) do
          comment_lines[#comment_lines + 1] = state:advance_token().value
          while state:peek_is(TK.NEWLINE) do
            state:advance_token()
            blank_count = blank_count + 1
          end
        end
        body[#body + 1] = ast.Comment(table.concat(comment_lines, "\n"))
        if blank_count > #comment_lines then
          for _ = 1, blank_count - #comment_lines do
            body[#body + 1] = ast.Comment("")
          end
        end
      else
        local stmts = stmt.parse_stmt(parse_block_body)
        if stmts then
          for _, s in ipairs(stmts) do
            body[#body + 1] = s
          end
        end
        while state:peek_is(TK.COMMENT) do
          body[#body + 1] = ast.Comment(state:advance_token().value)
        end
        local blank_count = 0
        while state:peek_is(TK.NEWLINE) do
          state:advance_token()
          blank_count = blank_count + 1
        end
        if blank_count > 1 then
          for _ = 1, blank_count - 1 do
            body[#body + 1] = ast.Comment("")
          end
        end
      end
    end
    return body
  end

  parse_block_body = function()
    while state:peek_is(TK.NEWLINE) do
      state:advance_token()
    end
    state:expect_token(TK.INDENT)
    local body = parse_statements()
    state:expect_token(TK.DEDENT)
    return body
  end

  stmt = statement_parser(state, expr)

  local function parse_program()
    while state:peek_is(TK.NEWLINE) do
      state:advance_token()
    end
    return ast.Program(parse_statements())
  end

  return parse_program()
end

return parser
