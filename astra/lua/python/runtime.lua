local generator = require("python.generator")
local parser = require("python.parser")
local tokenizer = require("python.tokenizer")

local python = {}

function python.transpile(source)
  local lines = {}
  for line in source:gmatch("[^\n]+") do
    line = line:match("^(.-)%s*$")
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  source = table.concat(lines, "\n")
  local tokens = tokenizer.tokenize(source)
  local ast = parser.parse(tokens)
  local lua_code = generator.generate(ast)
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
