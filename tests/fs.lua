-- fs API (logic: get_separator, get_current_dir, get_script_path, new_buffer)
local fs = require("fs")
assert(fs ~= nil, "fs")

local sep = fs.get_separator()
assert(type(sep) == "string" and (sep == "/" or sep == "\\"), "get_separator")

local cwd = fs.get_current_dir()
assert(type(cwd) == "string" and #cwd > 0, "get_current_dir")

local script_path = fs.get_script_path()
assert(type(script_path) == "string", "get_script_path")

local buf = fs.new_buffer(10)
assert(buf ~= nil, "new_buffer")
assert(type(buf.bytes) == "function", "buffer.bytes")
assert(type(buf.text) == "function", "buffer.text")

-- read_file/write_file roundtrip
local test_file = "tests" .. sep .. "fs_test_tmp.txt"
fs.write_file(test_file, "hello")
local content = fs.read_file(test_file)
assert(content == "hello", "write_file/read_file")
fs.write_file(test_file, "")
content = fs.read_file(test_file)
assert(content == "", "read_file after overwrite")
fs.remove(test_file)
