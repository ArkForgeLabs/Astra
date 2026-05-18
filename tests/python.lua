require("test")
local python = require("python")

return function(test)
  test.describe("Python transpiler", function()
    test.it("transpiles arithmetic", function()
      local code = python.transpile("x = 1 + 2")
      test.expect(code).to.be.a("string")
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles variable assignment", function()
      local code = python.transpile("x = 42")
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles function definition", function()
      local code = python.transpile([[
def add(a, b):
    return a + b
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles indents", function()
      local code = python.transpile([[
print(1 + 2)

  ]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("handles blank lines before indented blocks", function()
      local ok = pcall(python.run, [[
def foo():

    return 42
print(foo())
]])
      test.expect(ok).to.equal(true)
    end)

    test.it("transpiles if/elif/else", function()
      local code = python.transpile([[
x = 0
if x > 0:
    y = 1
elif x == 0:
    y = 0
else:
    y = -1
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles for range loops", function()
      local code = python.transpile([[
total = 0
for i in range(5):
    total = total + i
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles while loops", function()
      local code = python.transpile([[
x = 0
while x < 3:
    x = x + 1
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles list indexing (0->1)", function()
      local code = python.transpile([[
nums = [10, 20, 30]
print(nums[0])
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles dict with string keys", function()
      local code = python.transpile([[
d = {"key": "value"}
print(d["key"])
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles boolean/None literals", function()
      test.expect(python.transpile("x = None")).to.match("nil")
      test.expect(python.transpile("x = True")).to.match("true")
      test.expect(python.transpile("x = False")).to.match("false")
    end)

    test.it("transpiles comparisons (is, in, !=)", function()
      test.expect(python.transpile("x is None")).to.match("==")
      test.expect(python.transpile("x is not None")).to.match("~=")
      test.expect(python.transpile("x != y")).to.match("~=")
      test.expect(python.transpile("x in y")).to.match("__py_in")
      test.expect(python.transpile("x not in y")).to.match("__py_in")
    end)

    test.it("transpiles pass/break/continue", function()
      local code = python.transpile([[
for i in range(10):
    if i == 5:
        break
    if i == 3:
        continue
]])
      test.expect(load(code)).to.be.a("function")
      test.expect(code).to.match("goto __continue")
      test.expect(code).to.match("__continue::")
    end)

    test.it("transpiles augmented assignment", function()
      local code = python.transpile([[
x = 5
x += 3
x -= 1
x *= 2
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("transpiles nested functions", function()
      local code = python.transpile([[
def outer():
    def inner():
        return 42
    return inner()
]])
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("runs python code and returns value", function()
      local result = python.run("return 1 + 2")
      test.expect(result).to.equal(3)
    end)

    test.it("runs python print via Astra", function()
      local ok = pcall(python.run, [[print("hello from python")]])
      test.expect(ok).to.equal(true)
    end)
  end)
end
