local run_python = require("tests.python_tests.run_python")
local run_lua = require("tests.python_tests.run_lua")

local cases_dir = "tests/python_tests/cases/"

return function(test)

local files = {
  "arithmetic.py",
  "boolean_ops.py",
  "builtins.py",
  "class_decorators.py",
  "class_dunders.py",
  "classes.py",
  "comparisons.py",
  "comprehensions.py",
  "data_structures.py",
  "decorators.py",
  "exceptions.py",
  "functions.py",
  "if_else.py",
  "kwargs_star.py",
  "lambdas.py",
  "loops.py",
  "slice_assign.py",
  "super_calls.py",
  "variables.py",
}

-- Check if python3 is available
local has_python = false
local handle = io.popen("python3 --version 2>&1", "r")
if handle then
  local out = handle:read("*a")
  handle:close()
  has_python = out and out ~= ""
end

  local function normalize_bool(s)
    local lines = {}
    for line in s:gmatch("([^\n]*)\n?") do
      if line == "true" then line = "True"
      elseif line == "false" then line = "False" end
      lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
  end

  for _, fname in ipairs(files) do
    local filepath = cases_dir .. fname
    test.it("equivalence: " .. fname, function()
      local py_code = io.open(filepath):read("*a")
      if not py_code then
        test.expect(false).to.equal(true, "could not read " .. filepath)
        return
      end

      -- Run through Lua transpiler
      local lua_out = run_lua.execute(py_code)
      lua_out = normalize_bool(lua_out)

      -- Run through Python if available
      if has_python then
        local python_out = run_python.execute(filepath)
        test.expect(lua_out).to.equal(python_out, fname .. " output mismatch")
      else
        -- Without python3, just verify Lua runs without errors
        test.expect(lua_out).to_not.match("error")
        test.expect(lua_out).to_not.match("panic")
      end
    end)
  end

end
