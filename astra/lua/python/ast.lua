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

---@class ast.Program: {type: integer, body: ast_node[]}
---@class ast.FunctionDef: {type: integer, name: string, args: string[], body: ast_node[], decorators: ast_node[], vararg: string?, kwarg: string?, defaults: ast_node[]?}
---@class ast.If: {type: integer, test: ast_node, body: ast_node[], elifs: {test: ast_node, body: ast_node[]}[], or_else: ast_node[]?}
---@class ast.While: {type: integer, test: ast_node, body: ast_node[], or_else: ast_node[]?}
---@class ast.For: {type: integer, targets: string[], iterator: ast_node?, body: ast_node[], or_else: ast_node[]?, is_range: boolean, range_args: ast_node[]}
---@class ast.Try: {type: integer, body: ast_node[], handlers: {type: ast_node?, name: string?, body: ast_node[]}[], finally_body: ast_node[]?}
---@class ast.Return: {type: integer, value: ast_node?}
---@class ast.Assign: {type: integer, targets: ast_node[], value: ast_node}
---@class ast.AugAssign: {type: integer, target: ast_node, op: string, value: ast_node}
---@class ast.ExprStmt: {type: integer, expr: ast_node}
---@class ast.Global: {type: integer, names: string[]}
---@class ast.Pass: {type: integer}
---@class ast.Break: {type: integer}
---@class ast.Continue: {type: integer}
---@class ast.Constant: {type: integer, value: any}
---@class ast.Name: {type: integer, id: string}
---@class ast.BinOp: {type: integer, left: ast_node, op: string, right: ast_node}
---@class ast.UnaryOp: {type: integer, op: string, operand: ast_node}
---@class ast.BoolOp: {type: integer, op: string, values: ast_node[]}
---@class ast.Compare: {type: integer, left: ast_node, ops: string[], comparators: ast_node[]}
---@class ast.Call: {type: integer, func: ast_node, args: ast_node[], keywords?: {arg:string, value:ast_node}[], _resolved_params?: string[], [any]: any}
---@class ast.Subscript: {type: integer, value: ast_node, index: ast_node}
---@class ast.Attribute: {type: integer, value: ast_node, attr: string}
---@class ast.List: {type: integer, elements: ast_node[]}
---@class ast.Dict: {type: integer, keys: ast_node[], values: ast_node[]}
---@class ast.Set: {type: integer, elements: ast_node[]}
---@class ast.Tuple: {type: integer, elements: ast_node[]}
---@class ast.Lambda: {type: integer, args: string[], body: ast_node, has_vararg?: boolean}
---@class ast.Walrus: {type: integer, target: ast_node, value: ast_node}
---@class ast.IfExpr: {type: integer, test: ast_node, body: ast_node, or_else: ast_node}
---@class ast.ListComp: {type: integer, element: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.SetComp: {type: integer, element: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.DictComp: {type: integer, key: ast_node, value: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.Slice: {type: integer, lower: ast_node?, upper: ast_node?, step: ast_node?}
---@class ast.ClassDef: {type: integer, name: string, bases: ast_node[], body: ast_node[], decorators: ast_node[]}
---@class ast.Starred: {type: integer, value: ast_node, double_star?: boolean}
---@class ast.Super: {type: integer}
---@class ast.Comment: {type: integer, value: string}
---@class ast.Import: {type: integer, names: {name:string, as_name:string?}[]}
---@class ast.ImportFrom: {type: integer, module: string, names: {name:string, as_name:string?}[]}

---@alias ast_node
---| ast.Program | ast.FunctionDef | ast.If | ast.While | ast.For | ast.Try
---| ast.Return | ast.Assign | ast.AugAssign | ast.ExprStmt | ast.Global
---| ast.Pass | ast.Break | ast.Continue | ast.Constant | ast.Name
---| ast.BinOp | ast.UnaryOp | ast.BoolOp | ast.Compare | ast.Call
---| ast.Subscript | ast.Attribute | ast.List | ast.Dict | ast.Set
---| ast.Tuple | ast.Lambda | ast.Walrus | ast.IfExpr | ast.ListComp
---| ast.SetComp | ast.DictComp | ast.Slice | ast.ClassDef | ast.Starred | ast.Super
---| ast.Comment | ast.Import | ast.ImportFrom

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
  { "Comment", "COMMENT", { "value" } },
  { "Import", "IMPORT", { "names" } },
  { "ImportFrom", "IMPORT_FROM", { "module", "names" } },
}
for _, def in ipairs(node_defs) do
  define_ast_node(def[1], def[2], def[3])
end

return ast
