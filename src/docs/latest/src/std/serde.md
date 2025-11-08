# Serialization & Deserialization

## JSON

Often you will have to deal with a medium of structured data between your server and the clients. This could be in form of JSON, YAML, e.t.c. Astra includes some utilities to serialize and deserialize these with native Lua structures.

For JSON, you can import the serializer package (`require("serde")`), and then use `json.encode()` and `json.decode()` methods which converts JSON data from and into Lua tables.

```lua
local serde = require("serde")

local value = { key = 1.23 }
local to_json = serde.json.encode(value) -- Returns JSON string
local from_json = serde.json.decode(to_json) -- Returns back the original value

assert(from_json, value)
```
