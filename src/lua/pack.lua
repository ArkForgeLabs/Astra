---@diagnostic disable: lowercase-global
--!nocheck

-- https://github.com/turtleDev/pack.lua/blob/main/src/pack.lua
--[[
    The MIT License
    Copyright (C) 2017 Saravjeet 'Aman' Singh
    <saravjeetamansingh@gmail.com>
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

-- map module path to modules array
local module_index = {}

-- contains source for modules
local modules = {}

local luapack_header = [[
---@diagnostic disable: duplicate-set-field, lowercase-global

__luapack_modules__ = {
%s
}
__luapack_cache__ = {}
__luapack_require__ = function(idx)
    local cache = __luapack_cache__[idx]
    if cache then
        return cache
    end
    local module = __luapack_modules__[idx]()
    __luapack_cache__[idx] = module
    return module
end
]]

local function file_exists(filename)
    local f, err = io.open(filename, "r")
    if f then
        io.close(f)
        return true
    elseif err == "No such file or directory" then
        return false
    end
end

if (file_exists("minify.lua")) then
    local minify = require "minify"
end

-- python-like path helpers
path = {
    isrelative = function(path)
        return path:sub(1, 1) ~= '/'
    end,
    isabsolute = function(path)
        return path:sub(1, 1) == '/'
    end,
    join = function(base, addon)
        -- addon path must be relative
        if path.isabsolute(addon) then
            return addon
        end

        -- prepare the base path, and make sure it points to a directory
        if path.isrelative(base) then
            base = path.abspath(base)
        end
        if path.isfile(base) then
            base = path.dirname(base)
        end

        -- join
        local newpath = base .. '/' .. addon

        -- normalise
        newpath = path.abspath(newpath)

        -- realpath failed
        if newpath:sub(1, 1) ~= '/' then
            return addon
        end

        return newpath
    end,
    isdir = function(path)
        return os.execute("test -d " .. path) == 0
    end,
    isfile = function(path)
        return os.execute("test -f " .. path) == 0
    end,
    abspath = function(path)
        local cmd = string.format("realpath %s", path)
        return strip(io.popen(cmd):read("*a"))
    end,
    basename = function(path)
        local cmd = string.format("basename %s", path)
        return strip(io.popen(cmd):read("*a"))
    end,
    dirname = function(path)
        local cmd = string.format("dirname %s", path)
        return strip(io.popen(cmd):read("*a"))
    end
}

function strip(str)
    return string.gsub(str, "%s", "")
end

function require_string(idx)
    return string.format("__luapack_require__(%d)\n", idx)
end

function import(module_path)
    local cache_idx = module_index[module_path]
    if cache_idx then
        return require_string(cache_idx)
    end

    local fd, err = io.open(module_path)
    if fd == nil then
        error(err)
    end
    local source = fd:read("*a")
    io.close(fd)
    source = transform(source, module_path)
    table.insert(modules, source)
    local idx = #modules
    module_index[module_path] = idx
    return require_string(idx)
end

function transform(source, source_path)
    local context = path.abspath(path.dirname(source_path))
    local pattern = "require%s*%(?%s*[\"'](.-)[\"']%s*%)?"
    return string.gsub(source, pattern, function(name)
        local path_to_module = path.join(context, name)

        if not path.isfile(path_to_module) then
            return nil
        end

        return import(path_to_module)
    end)
end

function generate_module_header()
    if #modules < 1 then
        return ''
    end

    function left_pad(source, padding, ch)
        ch = ch or ' '
        local repl = function(str)
            return string.rep(ch, padding) .. str
        end
        return string.gsub(source, '(.-\n)', repl)
    end

    function pad(source)
        source = left_pad(source, 4)
        source = string.format('(function()\n%s\nend),\n', source)
        source = left_pad(source, 4)
        return source
    end

    local modstring = ''
    for i = 1, #modules do
        if (file_exists("minify.lua")) then
            ---@diagnostic disable-next-line: undefined-global
            local did_minify, module = Minify(modules[i])
            modstring = modstring .. pad(module)
        else
            modstring = modstring .. pad(modules[i])
        end
    end
    if #modules > 1 then
        -- strip the last newline, make it look pretty
        modstring = modstring:sub(1, -2)
    end
    local header = string.format(luapack_header, modstring)
    return header
end

function main(argv)
    if #argv == 0 then
        local usage = string.format('usage: %s <toplevel-module>.lua', argv[0])
        print(usage)
        return -1
    end

    local entry = argv[1]
    local fd, err = io.open(entry)
    if fd == nil then
        error(err)
    end
    local source = fd:read("*a")
    io.close(fd)
    local path_to_entry = path.abspath(entry)
    source = transform(source, path_to_entry)
    local header = generate_module_header()

    source = header .. '\n' .. source

    local out = string.gsub(entry, "%.lua", "")
    out = out .. "_bundle.lua"
    out = path.basename(out)
    io.open(out, "w"):write(source)

    return 0
end

os.exit(main(arg))
