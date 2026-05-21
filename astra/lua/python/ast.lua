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

local node_defs = {
  { "Program", "PROGRAM", { "body" } },
  { "FunctionDef", "FUNCTION_DEF", { "name", "args", "body", "decorators", "vararg", "kwarg", "defaults" } },
  { "If", "IF", { "test", "body", "elifs", "or_else" } },
  { "While", "WHILE", { "test", "body", "or_else" } },
  { "For", "FOR", { "targets", "iterator", "body", "or_else", "is_range", "range_args" } },
  { "Try", "TRY", { "body", "handlers", "finally_body" } },
  { "Return", "RETURN", { "value" } },
  { "Assign", "ASSIGN", { "targets", "value" } },
  { "AugAssign", "AUG_ASSIGN", { "target", "op", "value" } },
  { "ExprStmt", "EXPR_STMT", { "expr" } },
  { "Global", "GLOBAL", { "names" } },
  { "Pass", "PASS", {} },
  { "Break", "BREAK", {} },
  { "Continue", "CONTINUE", {} },
  { "Constant", "CONSTANT", { "value" } },
  { "Name", "NAME", { "id" } },
  { "BinOp", "BIN_OP", { "left", "op", "right" } },
  { "UnaryOp", "UNARY_OP", { "op", "operand" } },
  { "BoolOp", "BOOL_OP", { "op", "values" } },
  { "Compare", "COMPARE", { "left", "ops", "comparators" } },
  { "Call", "CALL", { "func", "args", "keywords" } },
  { "Subscript", "SUBSCRIPT", { "value", "index" } },
  { "Attribute", "ATTRIBUTE", { "value", "attr" } },
  { "List", "LIST", { "elements" } },
  { "Dict", "DICT", { "keys", "values" } },
  { "Set", "SET", { "elements" } },
  { "Tuple", "TUPLE", { "elements" } },
  { "Lambda", "LAMBDA", { "args", "body" } },
  { "Walrus", "WALRUS", { "target", "value" } },
  { "IfExpr", "IF_EXPR", { "test", "body", "or_else" } },
  { "ListComp", "LIST_COMP", { "element", "generators" } },
  { "SetComp", "SET_COMP", { "element", "generators" } },
  { "DictComp", "DICT_COMP", { "key", "value", "generators" } },
  { "Slice", "SLICE", { "lower", "upper", "step" } },
  { "ClassDef", "CLASS_DEF", { "name", "bases", "body", "decorators" } },
  { "Starred", "STARRED", { "value", "double_star" } },
  { "Super", "SUPER", {} },
}
for _, def in ipairs(node_defs) do
  define_ast_node(def[1], def[2], def[3])
end

return ast
