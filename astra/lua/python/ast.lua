local ast = {}

local function def(name, constant, fields)
  ast[constant] = name
  if #fields == 0 then
    ast[name] = function()
      return { type = name }
    end
  else
    ast[name] = function(...)
      local args = { ... }
      local node = { type = name }
      for i, f in ipairs(fields) do
        node[f] = args[i]
      end
      return node
    end
  end
end

def("Program", "PROGRAM", { "body" })
def("FunctionDef", "FUNCTION_DEF", { "name", "args", "body", "decorators", "vararg", "kwarg", "defaults" })
def("If", "IF", { "test", "body", "elifs", "or_else" })
def("While", "WHILE", { "test", "body", "or_else" })
def("For", "FOR", { "targets", "iterator", "body", "or_else", "is_range", "range_args" })
def("Try", "TRY", { "body", "handlers", "finally_body" })
def("Return", "RETURN", { "value" })
def("Assign", "ASSIGN", { "targets", "value" })
def("AugAssign", "AUG_ASSIGN", { "target", "op", "value" })
def("ExprStmt", "EXPR_STMT", { "expr" })
def("Global", "GLOBAL", { "names" })
def("Pass", "PASS", {})
def("Break", "BREAK", {})
def("Continue", "CONTINUE", {})
def("Constant", "CONSTANT", { "value" })
def("Name", "NAME", { "id" })
def("BinOp", "BIN_OP", { "left", "op", "right" })
def("UnaryOp", "UNARY_OP", { "op", "operand" })
def("BoolOp", "BOOL_OP", { "op", "values" })
def("Compare", "COMPARE", { "left", "ops", "comparators" })
def("Call", "CALL", { "func", "args", "keywords" })
def("Subscript", "SUBSCRIPT", { "value", "index" })
def("Attribute", "ATTRIBUTE", { "value", "attr" })
def("List", "LIST", { "elements" })
def("Dict", "DICT", { "keys", "values" })
def("Set", "SET", { "elements" })
def("Tuple", "TUPLE", { "elements" })
def("Lambda", "LAMBDA", { "args", "body" })
def("Walrus", "WALRUS", { "target", "value" })
def("IfExpr", "IF_EXPR", { "test", "body", "or_else" })
def("ListComp", "LIST_COMP", { "element", "generators" })
def("SetComp", "SET_COMP", { "element", "generators" })
def("DictComp", "DICT_COMP", { "key", "value", "generators" })
def("Slice", "SLICE", { "lower", "upper", "step" })
def("ClassDef", "CLASS_DEF", { "name", "bases", "body", "decorators" })
def("Starred", "STARRED", { "value", "double_star" })
def("Super", "SUPER", {})

return ast
