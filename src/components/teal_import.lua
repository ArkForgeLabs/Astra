local source = [====================================================================================================[
@SOURCE
]====================================================================================================]
local file_name = [[@FILE_NAME]]
local teal_compile_checks = true

if teal_compile_checks then
    local tlconfig = { global_env_def = "astra/teal/astra" }
    tlconfig._init_env_modules = tlconfig._init_env_modules or {}
    if tlconfig.global_env_def then
        table.insert(tlconfig._init_env_modules, 1, tlconfig.global_env_def)
    end

    local opts = {
        defaults = {
            feat_lax = "on",
            gen_compat = "off",
        },
        predefined_modules = tlconfig._init_env_modules,
    }
    local env = Astra.teal.new_env(opts)

    local check_errors = Astra.teal.check_string(source, env)
    if check_errors ~= nil then
        local syntax_errors = check_errors.syntax_errors
        local type_errors = check_errors.type_errors

        if #syntax_errors ~= 0 or #type_errors ~= 0 then
            if #syntax_errors ~= 0 then
                print("========================================")
                print(tostring(#syntax_errors) .. " syntax errors:")
                for _, value in ipairs(syntax_errors) do
                    print(file_name .. ":" .. tostring(value.x) .. ":" .. tostring(value.y) .. ": " .. value.msg)
                end
            end
            if #type_errors ~= 0 then
                print("========================================")
                print(tostring(#type_errors) .. " type errors:")
                for _, value in ipairs(type_errors) do
                    print(file_name .. ":" .. tostring(value.x) .. ":" .. tostring(value.y) .. ": " .. value.msg)
                end
            end
            print("----------------------------------------")
            os.exit()
        end
    end
end
Astra.teal.load(source, file_name)()
