local ast = {}

-- Registers a node type: creates both a number constant (e.g. ast.PROGRAM)
-- and a constructor function (e.g. ast.Program(body)) with named fields.
local function define_ast_node(name, constant, fields)
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

define_ast_node("Program", "PROGRAM", { "body" })
define_ast_node("FunctionDef", "FUNCTION_DEF", { "name", "args", "body", "decorators", "vararg", "kwarg", "defaults" })
define_ast_node("If", "IF", { "test", "body", "elifs", "or_else" })
define_ast_node("While", "WHILE", { "test", "body", "or_else" })
define_ast_node("For", "FOR", { "targets", "iterator", "body", "or_else", "is_range", "range_args" })
define_ast_node("Try", "TRY", { "body", "handlers", "finally_body" })
define_ast_node("Return", "RETURN", { "value" })
define_ast_node("Assign", "ASSIGN", { "targets", "value" })
define_ast_node("AugAssign", "AUG_ASSIGN", { "target", "op", "value" })
define_ast_node("ExprStmt", "EXPR_STMT", { "expr" })
define_ast_node("Global", "GLOBAL", { "names" })
define_ast_node("Pass", "PASS", {})
define_ast_node("Break", "BREAK", {})
define_ast_node("Continue", "CONTINUE", {})
define_ast_node("Constant", "CONSTANT", { "value" })
define_ast_node("Name", "NAME", { "id" })
define_ast_node("BinOp", "BIN_OP", { "left", "op", "right" })
define_ast_node("UnaryOp", "UNARY_OP", { "op", "operand" })
define_ast_node("BoolOp", "BOOL_OP", { "op", "values" })
define_ast_node("Compare", "COMPARE", { "left", "ops", "comparators" })
define_ast_node("Call", "CALL", { "func", "args", "keywords" })
define_ast_node("Subscript", "SUBSCRIPT", { "value", "index" })
define_ast_node("Attribute", "ATTRIBUTE", { "value", "attr" })
define_ast_node("List", "LIST", { "elements" })
define_ast_node("Dict", "DICT", { "keys", "values" })
define_ast_node("Set", "SET", { "elements" })
define_ast_node("Tuple", "TUPLE", { "elements" })
define_ast_node("Lambda", "LAMBDA", { "args", "body" })
define_ast_node("Walrus", "WALRUS", { "target", "value" })
define_ast_node("IfExpr", "IF_EXPR", { "test", "body", "or_else" })
define_ast_node("ListComp", "LIST_COMP", { "element", "generators" })
define_ast_node("SetComp", "SET_COMP", { "element", "generators" })
define_ast_node("DictComp", "DICT_COMP", { "key", "value", "generators" })
define_ast_node("Slice", "SLICE", { "lower", "upper", "step" })
define_ast_node("ClassDef", "CLASS_DEF", { "name", "bases", "body", "decorators" })
define_ast_node("Starred", "STARRED", { "value", "double_star" })
define_ast_node("Super", "SUPER", {})

return ast
