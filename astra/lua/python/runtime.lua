local generator = require("python.generator")
local parser = require("python.parser")
local tokenizer = require("python.tokenizer")
local optimizer = require("python.optimizer")

local python = {}

function python.transpile(source, opts)
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
  local analysis = optimizer.analyze(ast, opts)
  local lua_code = generator.generate(ast, analysis)
  python.last_code = lua_code
  return lua_code
end

function python.run(source, opts)
  local lua_code = python.transpile(source, opts)
  local fn, err = load(lua_code, "=python")
  if not fn then
    error("Python runtime error: " .. tostring(err))
  end
  return fn()
end

function python.transpile_file(path, opts)
  local fs = require("fs")
  local source = fs.read_file(path)
  return python.transpile(source, opts)
end

function python.run_file(path, opts)
  local fs = require("fs")
  local source = fs.read_file(path)
  return python.run(source, opts)
end

return python
