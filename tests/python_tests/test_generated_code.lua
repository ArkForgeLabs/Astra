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
  test.it("generates inline subscript for list access", function()
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
    test.expect(body).to.match('"a"')
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

  test.it("generates inline endswith for .endswith()", function()
    local lua = python.transpile('s.endswith("x")')
    test.expect(lua).to.match(":sub%(%-")
  end)

  test.it("generates __name__ == __main__ guard", function()
    local lua = python.transpile("__name__ == '__main__'")
    test.expect(lua).to.match("MAIN_SCRIPT == CURRENT_SCRIPT")
  end)

  test.it("generates import as global stmt", function()
    local body = strip_preamble(python.transpile("global x"))
    test.expect(type(body)).to.equal("string")
  end)

  test.it("for loop uses __py_for_vars unpacking for multi-target", function()
    local body = strip_preamble(python.transpile("for a, b in items:\n    pass"))
    test.expect(body).to.match("__py_for_vars")
  end)

  test.it("string concatenation uses Lua ..", function()
    local lua = python.transpile('"a" + "b"')
    test.expect(lua).to.match("%.%.%s")
  end)

  test.it("preamble inlines stdlib functions", function()
    local lua = python.transpile("x = len([1,2,3])")
    test.expect(lua).to.match("getmetatable")
    test.expect(lua).to.match("local chr, ord, str, int")
  end)

  test.it("class generates __call metamethod", function()
    local body = strip_preamble(python.transpile("class X:\n    pass"))
    test.expect(body).to.match("__call = function%(cls")
  end)

  test.it("class with inheritance generates __py_base", function()
    local body = strip_preamble(python.transpile("class X(Base):\n    pass"))
    test.expect(body).to.match("__py_base")
  end)

  test.it("preserves single-line comments", function()
    local lua = python.transpile("# hello world\nx = 1")
    test.expect(lua).to.match("-- hello world")
    test.expect(lua).to.match("x = 1")
  end)

  test.it("preserves inline comments", function()
    local lua = python.transpile("x = 1  # inline")
    test.expect(lua).to.match("x = 1")
    test.expect(lua).to.match("-- inline")
  end)

  test.it("preserves multi-line comments as block", function()
    local lua = python.transpile("# line 1\n# line 2\nx = 1")
    test.expect(lua).to.match("%-%-%[%[ line 1.line 2 %]%]")
    test.expect(lua).to.match("x = 1")
  end)

  test.it("generates import as stdlib inline table", function()
    local body = strip_preamble(python.transpile("import math"))
    test.expect(body).to.match("local math = {")
  end)

  test.it("generates import as stdlib inline table with alias", function()
    local body = strip_preamble(python.transpile("import math as m"))
    test.expect(body).to.match("local m = {")
  end)

  test.it("generates from import as inline value", function()
    local body = strip_preamble(python.transpile("from math import sqrt"))
    test.expect(body).to.match('local sqrt = math%.sqrt')
  end)

  test.it("generates from import with alias inline", function()
    local body = strip_preamble(python.transpile("from math import sqrt as sq"))
    test.expect(body).to.match('local sq = math%.sqrt')
  end)

  test.it("generates multi-name from import", function()
    local body = strip_preamble(python.transpile("from sys import argv, exit"))
    test.expect(body).to.match("argv = setmetatable")
    test.expect(body).to.match("exit = os%.exit")
  end)

  test.it("generates from import *", function()
    local body = strip_preamble(python.transpile("from math import *"))
    test.expect(body).to.match("for k, v in pairs%(require%('math'%)%) do _ENV%[k%] = v end")
  end)

  test.it("raises error with error()", function()
    local lua = python.transpile('raise ValueError("bad")')
    test.expect(lua).to.match("error%(ValueError%(.")
  end)

  test.it("raise from generates cause chain", function()
    local lua = python.transpile("raise X from Y")
    test.expect(lua).to.match("__cause")
  end)

  test.it("assert generates conditional error", function()
    local lua = python.transpile("assert x > 0")
    test.expect(lua).to.match("if not %(")
    test.expect(lua).to.match("error%(\"assertion failed\"%)")
  end)

  test.it("assert with message includes it", function()
    local lua = python.transpile('assert x > 0, "bad x"')
    test.expect(lua).to.match('"bad x"')
  end)

  test.it("del name generates nil assignment", function()
    local body = strip_preamble(python.transpile("del x"))
    test.expect(body).to.match("x = nil")
  end)

  test.it("del subscript generates table.remove", function()
    local body = strip_preamble(python.transpile("del items[0]"))
    test.expect(body).to.match("table%.remove%(items,")
  end)

  test.it("del attribute generates nil", function()
    local body = strip_preamble(python.transpile("del obj.attr"))
    test.expect(body).to.match("obj%.attr = nil")
  end)

  test.it("bitwise AND generates __py_band", function()
    local lua = python.transpile("x = a & b")
    test.expect(lua).to.match("__py_band")
  end)

  test.it("bitwise OR generates __py_bor", function()
    local lua = python.transpile("x = a | b")
    test.expect(lua).to.match("__py_bor")
  end)

  test.it("bitwise XOR generates __py_bxor", function()
    local lua = python.transpile("x = a ^ b")
    test.expect(lua).to.match("__py_bxor")
  end)

  test.it("left shift generates __py_lshift", function()
    local lua = python.transpile("x = a << 2")
    test.expect(lua).to.match("__py_lshift")
  end)

  test.it("bitwise NOT generates __py_bnot", function()
    local lua = python.transpile("x = ~a")
    test.expect(lua).to.match("__py_bnot")
  end)

  test.it("generates nonlocal as no-op", function()
    local lua = python.transpile("def f():\n    nonlocal x")
    test.expect(type(lua)).to.equal("string")
  end)

  test.it("async def wraps in spawn_task", function()
    local lua = python.transpile("async def f():\n    return 42")
    test.expect(lua).to.match("spawn_task")
  end)

  test.it("await generates :await() call", function()
    local lua = python.transpile("async def f():\n    await x\n    return 1")
    test.expect(lua).to.match(":await%(%)")
  end)

  test.it("with statement generates __enter__ and __exit__", function()
    local lua = python.transpile("with x as y:\n    pass")
    test.expect(lua).to.match("__enter__")
    test.expect(lua).to.match("__exit__")
    test.expect(lua).to.match("pcall")
  end)

  test.it("yield generates coroutine.yield", function()
    local lua = python.transpile("def g():\n    yield 42")
    test.expect(lua).to.match("coroutine%.yield")
  end)

  test.it("generator function wraps in coroutine.wrap", function()
    local lua = python.transpile("def g():\n    yield 42")
    test.expect(lua).to.match("coroutine%.wrap")
  end)

  test.it("for/else generates do block after loop", function()
    local body = strip_preamble(python.transpile("for i in range(5):\n    pass\nelse:\n    print('done')"))
    test.expect(body).to.match("^do")
    test.expect(body).to.match("end$")
  end)
end
