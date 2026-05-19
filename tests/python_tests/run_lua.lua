local python = require("python")

local run_lua = {}

function run_lua.execute(py_code)
  local lua_code = python.transpile(py_code)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(lua_code)
  f:close()
  local handle = io.popen("LUA_PATH='./astra/lua/?.lua;./astra/lua/?/?.lua;./astra/lua/?/init.lua;;' luajit " .. tmp .. " 2>&1", "r")
  local out = handle:read("*a")
  handle:close()
  os.remove(tmp)
  return out
end

return run_lua
