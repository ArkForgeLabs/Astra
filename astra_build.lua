--!nocheck
--[[
    Astra's build system script written by Elham Aryanpur.
    There are many commands to automate the common tasks around.
    This script was tested with Lua 5.4 and LuaJIT.
    The license is same as the Astra's license.
]]

local runtime = "luajit"

------------- UTILS

---@param table_to_check table
---@param value_to_check any
local function contains(table_to_check, value_to_check)
    for _, value in ipairs(table_to_check) do
        if value == value_to_check then
            return true
        end
    end
    return false
end

---@param directory string
---@param ignore table?
---@param command string
local function execute_command_in_subdirectories(directory, ignore, command)
    local handle = io.popen("ls " .. directory, "r")

    if not handle then
        print("Failed to open directory: " .. directory)
        return
    end

    for file in handle:lines() do
        if file ~= "" then
            local full_path = directory .. "/" .. file

            -- Check if the entry is a directory
            local is_dir = Astra.io.get_metadata(full_path):file_type():is_dir()

            if is_dir then                
                print("Executing command in directory: " .. full_path)
                if not ignore then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    if not contains(ignore, file) then
                        os.execute("cd " .. full_path .. " && " .. command)
                    end
                else
                    os.execute("cd " .. full_path .. " && " .. command)
                end
            end
        end
    end

    handle:close()
end

------------- COMMANDS

local function print_usage()
    io.write("Usage: astra_build.lua [command] [options]\n")
    io.write("\nCommands:\n")
    io.write("  help            Display this help message.\n")
    io.write("  version         Show the version information.\n")
    io.write("  changelog <TAG> Update CHANGELOG.md.\n")
    io.write("  docs            Generate documentation.\n")
end

local function show_version()
    io.write("Astra Build CLI Version 1.0\n")
end

local function execute_update_changelog(tag)
    if tag == "unreleased" or tag == nil then
        os.execute("git cliff --unreleased --prepend CHANGELOG.md")
    else
        os.execute("git cliff --unreleased --tag=\"" .. tag .. "\" --prepend CHANGELOG.md")
    end
end

local function execute_build_docs()
    -- Placeholder for generating documentation
    io.write("Generating documentation...\n")
    execute_command_in_subdirectories("src/docs", { "theme" }, "mdbook build")
end

local function main(args)
    if args == nil or #args <= 0 then
        print_usage()
        return
    end

    local command = args[1]
    if args[-1] == "lua" then
        runtime = "lua"
    end

    if command == "help" then
        print_usage()
    elseif command == "version" then
        show_version()
    elseif command == "changelog" then
        execute_update_changelog(args[2])
    elseif command == "docs" then
        execute_build_docs()
    else
        io.write("Unknown command: ", command, "\n")
        print_usage()
    end
end

main(arg)
