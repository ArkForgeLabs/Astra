-- Astra globals and helpers
assert(Astra ~= nil, "Astra global")
assert(type(Astra.version) == "string", "Astra.version")

assert(string.split ~= nil, "string.split")
local t = string.split("a,b,c", ",")
assert(#t == 3 and t[1] == "a" and t[2] == "b" and t[3] == "c", "string.split comma")
t = string.split("x y z", " ")
assert(#t == 3 and t[1] == "x" and t[3] == "z", "string.split space")

assert(uuid ~= nil, "uuid")
local u = uuid()
assert(type(u) == "string" and #u > 0, "uuid returns string")

assert(regex ~= nil, "regex")
local r = regex("^hello")
assert(r.is_match(r, "hello world") == true, "regex is_match true")
assert(r.is_match(r, "no hello") == false, "regex is_match false")

assert(os.getenv ~= nil and os.setenv ~= nil, "os.getenv/setenv")
os.setenv("ASTRA_TEST_VAR", "ok")
assert(os.getenv("ASTRA_TEST_VAR") == "ok", "os.setenv/getenv")

if is_main_script ~= nil then
  local main = is_main_script("tests/astra.lua")
  assert(type(main) == "boolean", "is_main_script returns boolean")
end
