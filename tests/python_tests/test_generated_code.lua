local python = require("python")

local function strip_preamble(lua)
  -- Remove everything up to and including the first "end" that closes the preamble
  local i = lua:find("\nend\n")
  if i then
    return lua:sub(i + 5)
  end
  return lua
end

return function(test)

test.it("generates __py_getitem for list access", function()
  local lua = python.transpile("items[0]")
  test.expect(lua).to.match("__py_getitem%(items, 0 %+ 1%)")
end)

test.it("generates __py_slice for slice access", function()
  local lua = python.transpile("items[1:3]")
  test.expect(lua).to.match("__py_slice%(items, 1, 3, nil%)")
end)

test.it("generates __py_repeat for list multiplication", function()
  local lua = python.transpile("[0] * 10")
  test.expect(lua).to.match("__py_repeat%(.+%)")
end)

test.it("generates colon syntax for method calls", function()
  local body = strip_preamble(python.transpile("x.get()"))
  test.expect(body).to.match("x:get%(%)")
end)

test.it("generates __py_call for keyword args", function()
  local body = strip_preamble(python.transpile("f(a=1)"))
  test.expect(body).to.match("__py_call%(")
end)

test.it("generates table.unpack for starred args", function()
  local body = strip_preamble(python.transpile("f(*args)"))
  test.expect(body).to.match("table%.unpack%(")
end)

test.it("for range generates numeric for loop", function()
  local body = strip_preamble(python.transpile("for i in range(5):\n    pass"))
  test.expect(body).to.match("for i = 0, 5 %- 1, 1 do")
end)

test.it("generates __py_in for 'in' operator", function()
  local lua = python.transpile("x in y")
  test.expect(lua).to.match("__py_in%(")
end)

test.it("generates __py_items for .items()", function()
  local lua = python.transpile("d.items()")
  test.expect(lua).to.match("__py_items%(")
end)

test.it("generates __py_endswith for .endswith()", function()
  local lua = python.transpile('s.endswith("x")')
  test.expect(lua).to.match("__py_endswith%(")
end)

test.it("generates __name__ == __main__ guard", function()
  local lua = python.transpile("__name__ == '__main__'")
  test.expect(lua).to.match("MAIN_SCRIPT == CURRENT_SCRIPT")
end)

test.it("generates import as global stmt", function()
  local body = strip_preamble(python.transpile("global x"))
  test.expect(type(body)).to.equal("string")
end)

test.it("for loop uses __pair unpacking for multi-target", function()
  local body = strip_preamble(python.transpile("for a, b in items:\n    pass"))
  test.expect(body).to.match("__pair")
end)

test.it("string concatenation uses Lua ..", function()
  local lua = python.transpile('"a" + "b"')
  test.expect(lua).to.match("%.%.%s")
end)

test.it("generates int = __py_int alias", function()
  local lua = python.transpile("")
  test.expect(lua).to.match("int = __py_int")
end)

test.it("generates range = __py_range alias", function()
  local lua = python.transpile("")
  test.expect(lua).to.match("range = __py_range")
end)

test.it("class generates __call metamethod", function()
  local body = strip_preamble(python.transpile("class X:\n    pass"))
  test.expect(body).to.match("__call = function%(cls")
end)

test.it("class with inheritance generates __py_base", function()
  local body = strip_preamble(python.transpile("class X(Base):\n    pass"))
  test.expect(body).to.match("__py_base")
end)

end
