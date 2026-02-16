local fs = require("fs")
local sep = fs.get_separator()
local base = "tests" .. sep

local list = { "astra", "http", "jinja2", "validation", "serde", "datetime", "fs" }
for _, name in ipairs(list) do
  local chunk, err_load = loadfile(base .. name .. ".lua")
  if not chunk then
    print("FAIL " .. name .. ": " .. tostring(err_load))
    os.exit(1)
  end
  local ok, err = pcall(chunk)
  if not ok then
    print("FAIL " .. name .. ": " .. tostring(err))
    os.exit(1)
  end
  print("OK " .. name)
end
print("All tests passed.")
os.exit(0)
