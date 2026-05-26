local ast = require("python.ast")
local parser = require("python.parser")
local tokenizer = require("python.tokenizer")

local function parse(src)
  return parser.parse(tokenizer.tokenize(src))
end

return function(test)
  test.it("Program contains body", function()
    local p = parse("pass")
    test.expect(p.type).to.equal(ast.PROGRAM)
    test.expect(#p.body).to.equal(1)
    test.expect(p.body[1].type).to.equal(ast.PASS)
  end)

  test.it("Constant AST values", function()
    local p = parse("42")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.CONSTANT)
    test.expect(e.value).to.equal(42)
  end)

  test.it("Name AST for identifiers", function()
    local p = parse("x")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.NAME)
    test.expect(e.id).to.equal("x")
  end)

  test.it("BinOp AST structure", function()
    local p = parse("1 + 2")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.BIN_OP)
    test.expect(e.op).to.equal("+")
    test.expect(e.left.value).to.equal(1)
    test.expect(e.right.value).to.equal(2)
  end)

  test.it("UnaryOp AST structure", function()
    local p = parse("-x")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.UNARY_OP)
    test.expect(e.op).to.equal("-")
    test.expect(e.operand.id).to.equal("x")
  end)

  test.it("BoolOp AST structure", function()
    local p = parse("x and y")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.BOOL_OP)
    test.expect(e.op).to.equal("and")
    test.expect(#e.values).to.equal(2)
  end)

  test.it("Compare AST structure", function()
    local p = parse("x < y")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.COMPARE)
    test.expect(e.ops[1]).to.equal("<")
    test.expect(e.left.id).to.equal("x")
    test.expect(e.comparators[1].id).to.equal("y")
  end)

  test.it("Chained compare AST", function()
    local p = parse("1 < x < 10")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.COMPARE)
    test.expect(#e.ops).to.equal(2)
    test.expect(#e.comparators).to.equal(2)
  end)

  test.it("Call AST structure", function()
    local p = parse("f(1, 2)")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.CALL)
    test.expect(e.func.id).to.equal("f")
    test.expect(#e.args).to.equal(2)
  end)

  test.it("Attribute AST structure", function()
    local p = parse("x.y")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.ATTRIBUTE)
    test.expect(e.value.id).to.equal("x")
    test.expect(e.attr).to.equal("y")
  end)

  test.it("Subscript AST structure", function()
    local p = parse("a[0]")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.SUBSCRIPT)
    test.expect(e.value.id).to.equal("a")
    test.expect(e.index.value).to.equal(0)
  end)

  test.it("Slice AST structure", function()
    local p = parse("a[1:3]")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.SUBSCRIPT)
    test.expect(e.index.type).to.equal(ast.SLICE)
    test.expect(e.index.lower.value).to.equal(1)
    test.expect(e.index.upper.value).to.equal(3)
  end)

  test.it("List AST structure", function()
    local p = parse("[1, 2, 3]")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.LIST)
    test.expect(#e.elements).to.equal(3)
  end)

  test.it("Dict AST structure", function()
    local p = parse('{"a": 1}')
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.DICT)
    test.expect(#e.keys).to.equal(1)
  end)

  test.it("If statement AST", function()
    local p = parse("if x:\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.IF)
    test.expect(s.test.id).to.equal("x")
    test.expect(#s.body).to.equal(1)
  end)

  test.it("FunctionDef AST", function()
    local p = parse("def f(a, b):\n    return a")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.FUNCTION_DEF)
    test.expect(s.name).to.equal("f")
    test.expect(#s.args).to.equal(2)
  end)

  test.it("While AST", function()
    local p = parse("while x:\n    break")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.WHILE)
    test.expect(s.test.id).to.equal("x")
  end)

  test.it("For AST with range", function()
    local p = parse("for i in range(10):\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.FOR)
    test.expect(s.is_range).to.equal(true)
  end)

  test.it("ListComp AST", function()
    local p = parse("[x for x in y]")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.LIST_COMP)
    test.expect(e.element.id).to.equal("x")
    test.expect(#e.generators).to.equal(1)
  end)

  test.it("Lambda AST", function()
    local p = parse("lambda x: x + 1")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.LAMBDA)
    test.expect(#e.args).to.equal(1)
  end)

  test.it("Walrus AST", function()
    local p = parse("(x := 1)")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.WALRUS)
    test.expect(e.target.id).to.equal("x")
    test.expect(e.value.value).to.equal(1)
  end)

  test.it("IfExpr AST", function()
    local p = parse("x if True else y")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.IF_EXPR)
    test.expect(e.body.id).to.equal("x")
    test.expect(e.or_else.id).to.equal("y")
  end)

  test.it("ClassDef AST", function()
    local p = parse("class X:\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.CLASS_DEF)
    test.expect(s.name).to.equal("X")
  end)

  test.it("ClassDef with bases", function()
    local p = parse("class X(Base):\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.CLASS_DEF)
    test.expect(s.name).to.equal("X")
    test.expect(#s.bases).to.equal(1)
  end)

  test.it("Super AST", function()
    local p = parse("super()")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.CALL)
    test.expect(e.func.type).to.equal(ast.SUPER)
  end)

  test.it("Starred AST in call", function()
    local p = parse("f(*args)")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.CALL)
    test.expect(e.args[1].type).to.equal(ast.STARRED)
  end)

  test.it("Try AST with bare except", function()
    local p = parse("try:\n    pass\nexcept:\n    pass\nfinally:\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.TRY)
    test.expect(#s.body).to.equal(1)
    test.expect(#s.handlers).to.equal(1)
    test.expect(s.handlers[1].type).to.equal(nil)
    test.expect(s.handlers[1].name).to.equal(nil)
    test.expect(#s.handlers[1].body).to.equal(1)
    test.expect(s.finally_body ~= nil).to.equal(true)
  end)

  test.it("Try AST with typed except and else", function()
    local p = parse("try:\n    pass\nexcept ValueError as e:\n    pass\nelse:\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.TRY)
    test.expect(s.handlers[1].type.type).to.equal(ast.NAME)
    test.expect(s.handlers[1].type.id).to.equal("ValueError")
    test.expect(s.handlers[1].name).to.equal("e")
    test.expect(s.or_else ~= nil).to.equal(true)
  end)

  test.it("Raise AST", function()
    local p = parse("raise ValueError(\"msg\")")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.RAISE)
    test.expect(s.exc.type).to.equal(ast.CALL)
  end)

  test.it("Raise AST with cause", function()
    local p = parse("raise X from Y")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.RAISE)
    test.expect(s.exc.id).to.equal("X")
    test.expect(s.cause ~= nil).to.equal(true)
    test.expect(s.cause.id).to.equal("Y")
  end)

  test.it("Assert AST", function()
    local p = parse("assert x > 0")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.ASSERT)
    test.expect(s.test.type).to.equal(ast.COMPARE)
    test.expect(s.message).to.equal(nil)
  end)

  test.it("Assert AST with message", function()
    local p = parse('assert x > 0, "bad"')
    local s = p.body[1]
    test.expect(s.message.type).to.equal(ast.CONSTANT)
    test.expect(s.message.value).to.equal("bad")
  end)

  test.it("Del AST name", function()
    local p = parse("del x")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.DEL)
    test.expect(s.target.type).to.equal(ast.NAME)
    test.expect(s.target.id).to.equal("x")
  end)

  test.it("Nonlocal AST", function()
    local p = parse("def f():\n    nonlocal x")
    local s = p.body[1].body[1]
    test.expect(s.type).to.equal(ast.NONLOCAL)
    test.expect(s.names[1]).to.equal("x")
  end)

  test.it("With AST", function()
    local p = parse("with x as y:\n    pass")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.WITH)
    test.expect(#s.items).to.equal(1)
    test.expect(s.items[1].context_expr.id).to.equal("x")
    test.expect(s.items[1].optional_vars.id).to.equal("y")
  end)

  test.it("Yield AST in function", function()
    local p = parse("def g():\n    yield 42")
    local s = p.body[1].body[1]
    test.expect(s.type).to.equal(ast.YIELD)
    test.expect(s.value.value).to.equal(42)
  end)

  test.it("Await AST", function()
    local p = parse("def f():\n    x = await y")
    local s = p.body[1].body[1]
    test.expect(s.value.type).to.equal(ast.AWAIT)
    test.expect(s.value.value.id).to.equal("y")
  end)

  test.it("Import AST", function()
    local p = parse("import os")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.IMPORT)
    test.expect(s.names[1].name).to.equal("os")
  end)

  test.it("ImportFrom AST", function()
    local p = parse("from os import path")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.IMPORT_FROM)
    test.expect(s.module).to.equal("os")
    test.expect(s.names[1].name).to.equal("path")
  end)

  test.it("Set AST", function()
    local p = parse("{1, 2, 3}")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.SET)
    test.expect(#e.elements).to.equal(3)
  end)

  test.it("Tuple AST", function()
    local p = parse("(1, 2)")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.TUPLE)
    test.expect(#e.elements).to.equal(2)
  end)

  test.it("SetComp AST", function()
    local p = parse("{x for x in y}")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.SET_COMP)
    test.expect(e.element.id).to.equal("x")
  end)

  test.it("DictComp AST", function()
    local p = parse("{k: v for k in items}")
    local e = p.body[1].expr
    test.expect(e.type).to.equal(ast.DICT_COMP)
  end)

  test.it("Comment AST", function()
    local p = parse("# hello\npass")
    test.expect(p.body[1].type).to.equal(ast.COMMENT)
    test.expect(p.body[1].value).to.equal(" hello")
  end)

  test.it("Global AST", function()
    local p = parse("def f():\n    global x")
    local s = p.body[1].body[1]
    test.expect(s.type).to.equal(ast.GLOBAL)
    test.expect(s.names[1]).to.equal("x")
  end)

  test.it("AsyncFunctionDef AST", function()
    local p = parse("async def fetch():\n    return 42")
    local s = p.body[1]
    test.expect(s.type).to.equal(ast.ASYNC_FUNCTION_DEF)
    test.expect(s.name).to.equal("fetch")
  end)
end
