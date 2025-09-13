local source = [====================================================================================================[
@SOURCE
]====================================================================================================]
local file_name = [[@FILE_NAME]]

local check_errors = Astra.teal.check_string(source)
if check_errors ~= nil then
    local syntax_errors = check_errors.syntax_errors
    local type_errors = check_errors.type_errors

    if #syntax_errors ~= 0 or #type_errors ~= 0 then
        if #syntax_errors ~= 0 then
            print("========================================")
            print(tostring(#syntax_errors) .. "syntax errors:\n")
            for _, value in ipairs(syntax_errors) do
                print(file_name .. ":" .. tostring(value.x) .. ":" .. tostring(value.y) .. ":" .. value.msg)
            end
        end
        if #type_errors ~= 0 then
            print("========================================")
            print(tostring(#type_errors) .. "type errors:\n")
            for _, value in ipairs(type_errors) do
                print(file_name .. ":" .. tostring(value.x) .. ":" .. tostring(value.y) .. ":" .. value.msg)
            end
        end
        os.exit()
    end
end
Astra.teal.load(source, file_name)()