local ast = {}

ast.PROGRAM = "Program"
ast.FUNCTION_DEF = "FunctionDef"
ast.IF = "If"
ast.WHILE = "While"
ast.FOR = "For"
ast.TRY = "Try"
ast.RETURN = "Return"
ast.ASSIGN = "Assign"
ast.AUG_ASSIGN = "AugAssign"
ast.EXPR_STMT = "ExprStmt"
ast.GLOBAL = "Global"
ast.PASS = "Pass"
ast.BREAK = "Break"
ast.CONTINUE = "Continue"
ast.CONSTANT = "Constant"
ast.NAME = "Name"
ast.BIN_OP = "BinOp"
ast.UNARY_OP = "UnaryOp"
ast.BOOL_OP = "BoolOp"
ast.COMPARE = "Compare"
ast.CALL = "Call"
ast.SUBSCRIPT = "Subscript"
ast.ATTRIBUTE = "Attribute"
ast.LIST = "List"
ast.DICT = "Dict"
ast.SET = "Set"
ast.TUPLE = "Tuple"
ast.LAMBDA = "Lambda"
ast.WALRUS = "Walrus"
ast.IF_EXPR = "IfExpr"
ast.LIST_COMP = "ListComp"
ast.SET_COMP = "SetComp"
ast.DICT_COMP = "DictComp"
ast.SLICE = "Slice"

function ast.Program(body)
  return { type = ast.PROGRAM, body = body }
end

function ast.FunctionDef(name, args, body)
  return { type = ast.FUNCTION_DEF, name = name, args = args, body = body }
end

function ast.If(test, body, elifs, or_else)
  return { type = ast.IF, test = test, body = body, elifs = elifs or {}, or_else = or_else }
end

function ast.While(test, body, or_else)
  return { type = ast.WHILE, test = test, body = body, or_else = or_else }
end

function ast.For(targets, iterator, body, or_else, is_range, range_args)
  return {
    type = ast.FOR,
    targets = targets,
    iterator = iterator,
    body = body,
    or_else = or_else,
    is_range = is_range or false,
    range_args = range_args or {},
  }
end

function ast.Try(body, handlers, finally_body)
  return { type = ast.TRY, body = body, handlers = handlers or {}, finally_body = finally_body }
end

function ast.Return(value)
  return { type = ast.RETURN, value = value }
end

function ast.Assign(targets, value)
  return { type = ast.ASSIGN, targets = targets, value = value }
end

function ast.AugAssign(target, op, value)
  return { type = ast.AUG_ASSIGN, target = target, op = op, value = value }
end

function ast.ExprStmt(expr)
  return { type = ast.EXPR_STMT, expr = expr }
end

function ast.Global(names)
  return { type = ast.GLOBAL, names = names }
end

function ast.Pass()
  return { type = ast.PASS }
end

function ast.Break()
  return { type = ast.BREAK }
end

function ast.Continue()
  return { type = ast.CONTINUE }
end

function ast.Constant(value)
  return { type = ast.CONSTANT, value = value }
end

function ast.Name(id)
  return { type = ast.NAME, id = id }
end

function ast.BinOp(left, op, right)
  return { type = ast.BIN_OP, left = left, op = op, right = right }
end

function ast.UnaryOp(op, operand)
  return { type = ast.UNARY_OP, op = op, operand = operand }
end

function ast.BoolOp(op, values)
  return { type = ast.BOOL_OP, op = op, values = values }
end

function ast.Compare(left, ops, comparators)
  return { type = ast.COMPARE, left = left, ops = ops, comparators = comparators }
end

function ast.Call(func, args, keywords)
  return { type = ast.CALL, func = func, args = args, keywords = keywords }
end

function ast.Subscript(value, index)
  return { type = ast.SUBSCRIPT, value = value, index = index }
end

function ast.Attribute(value, attr)
  return { type = ast.ATTRIBUTE, value = value, attr = attr }
end

function ast.List(elements)
  return { type = ast.LIST, elements = elements }
end

function ast.Dict(keys, values)
  return { type = ast.DICT, keys = keys, values = values }
end

function ast.Set(elements)
  return { type = ast.SET, elements = elements }
end

function ast.Tuple(elements)
  return { type = ast.TUPLE, elements = elements }
end

function ast.Lambda(args, body)
  return { type = ast.LAMBDA, args = args, body = body }
end

function ast.Walrus(target, value)
  return { type = ast.WALRUS, target = target, value = value }
end

function ast.IfExpr(test, body, or_else)
  return { type = ast.IF_EXPR, test = test, body = body, or_else = or_else }
end

function ast.ListComp(element, generators)
  return { type = ast.LIST_COMP, element = element, generators = generators }
end

function ast.SetComp(element, generators)
  return { type = ast.SET_COMP, element = element, generators = generators }
end

function ast.DictComp(key, value, generators)
  return { type = ast.DICT_COMP, key = key, value = value, generators = generators }
end

function ast.Slice(lower, upper, step)
  return { type = ast.SLICE, lower = lower, upper = upper, step = step }
end

return ast
