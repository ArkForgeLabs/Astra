-- Python-to-Lua transpiler for Astra

local validation = require("validation")
local regex = validation.regex

-- ============================================================
-- Lexer / Tokenizer
-- ============================================================

local keywords = {
    ["def"] = true, ["if"] = true, ["elif"] = true, ["else"] = true,
    ["while"] = true, ["for"] = true, ["in"] = true, ["return"] = true,
    ["and"] = true, ["or"] = true, ["not"] = true, ["is"] = true,
    ["pass"] = true, ["break"] = true, ["continue"] = true,
    ["None"] = true, ["True"] = true, ["False"] = true,
}

local function tokenize(source)
    local tokens = {}
    local line = 1
    local col = 1
    local i = 1
    local n = #source
    local indent_stack = {0}
    local at_line_start = true
    local paren_depth = 0

    local function emit(kind, value)
        tokens[#tokens + 1] = {kind = kind, value = value or kind, line = line, col = col}
    end

    while i <= n do
        local ch = source:sub(i, i)

        -- Handle newlines
        if ch == '\n' then
            emit("NEWLINE", '\n')
            line = line + 1
            col = 1
            i = i + 1
            at_line_start = true
            paren_depth = 0

        -- Handle line-start: indent tracking
        elseif at_line_start then
            if ch == ' ' or ch == '\t' then
                local indent_count = 0
                local indent_char = ch
                while i <= n do
                    local c = source:sub(i, i)
                    if c == ' ' or c == '\t' then
                        if c ~= indent_char then
                            indent_count = indent_count + (c == '\t' and 4 or 1)
                        else
                            indent_count = indent_count + 1
                        end
                        i = i + 1
                        col = col + 1
                    else
                        break
                    end
                end

                local current = indent_stack[#indent_stack]
                -- Skip indent tracking for whitespace-only (blank) lines
                local next_ch = i <= n and source:sub(i, i) or ''
                if next_ch ~= '\n' and next_ch ~= '' then
                    if indent_count > current then
                        emit("INDENT")
                        indent_stack[#indent_stack + 1] = indent_count
                    elseif indent_count < current then
                        while #indent_stack > 1 and indent_stack[#indent_stack] > indent_count do
                            emit("DEDENT")
                            indent_stack[#indent_stack] = nil
                        end
                    end
                end
                at_line_start = false
            else
                -- Non-whitespace line start: close all open blocks
                while #indent_stack > 1 do
                    emit("DEDENT")
                    indent_stack[#indent_stack] = nil
                end
                at_line_start = false
                -- Fall through to process the character
            end

        -- Handle comments
        elseif ch == '#' then
            while i <= n and source:sub(i, i) ~= '\n' do
                i = i + 1
                col = col + 1
            end

        -- Handle strings
        elseif ch == '\"' or ch == "'" then
            local quote = ch
            local start_i = i
            i = i + 1
            col = col + 1
            -- Check for triple quotes
            if source:sub(i, i + 1) == quote .. quote then
                i = i + 2
                col = col + 2
                while i <= n do
                    if source:sub(i, i + 2) == quote .. quote .. quote then
                        i = i + 3
                        col = col + 3
                        break
                    end
                    if source:sub(i, i) == '\n' then
                        line = line + 1
                        col = 1
                    else
                        col = col + 1
                    end
                    i = i + 1
                end
                local s = source:sub(start_i, i - 1)
                emit("STRING", s)
            else
                while i <= n do
                    local c = source:sub(i, i)
                    if c == '\\' then
                        i = i + 2
                        col = col + 2
                    elseif c == quote then
                        i = i + 1
                        col = col + 1
                        break
                    else
                        i = i + 1
                        col = col + 1
                    end
                end
                local s = source:sub(start_i, i - 1)
                emit("STRING", s)
            end

        -- Handle digits (numbers)
        elseif ch >= '0' and ch <= '9' then
            local start_i = i
            local is_float = false
            i = i + 1
            col = col + 1
            while i <= n do
                local c = source:sub(i, i)
                if c >= '0' and c <= '9' then
                    i = i + 1
                    col = col + 1
                elseif c == '.' then
                    is_float = true
                    i = i + 1
                    col = col + 1
                elseif c == 'e' or c == 'E' then
                    is_float = true
                    i = i + 1
                    col = col + 1
                    if source:sub(i, i) == '+' or source:sub(i, i) == '-' then
                        i = i + 1
                        col = col + 1
                    end
                else
                    break
                end
            end
            local num_str = source:sub(start_i, i - 1)
            if is_float then
                emit("FLOAT", num_str)
            else
                emit("INTEGER", num_str)
            end

        -- Handle identifiers and keywords
        elseif (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_' then
            local start_i = i
            i = i + 1
            col = col + 1
            while i <= n do
                local c = source:sub(i, i)
                if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' then
                    i = i + 1
                    col = col + 1
                else
                    break
                end
            end
            local word = source:sub(start_i, i - 1)
            if keywords[word] then
                emit(word:upper(), word)
            else
                emit("IDENTIFIER", word)
            end

        -- Handle operators and delimiters
        else
            -- Try multi-char operators
            local two_ch = i + 1 <= n and source:sub(i, i + 1) or ''
            local three_ch = i + 2 <= n and source:sub(i, i + 2) or ''
            local op_map = {
                ["=="] = "EQEQ", ["!="] = "NOTEQ",
                ["<="] = "LESSEQ", [">="] = "GREATEREQ",
                ["//"] = "DOUBLESLASH", ["**"] = "DOUBLESTAR",
                ["+="] = "PLUSEQ", ["-="] = "MINUSEQ",
                ["*="] = "STAREQ", ["/="] = "SLASHEQ",
                ["%="] = "PERCENTEQ",
            }
            local single_map = {
                ["+"] = "PLUS", ["-"] = "MINUS", ["*"] = "STAR", ["/"] = "SLASH",
                ["%"] = "PERCENT", ["="] = "EQ",
                ["("] = "LPAREN", [")"] = "RPAREN",
                ["["] = "LBRACKET", ["]"] = "RBRACKET",
                ["{"] = "LBRACE", ["}"] = "RBRACE",
                [":"] = "COLON", [","] = "COMMA", ["."] = "DOT", [";"] = "SEMI",
            }
            -- Also handle single-char comparisons
            local comp_map = {["<"] = "LESS", [">"] = "GREATER"}

            if op_map[three_ch] then
                emit(op_map[three_ch], three_ch)
                i = i + 3
                col = col + 3
            elseif op_map[two_ch] then
                emit(op_map[two_ch], two_ch)
                i = i + 2
                col = col + 2
            elseif comp_map[ch] then
                emit(comp_map[ch], ch)
                i = i + 1
                col = col + 1
            elseif single_map[ch] then
                emit(single_map[ch], ch)
                i = i + 1
                col = col + 1
            elseif ch == ' ' or ch == '\t' or ch == '\r' then
                -- Skip whitespace within lines
                i = i + 1
                col = col + 1
            else
                error("syntax error at line " .. line .. " col " .. col .. ": unexpected character " .. ch)
            end
        end
    end

    -- Emit final DEDENTs to close all open blocks
    while #indent_stack > 1 do
        emit("DEDENT")
        indent_stack[#indent_stack] = nil
    end
    emit("EOF")

    return tokens
end


-- ============================================================
-- Parser
-- ============================================================

local function parse(tokens)
    local pos = 1

    local function peek()
        return tokens[pos]
    end

    local function advance()
        local t = tokens[pos]
        pos = pos + 1
        return t
    end

    local function expect(kind)
        local t = peek()
        if not t or t.kind ~= kind then
            error("expected " .. kind .. " got " .. (t and t.kind or "EOF") .. " at line " .. (t and t.line or "?") .. " col " .. (t and t.col or "?"))
        end
        return advance()
    end

    local function match(kind)
        local t = peek()
        if t and t.kind == kind then
            advance()
            return true
        end
        return false
    end

    -- Pre-declare all parser functions for Lua 5.1 compat
    local parse_program, parse_stmt, parse_simple_stmt
    local parse_func_def, parse_if, parse_while, parse_for, parse_return, parse_block_body
    local parse_expr, parse_or, parse_and, parse_not, parse_comparison
    local parse_term, parse_factor, parse_unary, parse_power, parse_primary, parse_atom
    local unescape_string

    -- Parse a program (sequence of statements)
    parse_program = function()
        local body = {}
        while peek() and peek().kind ~= "EOF" and peek().kind ~= "DEDENT" do
            local stmts = parse_stmt()
            if stmts then
                for _, s in ipairs(stmts) do
                    body[#body + 1] = s
                end
            end
            -- Skip NEWLINEs between statements
            while peek() and peek().kind == "NEWLINE" do
                advance()
            end
            -- Handle DEDENT (end of block)
            if peek() and peek().kind == "DEDENT" then
                break
            end
        end
        return {type = "Program", body = body}
    end

    -- Parse a single statement or compound statement
    parse_stmt = function()
        local t = peek()
        if not t then return nil end

        if t.kind == "DEF" then
            return {parse_func_def()}
        elseif t.kind == "IF" then
            return {parse_if()}
        elseif t.kind == "WHILE" then
            return {parse_while()}
        elseif t.kind == "FOR" then
            return {parse_for()}
        elseif t.kind == "RETURN" then
            return {parse_return()}
        elseif t.kind == "PASS" then
            advance()
            return {{type = "Pass"}}
        elseif t.kind == "BREAK" then
            advance()
            return {{type = "Break"}}
        elseif t.kind == "CONTINUE" then
            advance()
            return {{type = "Continue"}}
        else
            return {parse_simple_stmt()}
        end
    end

    -- Parse simple statement (assignment or expression)
    parse_simple_stmt = function()
        local expr = parse_expr()

        -- Check for assignment
        if match("EQ") then
            local value = parse_expr()
            return {type = "Assign", targets = {expr}, value = value}
        elseif match("PLUSEQ") then
            return {type = "AugAssign", target = expr, op = "+", value = parse_expr()}
        elseif match("MINUSEQ") then
            return {type = "AugAssign", target = expr, op = "-", value = parse_expr()}
        elseif match("STAREQ") then
            return {type = "AugAssign", target = expr, op = "*", value = parse_expr()}
        elseif match("SLASHEQ") then
            return {type = "AugAssign", target = expr, op = "/", value = parse_expr()}
        elseif match("PERCENTEQ") then
            return {type = "AugAssign", target = expr, op = "%", value = parse_expr()}
        else
            return {type = "ExprStmt", expr = expr}
        end
    end

    -- Parse function definition
    parse_func_def = function()
        advance() -- consume 'def'
        local name = expect("IDENTIFIER")
        expect("LPAREN")
        local args = {}
        if peek() and peek().kind ~= "RPAREN" then
            args[#args + 1] = expect("IDENTIFIER").value
            while match("COMMA") do
                args[#args + 1] = expect("IDENTIFIER").value
            end
        end
        expect("RPAREN")
        expect("COLON")
        -- Skip NEWLINE before block
        if peek() and peek().kind == "NEWLINE" then advance() end
        -- Parse body (handles INDENT)
        local body = parse_block_body()
        return {type = "FunctionDef", name = name.value, args = args, body = body}
    end

    -- Parse if statement
    parse_if = function()
        advance() -- consume 'if'
        local test = parse_expr()
        expect("COLON")
        if peek() and peek().kind == "NEWLINE" then advance() end
        local body = parse_block_body()
        local elifs = {}
        local orelse = nil

        while peek() and peek().kind == "ELIF" do
            advance()
            local etest = parse_expr()
            expect("COLON")
            if peek() and peek().kind == "NEWLINE" then advance() end
            local ebody = parse_block_body()
            elifs[#elifs + 1] = {test = etest, body = ebody}
        end

        if peek() and peek().kind == "ELSE" then
            advance()
            expect("COLON")
            if peek() and peek().kind == "NEWLINE" then advance() end
            orelse = parse_block_body()
        end

        return {type = "If", test = test, body = body, elifs = elifs, orelse = orelse}
    end

    -- Parse while statement
    parse_while = function()
        advance() -- consume 'while'
        local test = parse_expr()
        expect("COLON")
        if peek() and peek().kind == "NEWLINE" then advance() end
        local body = parse_block_body()
        return {type = "While", test = test, body = body}
    end

    -- Parse for statement (including range detection)
    parse_for = function()
        advance() -- consume 'for'
        local target = expect("IDENTIFIER").value
        expect("IN")

        -- Try to detect range() call
        local iter = nil
        local is_range = false
        local range_args = {}

        if peek() and peek().kind == "IDENTIFIER" and peek().value == "range" then
            advance() -- consume 'range'
            if peek() and peek().kind == "LPAREN" then
                advance()
                is_range = true
                range_args[1] = parse_expr()
                while match("COMMA") do
                    range_args[#range_args + 1] = parse_expr()
                end
                expect("RPAREN")
            end
        else
            iter = parse_atom()
            -- Handle subscript, call, attribute chains
            while true do
                if peek() and peek().kind == "LBRACKET" then
                    advance()
                    local idx = parse_expr()
                    expect("RBRACKET")
                    iter = {type = "Subscript", value = iter, index = idx}
                elseif peek() and peek().kind == "LPAREN" then
                    advance()
                    local args = {}
                    if peek() and peek().kind ~= "RPAREN" then
                        args[#args + 1] = parse_expr()
                        while match("COMMA") do
                            args[#args + 1] = parse_expr()
                        end
                    end
                    expect("RPAREN")
                    iter = {type = "Call", func = iter, args = args}
                elseif peek() and peek().kind == "DOT" then
                    advance()
                    local attr = expect("IDENTIFIER")
                    iter = {type = "Attribute", value = iter, attr = attr.value}
                else
                    break
                end
            end
        end

        expect("COLON")
        if peek() and peek().kind == "NEWLINE" then advance() end
        local body = parse_block_body()

        return {type = "For", target = target, iter = iter, body = body, is_range = is_range, range_args = range_args}
    end

    -- Parse return statement
    parse_return = function()
        advance()
        if peek() and peek().kind ~= "NEWLINE" and peek().kind ~= "DEDENT" and peek().kind ~= "EOF" then
            return {type = "Return", value = parse_expr()}
        else
            return {type = "Return", value = nil}
        end
    end

    -- Parse block body (statements between INDENT and DEDENT)
    parse_block_body = function()
        expect("INDENT")
        local body = {}
        while peek() and peek().kind ~= "DEDENT" and peek().kind ~= "EOF" do
            local stmts = parse_stmt()
            if stmts then
                for _, s in ipairs(stmts) do
                    body[#body + 1] = s
                end
            end
            -- Skip NEWLINEs between statements
            while peek() and peek().kind == "NEWLINE" do
                advance()
            end
        end
        expect("DEDENT")
        return body
    end

    -- ============ EXPRESSIONS ============

    parse_expr = function()
        return parse_or()
    end

    parse_or = function()
        local left = parse_and()
        while peek() and peek().kind == "OR" do
            advance()
            local right = parse_and()
            left = {type = "BoolOp", op = "or", values = {left, right}}
        end
        return left
    end

    parse_and = function()
        local left = parse_not()
        while peek() and peek().kind == "AND" do
            advance()
            local right = parse_not()
            left = {type = "BoolOp", op = "and", values = {left, right}}
        end
        return left
    end

    parse_not = function()
        if peek() and peek().kind == "NOT" then
            advance()
            return {type = "UnaryOp", op = "not", operand = parse_not()}
        end
        return parse_comparison()
    end

    parse_comparison = function()
        local left = parse_term()
        local ops = {"==", "!=", "<", ">", "<=", ">=", "is", "is not", "in", "not in"}
        local op_map = {
            ["EQEQ"] = "==", ["NOTEQ"] = "!=",
            ["LESS"] = "<", ["GREATER"] = ">",
            ["LESSEQ"] = "<=", ["GREATEREQ"] = ">=",
        }
        while peek() do
            local t = peek()
            local op = op_map[t.kind]
            if not op and t.kind == "IS" then
                advance()
                if peek() and peek().kind == "NOT" then
                    advance()
                    op = "is not"
                else
                    op = "is"
                end
            elseif not op and t.kind == "IN" then
                advance()
                op = "in"
            elseif not op and t.kind == "NOT" then
                -- 'not in'
                local saved = pos
                advance()
                if peek() and peek().kind == "IN" then
                    advance()
                    op = "not in"
                else
                    pos = saved
                    break
                end
            elseif op then
                advance()
            else
                break
            end
            local right = parse_term()
            left = {type = "Compare", left = left, ops = {op}, comparators = {right}}
        end
        return left
    end

    parse_term = function()
        local left = parse_factor()
        while peek() and (peek().kind == "PLUS" or peek().kind == "MINUS") do
            local op = advance()
            local right = parse_factor()
            left = {type = "BinOp", left = left, op = op.value, right = right}
        end
        return left
    end

    parse_factor = function()
        local mul_ops = {"STAR", "SLASH", "DOUBLESLASH", "PERCENT"}
        local left = parse_unary()
        while peek() do
            local found = false
            for _, mop in ipairs(mul_ops) do
                if peek().kind == mop then
                    found = true
                    break
                end
            end
            if found then
                local op = advance()
                local right = parse_unary()
                left = {type = "BinOp", left = left, op = op.value, right = right}
            else
                break
            end
        end
        return left
    end

    parse_unary = function()
        if peek() and (peek().kind == "PLUS" or peek().kind == "MINUS") then
            local op = advance()
            return {type = "UnaryOp", op = op.value, operand = parse_unary()}
        end
        local left = parse_power()
        return left
    end

    parse_power = function()
        local left = parse_primary()
        if peek() and peek().kind == "DOUBLESTAR" then
            advance()
            local right = parse_unary()
            left = {type = "BinOp", left = left, op = "**", right = right}
        end
        return left
    end

    parse_primary = function()
        local expr = parse_atom()
        while true do
            if peek() and peek().kind == "LPAREN" then
                advance()
                local args = {}
                if peek() and peek().kind ~= "RPAREN" then
                    args[#args + 1] = parse_expr()
                    while match("COMMA") do
                        args[#args + 1] = parse_expr()
                    end
                end
                expect("RPAREN")
                expr = {type = "Call", func = expr, args = args}
            elseif peek() and peek().kind == "LBRACKET" then
                advance()
                local idx = parse_expr()
                expect("RBRACKET")
                expr = {type = "Subscript", value = expr, index = idx}
            elseif peek() and peek().kind == "DOT" then
                advance()
                local attr = expect("IDENTIFIER")
                expr = {type = "Attribute", value = expr, attr = attr.value}
            else
                break
            end
        end
        return expr
    end

    parse_atom = function()
        local t = peek()
        if not t then error("unexpected EOF") end

        if t.kind == "NONE" then
            advance()
            return {type = "Constant", value = nil}
        elseif t.kind == "TRUE" then
            advance()
            return {type = "Constant", value = true}
        elseif t.kind == "FALSE" then
            advance()
            return {type = "Constant", value = false}
        elseif t.kind == "INTEGER" then
            advance()
            return {type = "Constant", value = tonumber(t.value)}
        elseif t.kind == "FLOAT" then
            advance()
            return {type = "Constant", value = tonumber(t.value)}
        elseif t.kind == "STRING" then
            advance()
            -- Unescape the string
            local raw = t.value
            local inner = raw:sub(2, #raw - 1)
            inner = unescape_string(inner)
            return {type = "Constant", value = inner}
        elseif t.kind == "IDENTIFIER" then
            advance()
            if t.value == "None" then
                return {type = "Constant", value = nil}
            elseif t.value == "True" then
                return {type = "Constant", value = true}
            elseif t.value == "False" then
                return {type = "Constant", value = false}
            end
            return {type = "Name", id = t.value}
        elseif t.kind == "LPAREN" then
            advance()
            local expr = parse_expr()
            expect("RPAREN")
            return expr
        elseif t.kind == "LBRACKET" then
            advance()
            local elts = {}
            if peek() and peek().kind ~= "RBRACKET" then
                elts[#elts + 1] = parse_expr()
                while match("COMMA") do
                    elts[#elts + 1] = parse_expr()
                end
            end
            expect("RBRACKET")
            return {type = "List", elts = elts}
        elseif t.kind == "LBRACE" then
            advance()
            local keys = {}
            local values = {}
            if peek() and peek().kind ~= "RBRACE" then
                keys[#keys + 1] = parse_expr()
                expect("COLON")
                values[#values + 1] = parse_expr()
                while match("COMMA") do
                    keys[#keys + 1] = parse_expr()
                    expect("COLON")
                    values[#values + 1] = parse_expr()
                end
            end
            expect("RBRACE")
            return {type = "Dict", keys = keys, values = values}
        end

        error("unexpected token " .. t.kind .. " (" .. t.value .. ") at line " .. t.line .. " col " .. t.col)
    end

    unescape_string = function(s)
        -- Basic unescaping for Lua
        local result = s:gsub('\\\\', '\\')
        result = result:gsub('\\n', '\n')
        result = result:gsub('\\t', '\t')
        result = result:gsub('\\"', '"')
        result = result:gsub("\\'", "'")
        return result
    end

    local ast = parse_program()
    return ast
end


-- ============================================================
-- Code Generator
-- ============================================================

local function generate(ast)
    local indent_level = 0
    local parts = {}

    local function indent()
        return string.rep("    ", indent_level)
    end

    local function push(s)
        parts[#parts + 1] = s
    end

    local function gen_string_literal(s)
        -- Escape special chars for Lua string literal
        s = s:gsub("\\", "\\\\")
        s = s:gsub("\n", "\\n")
        s = s:gsub("\t", "\\t")
        s = s:gsub("\"", "\\\"")
        s = s:gsub("\'", "\\'")
        return "\"" .. s .. "\""
    end

    local function gen_expr(expr)
        if expr.type == "Constant" then
            local v = expr.value
            if v == nil then return "nil" end
            if v == true then return "true" end
            if v == false then return "false" end
            if type(v) == "string" then return gen_string_literal(v) end
            return tostring(v)
        elseif expr.type == "Name" then
            return expr.id
        elseif expr.type == "BinOp" then
            local l = gen_expr(expr.left)
            local r = gen_expr(expr.right)
            local op = expr.op
            if op == "**" then
                return "(" .. l .. " ^ " .. r .. ")"
            elseif op == "//" then
                return "math.floor(" .. l .. " / " .. r .. ")"
            elseif op == "+" then
                -- Check if either operand is a string literal
                if (expr.left.type == "Constant" and type(expr.left.value) == "string") or
                   (expr.right.type == "Constant" and type(expr.right.value) == "string") then
                    return "(" .. l .. " .. " .. r .. ")"
                end
                return "(" .. l .. " + " .. r .. ")"
            elseif op == "*" then
                -- Check for string repetition (str * int or int * str)
                if expr.left.type == "Constant" and type(expr.left.value) == "string" then
                    return "string.rep(" .. l .. ", " .. r .. ")"
                elseif expr.right.type == "Constant" and type(expr.right.value) == "string" then
                    return "string.rep(" .. r .. ", " .. l .. ")"
                end
                return "(" .. l .. " * " .. r .. ")"
            else
                return "(" .. l .. " " .. op .. " " .. r .. ")"
            end
        elseif expr.type == "UnaryOp" then
            local op = expr.op
            local operand = gen_expr(expr.operand)
            return "(" .. op .. " " .. operand .. ")"
        elseif expr.type == "BoolOp" then
            local vals = {}
            for _, v in ipairs(expr.values) do
                vals[#vals + 1] = gen_expr(v)
            end
            return table.concat(vals, " " .. expr.op .. " ")
        elseif expr.type == "Compare" then
            local left = gen_expr(expr.left)
            local op = expr.ops[1]
            local right = gen_expr(expr.comparators[1])
            if op == "!=" then
                return "(" .. left .. " ~= " .. right .. ")"
            elseif op == "is" then
                return "(" .. left .. " == " .. right .. ")"
            elseif op == "is not" then
                return "(" .. left .. " ~= " .. right .. ")"
            elseif op == "in" then
                return "__py_in(" .. right .. ", " .. left .. ")"
            elseif op == "not in" then
                return "not __py_in(" .. right .. ", " .. left .. ")"
            else
                return "(" .. left .. " " .. op .. " " .. right .. ")"
            end
        elseif expr.type == "Call" then
            local f = gen_expr(expr.func)
            local args = {}
            for _, a in ipairs(expr.args) do
                args[#args + 1] = gen_expr(a)
            end
            return f .. "(" .. table.concat(args, ", ") .. ")"
        elseif expr.type == "Subscript" then
            local v = gen_expr(expr.value)
            local idx = gen_expr(expr.index)
            -- Only offset for numeric indices (0->1), not string keys
            if expr.index.type == "Constant" and type(expr.index.value) == "string" then
                return v .. "[" .. idx .. "]"
            end
            return v .. "[" .. idx .. " + 1]"
        elseif expr.type == "Attribute" then
            return gen_expr(expr.value) .. "." .. expr.attr
        elseif expr.type == "List" then
            local elts = {}
            for _, e in ipairs(expr.elts) do
                elts[#elts + 1] = gen_expr(e)
            end
            return "{" .. table.concat(elts, ", ") .. "}"
        elseif expr.type == "Dict" then
            local items = {}
            for i = 1, #expr.keys do
                local k = gen_expr(expr.keys[i])
                local v = gen_expr(expr.values[i])
                items[#items + 1] = "[" .. k .. "] = " .. v
            end
            return "{" .. table.concat(items, ", ") .. "}"
        end
        error("unknown expression type: " .. expr.type)
    end

    local function gen_stmt(stmt)
        if stmt.type == "FunctionDef" then
            local args = table.concat(stmt.args, ", ")
            push(indent() .. "function " .. stmt.name .. "(" .. args .. ")")
            indent_level = indent_level + 1
            for _, s in ipairs(stmt.body) do
                gen_stmt(s)
            end
            indent_level = indent_level - 1
            push(indent() .. "end")

        elseif stmt.type == "If" then
            local test = gen_expr(stmt.test)
            push(indent() .. "if " .. test .. " then")
            indent_level = indent_level + 1
            for _, s in ipairs(stmt.body) do
                gen_stmt(s)
            end
            indent_level = indent_level - 1
            for _, elif in ipairs(stmt.elifs) do
                local etest = gen_expr(elif.test)
                push(indent() .. "elseif " .. etest .. " then")
                indent_level = indent_level + 1
                for _, s in ipairs(elif.body) do
                    gen_stmt(s)
                end
                indent_level = indent_level - 1
            end
            if stmt.orelse then
                push(indent() .. "else")
                indent_level = indent_level + 1
                for _, s in ipairs(stmt.orelse) do
                    gen_stmt(s)
                end
                indent_level = indent_level - 1
            end
            push(indent() .. "end")

        elseif stmt.type == "While" then
            local test = gen_expr(stmt.test)
            push(indent() .. "while " .. test .. " do")
            indent_level = indent_level + 1
            for _, s in ipairs(stmt.body) do
                gen_stmt(s)
            end
            push(indent() .. "::__continue::")
            indent_level = indent_level - 1
            push(indent() .. "end")

        elseif stmt.type == "For" then
            if stmt.is_range then
                local start, stop, step
                local n = #stmt.range_args
                local start_str = gen_expr(stmt.range_args[1])
                if n == 1 then
                    start = "0"
                    stop = start_str
                    step = "1"
                elseif n == 2 then
                    start = start_str
                    stop = gen_expr(stmt.range_args[2])
                    step = "1"
                else
                    start = start_str
                    stop = gen_expr(stmt.range_args[2])
                    step = gen_expr(stmt.range_args[3])
                end
                push(indent() .. "for " .. stmt.target .. " = " .. start .. ", " .. stop .. " - 1, " .. step .. " do")
            else
                local iter = gen_expr(stmt.iter)
                push(indent() .. "for _, " .. stmt.target .. " in ipairs(" .. iter .. ") do")
            end
            indent_level = indent_level + 1
            for _, s in ipairs(stmt.body) do
                gen_stmt(s)
            end
            push(indent() .. "::__continue::")
            indent_level = indent_level - 1
            push(indent() .. "end")

        elseif stmt.type == "Return" then
            if stmt.value then
                push(indent() .. "return " .. gen_expr(stmt.value))
            else
                push(indent() .. "return")
            end

        elseif stmt.type == "Assign" then
            local target = gen_expr(stmt.targets[1])
            local value = gen_expr(stmt.value)
            push(indent() .. target .. " = " .. value)

        elseif stmt.type == "AugAssign" then
            local target = gen_expr(stmt.target)
            local value = gen_expr(stmt.value)
            push(indent() .. target .. " = " .. target .. " " .. stmt.op .. " " .. value)

        elseif stmt.type == "ExprStmt" then
            push(indent() .. gen_expr(stmt.expr))

        elseif stmt.type == "Pass" then
            push(indent() .. "-- pass")

        elseif stmt.type == "Break" then
            push(indent() .. "break")

        elseif stmt.type == "Continue" then
            push(indent() .. "goto __continue")

        else
            error("unknown statement type: " .. stmt.type)
        end
    end

    -- Generate runtime helpers preamble
    push("do")
    push("function __py_in(container, item)")
    push("    if type(container) == \"table\" then")
    push("        for _, __v in ipairs(container) do")
    push("            if __v == item then return true end")
    push("        end")
    push("        return false")
    push("    elseif type(container) == \"string\" then")
    push("        return string.find(container, item, 1, true) ~= nil")
    push("    end")
    push("    return false")
    push("end")
    push("function __py_range(...)")
    push("    local start, stop, step")
    push("    if select(\"#\", ...) == 1 then")
    push("        start, stop, step = 0, (...), 1")
    push("    elseif select(\"#\", ...) == 2 then")
    push("        start, stop, step = (...), select(2, ...), 1")
    push("    else")
    push("        start, stop, step = (...), select(2, ...), select(3, ...)")
    push("    end")
    push("    local result = {}")
    push("    if step > 0 then")
    push("        for i = start, stop - 1, step do")
    push("            result[#result + 1] = i")
    push("        end")
    push("    elseif step < 0 then")
    push("        for i = start, stop + 1, step do")
    push("            result[#result + 1] = i")
    push("        end")
    push("    end")
    push("    return result")
    push("end")
    push("end")
    push("")

    for _, stmt in ipairs(ast.body) do
        gen_stmt(stmt)
    end

    return table.concat(parts, "\n")
end

-- ============================================================
-- Public API
-- ============================================================

local python = {}

function python.transpile(source)
    -- Strip trailing whitespace and remove blank lines
    local lines = {}
    for line in source:gmatch("[^\n]+") do
        line = line:match("^(.-)%s*$")
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    source = table.concat(lines, "\n")
    local tokens = tokenize(source)
    local ast = parse(tokens)
    local lua_code = generate(ast)
    python.last_code = lua_code
    return lua_code
end

function python.run(source)
    local lua_code = python.transpile(source)
    local fn, err = load(lua_code, "=python")
    if not fn then
        error("Python runtime error: " .. tostring(err))
    end
    return fn()
end

return python
