local run_python = {}

function run_python.execute(filepath)
  local handle = io.popen("python3 " .. filepath .. " 2>&1", "r")
  local out = handle:read("*a")
  handle:close()
  return out
end

return run_python
