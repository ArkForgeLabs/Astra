local fs = require("fs")
local import = require("python.import")
local util = require("python.util")

local python = {}

function python.transpile(source, opts)
  opts = opts or {}
  local lua_code, prog = import.transpile_source(source, opts)

  local cwd = opts.cwd
  if not cwd and MAIN_SCRIPT then
    cwd = util.dirname(MAIN_SCRIPT)
  end
  if cwd then
    import.resolve(prog, cwd, opts)
  end

  python.last_code = lua_code
  return lua_code
end

function python.eval(source, opts)
  local lua_code = python.transpile(source, opts)
  local chunk, err = load(lua_code, "=python")
  if not chunk then
    error("Python runtime error: " .. tostring(err))
  end
  return chunk()
end
python.run = python.eval

function python.transpile_file(path, opts)
  opts = opts or {}
  local merged = { cwd = util.dirname(path) }
  if opts.path then
    merged.path = opts.path
  end
  return python.transpile(fs.read_file(path), merged)
end

function python.eval_file(path, opts)
  opts = opts or {}
  local merged = { cwd = util.dirname(path) }
  if opts.path then
    merged.path = opts.path
  end
  return python.eval(fs.read_file(path), merged)
end
python.run_file = python.eval_file

return python
