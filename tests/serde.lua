-- serde (json, toml, etc.) encode/decode
local serde = require("serde")
assert(serde ~= nil, "serde")

-- json
local enc = serde.json.encode({ a = 1, b = "x" })
assert(type(enc) == "string", "json.encode string")
assert(enc:find("a") and enc:find("1"), "json.encode content")
local dec = serde.json.decode('{"a":1,"b":"x"}')
assert(dec.a == 1 and dec.b == "x", "json.decode")

-- roundtrip
local t = { x = 1, y = { z = 2 } }
assert(serde.json.decode(serde.json.encode(t)).x == 1, "json roundtrip")
assert(serde.json.decode(serde.json.encode(t)).y.z == 2, "json roundtrip nested")

-- toml
enc = serde.toml.encode({ key = "val" })
assert(type(enc) == "string", "toml.encode")
dec = serde.toml.decode('key = "val"')
assert(dec.key == "val", "toml.decode")

-- yaml
enc = serde.yaml.encode({ foo = "bar" })
assert(type(enc) == "string", "yaml.encode")
dec = serde.yaml.decode("foo: bar")
assert(dec.foo == "bar", "yaml.decode")
