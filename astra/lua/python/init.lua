local generator = require("python.generator")
local optimizer = require("python.optimizer")
local parser = require("python.parser")
local tokenizer = require("python.tokenizer")

local python = {}

function python.transpile(source, opts)
  local tokens = tokenizer.tokenize(source)
  local ast = parser.parse(tokens)
  local analysis = optimizer.analyze(ast, opts)
  local lua_code = generator.generate(ast, analysis)
  python.last_code = lua_code
  return lua_code
end

function python.run(source, opts)
  local lua_code = python.transpile(source, opts)
  local chunk, err = load(lua_code, "=python")
  if not chunk then
    error("Python runtime error: " .. tostring(err))
  end
  return chunk()
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
