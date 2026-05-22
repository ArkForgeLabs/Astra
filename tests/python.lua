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
      local ok = pcall(
        python.run,
        [[
def foo():

    return 42
print(foo())
]]
      )
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

    -- ============================================================
    -- TDD: Features not yet implemented — tests document expected behavior

    -- ============================================================
    -- TDD: Features not yet implemented
    -- ============================================================

    test.it("TDD: chained comparisons (1 < x < 10)", function()
      local code = python.transpile("x = 1 < 2 < 3")
      test.expect(code).to.match("and")
    end)

    test.it("TDD: ternary if-else expression", function()
      local result = python.run("return 1 if True else 2")
      test.expect(result).to.equal(1)
    end)

    test.it("TDD: walrus operator (x := 1)", function()
      local result = python.run([[
x = 0
y = (x := 1)
return x + y
]])
      test.expect(result).to.equal(2)
    end)

    test.it("TDD: list comprehension", function()
      local res = python.run("return [x * 2 for x in range(3)]")
      test.expect(res[1]).to.equal(0)
      test.expect(res[2]).to.equal(2)
      test.expect(res[3]).to.equal(4)
    end)

    test.it("TDD: dict comprehension", function()
      local res = python.run("return {n: n * 2 for n in [1, 2, 3]}")
      test.expect(res[1]).to.equal(2)
      test.expect(res[2]).to.equal(4)
      test.expect(res[3]).to.equal(6)
    end)

    test.it("TDD: set literal {1, 2, 3}", function()
      local code = python.transpile("s = {1, 2, 3}")
      test.expect(load(code)).to.be.a("function")
    end)

    test.it("TDD: set comprehension", function()
      local code = python.transpile("{x for x in range(3)}")
      test.expect(code).to.be.a("string")
    end)

    test.it("TDD: slice syntax x[1:3]", function()
      local res = python.run([[
x = [0, 1, 2, 3]
return x[1:3]
]])
      test.expect(res[1]).to.equal(1)
      test.expect(res[2]).to.equal(2)
    end)

    test.it("TDD: nested comprehension", function()
      local res = python.run("return [x * y for x in [1, 2] for y in [3, 4]]")
      test.expect(res[1]).to.equal(3)
      test.expect(res[2]).to.equal(4)
      test.expect(res[3]).to.equal(6)
      test.expect(res[4]).to.equal(8)
    end)

    test.it("TDD: try/except/finally", function()
      local ok, result = pcall(
        python.run,
        [[
try:
    x = 1
except:
    x = 2
finally:
    y = 3
return x + y
]]
      )
      test.expect(ok).to.equal(true)
      test.expect(result).to.equal(4)
    end)

    test.it("TDD: lambda expression", function()
      local result = python.run([[
f = lambda x: x + 1
return f(5)
]])
      test.expect(result).to.equal(6)
    end)

    test.it("TDD: for/else", function()
      local result = python.run([[
for i in range(3):
    pass
else:
    result = 42
return result
]])
      test.expect(result).to.equal(42)
    end)

    test.it("TDD: while/else", function()
      local result = python.run([[
while False:
    pass
else:
    return 42
]])
      test.expect(result).to.equal(42)
    end)

    test.it("TDD: keyword arguments in calls", function()
      local result = python.run([[
def add(a, b):
    return a + b
return add(b = 2, a = 1)
]])
      test.expect(result).to.equal(3)
    end)

    test.it("TDD: starred unpacking *args", function()
      local result = python.run([[
def add(a, b):
    return a + b
nums = [1, 2]
return add(*nums)
]])
      test.expect(result).to.equal(3)
    end)

    test.it("TDD: tuple unpacking a, b = b, a", function()
      local result = python.run([[
a, b = 1, 2
a, b = b, a
return a * 10 + b
]])
      test.expect(result).to.equal(21)
    end)

    test.it("TDD: ellipsis literal", function()
      local code = python.transpile("x = ...")
      test.expect(code).to.be.a("string")
    end)
    test.it("TDD: empty class", function()
      local result = python.run([[
class X:
    pass
return "ok"
]])
      test.expect(result).to.equal("ok")
    end)
    test.it("TDD: class with method", function()
      local result = python.run([[
class X:
    def method(self):
        return 42
x = X()
return x.method()
]])
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: class with __init__", function()
      local result = python.run([[
class X:
    def __init__(self, val):
        self.val = val
    def get(self):
        return self.val
x = X(99)
return x.get()
]])
      test.expect(result).to.equal(99)
    end)
    test.it("TDD: class inheritance", function()
      local result = python.run([[
class Base:
    def meth(self):
        return 1
class Derived(Base):
    def meth(self):
        return 2
d = Derived()
return d.meth()
]])
      test.expect(result).to.equal(2)
    end)
    test.it("TDD: function decorator", function()
      local result = python.run([[
def deco(fn):
    return lambda: 42
@deco
def foo():
    return 0
return foo()
]])
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: class variable", function()
      local result = python.run([[
class X:
    val = 42
return X.val
]])
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: super() call", function()
      local result = python.run([[
class Base:
    def method(self):
        return 1
class Derived(Base):
    def method(self):
        return super().method() + 1
d = Derived()
return d.method()
]])
      test.expect(result).to.equal(2)
    end)
    test.it("TDD: staticmethod", function()
      local result = python.run([[
class X:
    @staticmethod
    def add(a, b):
        return a + b
return X.add(3, 4)
]])
      test.expect(result).to.equal(7)
    end)
    test.it("TDD: classmethod", function()
      local result = python.run([[
class X:
    count = 0
    @classmethod
    def get_count(cls):
        return cls.count
return X.get_count()
]])
      test.expect(result).to.equal(0)
    end)
    test.it("TDD: __str__ dunder", function()
      local result = python.run([[
class X:
    def __init__(self, val):
        self.val = val
    def __str__(self):
        return self.val
x = X("hello")
return str(x)
]])
      test.expect(result).to.equal("hello")
    end)
    test.it("TDD: __len__ dunder", function()
      local result = python.run([[
class X:
    def __init__(self, items):
        self.items = items
    def __len__(self):
        return len(self.items)
x = X([1, 2, 3])
return len(x)
]])
      test.expect(result).to.equal(3)
    end)
    test.it("TDD: __add__ dunder", function()
      local result = python.run([[
class X:
    def __init__(self, val):
        self.val = val
    def __add__(self, other):
        return X(self.val + other.val)
    def get(self):
        return self.val
a = X(10)
b = X(20)
c = a + b
return c.get()
]])
      test.expect(result).to.equal(30)
    end)
    test.it("TDD: @property", function()
      local result = python.run([[
class X:
    def __init__(self, val):
        self._val = val
    @property
    def val(self):
        return self._val
x = X(42)
return x.val
]])
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: isinstance", function()
      local result = python.run([[
class Base:
    pass
class Derived(Base):
    pass
d = Derived()
return isinstance(d, Base)
]])
      test.expect(result).to.equal(true)
    end)
    test.it("TDD: isinstance false", function()
      local result = python.run([[
class A:
    pass
class B:
    pass
a = A()
return isinstance(a, B)
]])
      test.expect(result).to.equal(false)
    end)
    test.it("TDD: issubclass", function()
      local result = python.run([[
class Base:
    pass
class Derived(Base):
    pass
return issubclass(Derived, Base)
]])
      test.expect(result).to.equal(true)
    end)
    test.it("TDD: *args in function def", function()
      local result = python.run([[
def f(*args):
    return len(args)
return f(1, 2, 3)
]])
      test.expect(result).to.equal(3)
    end)
    test.it("TDD: **kwargs in function def", function()
      local result = python.run([[
def f(**kwargs):
    return len(kwargs)
return f(a=1, b=2)
]])
      test.expect(result).to.equal(2)
    end)
    test.it("TDD: slice assignment", function()
      local result = python.run([[
items = [1, 2, 3, 4, 5]
items[1:3] = [9, 9]
return items
]])
      local expected = { 1, 9, 9, 4, 5 }
      test.expect(#result).to.equal(#expected)
      for i = 1, #expected do
        test.expect(result[i]).to.equal(expected[i])
      end
    end)
    test.it("TDD: isinstance with builtin int", function()
      local result = python.run("return isinstance(42, int)")
      test.expect(result).to.equal(true)
    end)
    test.it("TDD: isinstance with builtin string", function()
      local result = python.run("return isinstance('hello', str)")
      test.expect(result).to.equal(true)
    end)
    test.it("TDD: f-string basic", function()
      local result = python.run("return f'hello world'")
      test.expect(result).to.equal("hello world")
    end)
    test.it("TDD: f-string with expression", function()
      local code = "name = 'world'\nreturn f'hello {name}'"
      local result = python.run(code)
      test.expect(result).to.equal("hello world")
    end)
    test.it("TDD: f-string with arithmetic", function()
      local result = python.run("return f'{1 + 2}'")
      test.expect(result).to.equal("3")
    end)
    test.it("TDD: f-string with double quotes", function()
      local result = python.run('name = "x"\nreturn f"value {name}"')
      test.expect(result).to.equal("value x")
    end)
    test.it("TDD: f-string with escaped braces", function()
      local result = python.run("return f'{{literal}}'")
      test.expect(result).to.equal("{literal}")
    end)
    test.it("TDD: f-string with multiple expressions", function()
      local code = "a, b = 1, 2\nreturn f'{a} + {b} = {a + b}'"
      local result = python.run(code)
      test.expect(result).to.equal("1 + 2 = 3")
    end)
    test.it("TDD: comment after colon", function()
      local code = "if True: # comment\n    pass\nreturn 42"
      local result = python.run(code)
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: comment after colon with else", function()
      local code = "if False: # comment\n    pass\nelse: # other\n    return 42"
      local result = python.run(code)
      test.expect(result).to.equal(42)
    end)
    test.it("TDD: comment between decorator and def", function()
      local code = [[
def deco(f):
    return lambda: 42
@deco
# a comment
def foo():
    return 0
return foo()
]]
      local result = python.run(code)
      test.expect(result).to.equal(42)
    end)
  end)
end
