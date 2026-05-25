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

---@class ast.Program: {type: string, body: ast_node[]}
---@class ast.FunctionDef: {type: string, name: string, args: string[], body: ast_node[], decorators: ast_node[], vararg: string?, kwarg: string?, defaults: ast_node[]?}
---@class ast.If: {type: string, test: ast_node, body: ast_node[], elifs: {test: ast_node, body: ast_node[]}[], or_else: ast_node[]?}
---@class ast.While: {type: string, test: ast_node, body: ast_node[], or_else: ast_node[]?}
---@class ast.For: {type: string, targets: string[], iterator: ast_node?, body: ast_node[], or_else: ast_node[]?, is_range: boolean, range_args: ast_node[]}
---@class ast.Try: {type: string, body: ast_node[], handlers: {type: ast_node?, name: string?, body: ast_node[]}[], finally_body: ast_node[]?, or_else: ast_node[]?}
---@class ast.Return: {type: string, value: ast_node?}
---@class ast.Assign: {type: string, targets: ast_node[], value: ast_node}
---@class ast.AugAssign: {type: string, target: ast_node, op: string, value: ast_node}
---@class ast.ExprStmt: {type: string, expr: ast_node}
---@class ast.Global: {type: string, names: string[]}
---@class ast.Pass: {type: string}
---@class ast.Break: {type: string}
---@class ast.Continue: {type: string}
---@class ast.Constant: {type: string, value: any}
---@class ast.Name: {type: string, id: string}
---@class ast.BinOp: {type: string, left: ast_node, op: string, right: ast_node}
---@class ast.UnaryOp: {type: string, op: string, operand: ast_node}
---@class ast.BoolOp: {type: string, op: string, values: ast_node[]}
---@class ast.Compare: {type: string, left: ast_node, ops: string[], comparators: ast_node[]}
---@class ast.Call: {type: string, func: ast_node, args: ast_node[], keywords?: {arg:string, value:ast_node}[], _resolved_params?: string[], [any]: any}
---@class ast.Subscript: {type: string, value: ast_node, index: ast_node}
---@class ast.Attribute: {type: string, value: ast_node, attr: string}
---@class ast.List: {type: string, elements: ast_node[]}
---@class ast.Dict: {type: string, keys: ast_node[], values: ast_node[]}
---@class ast.Set: {type: string, elements: ast_node[]}
---@class ast.Tuple: {type: string, elements: ast_node[]}
---@class ast.Lambda: {type: string, args: string[], body: ast_node, has_vararg?: boolean}
---@class ast.Walrus: {type: string, target: ast_node, value: ast_node}
---@class ast.IfExpr: {type: string, test: ast_node, body: ast_node, or_else: ast_node}
---@class ast.ListComp: {type: string, element: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.SetComp: {type: string, element: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.DictComp: {type: string, key: ast_node, value: ast_node, generators: {target:string, iterator:ast_node, ifs:ast_node[]}[]}
---@class ast.Slice: {type: string, lower: ast_node?, upper: ast_node?, step: ast_node?}
---@class ast.ClassDef: {type: string, name: string, bases: ast_node[], body: ast_node[], decorators: ast_node[]}
---@class ast.Starred: {type: string, value: ast_node, double_star?: boolean}
---@class ast.Super: {type: string}
---@class ast.Comment: {type: string, value: string}
---@class ast.Import: {type: string, names: {name:string, as_name:string?}[]}
---@class ast.JoinedStr: {type: string, values: ast_node[]}
---@class ast.FormattedValue: {type: string, value: ast_node, conversion: string?, format_spec: ast_node?}
---@class ast.Raise: {type: string, exc: ast_node?, cause: ast_node?}
---@class ast.Assert: {type: string, test: ast_node, message: ast_node?}
---@class ast.Del: {type: string, target: ast_node}
---@class ast.Nonlocal: {type: string, names: string[]}
---@class ast.Await: {type: string, value: ast_node}
---@class ast.AsyncFunctionDef: {type: string, name: string, args: string[], body: ast_node[], decorators: ast_node[], vararg: string?, kwarg: string?, defaults: ast_node[]?}
---@class ast.With: {type: string, items: {context_expr: ast_node, optional_vars: ast_node?}[], body: ast_node[]}
---@class ast.Yield: {type: string, value: ast_node?}
---@class ast.ImportFrom: {type: string, module: string, names: {name:string, as_name:string?}[]}

---@alias ast_node
---| ast.Program | ast.FunctionDef | ast.If | ast.While | ast.For | ast.Try
---| ast.Return | ast.Assign | ast.AugAssign | ast.ExprStmt | ast.Global
---| ast.Pass | ast.Break | ast.Continue | ast.Constant | ast.Name
---| ast.BinOp | ast.UnaryOp | ast.BoolOp | ast.Compare | ast.Call
---| ast.Subscript | ast.Attribute | ast.List | ast.Dict | ast.Set
---| ast.Tuple | ast.Lambda | ast.Walrus | ast.IfExpr | ast.ListComp
---| ast.SetComp | ast.DictComp | ast.Slice | ast.ClassDef | ast.Starred | ast.Super
---| ast.Comment | ast.Import | ast.ImportFrom | ast.Raise | ast.Assert | ast.Del
---| ast.Nonlocal | ast.Await | ast.AsyncFunctionDef | ast.With | ast.Yield

local node_defs = {
  { "Program", "PROGRAM", { "body" } },
  { "FunctionDef", "FUNCTION_DEF", { "name", "args", "body", "decorators", "vararg", "kwarg", "defaults" } },
  { "If", "IF", { "test", "body", "elifs", "or_else" } },
  { "While", "WHILE", { "test", "body", "or_else" } },
  { "For", "FOR", { "targets", "iterator", "body", "or_else", "is_range", "range_args" } },
  { "Try", "TRY", { "body", "handlers", "finally_body", "or_else" } },
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
  { "JoinedStr", "JOINED_STR", { "values" } },
  { "FormattedValue", "FORMATTED_VALUE", { "value", "conversion", "format_spec" } },
  { "Comment", "COMMENT", { "value" } },
  { "Import", "IMPORT", { "names" } },
  { "ImportFrom", "IMPORT_FROM", { "module", "names" } },
  { "Raise", "RAISE", { "exc", "cause" } },
  { "Assert", "ASSERT", { "test", "message" } },
  { "Del", "DEL", { "target" } },
  { "Nonlocal", "NONLOCAL", { "names" } },
  { "Await", "AWAIT", { "value" } },
  { "AsyncFunctionDef", "ASYNC_FUNCTION_DEF", { "name", "args", "body", "decorators", "vararg", "kwarg", "defaults" } },
  { "With", "WITH", { "items", "body" } },
  { "Yield", "YIELD", { "value" } },
}
for _, def in ipairs(node_defs) do
  define_ast_node(def[1], def[2], def[3])
end

return ast
