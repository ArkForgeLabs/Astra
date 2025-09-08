# Crypto

During development of your web servers, you might need some cryptography functionality such as hashing and encoding. For these cases, Astra provides commonly used cryptographic functions to ease up development.

## Hashing

Currently Astra provides SHA2 and SHA3 (both 256 and 512 variants) hashing functions.

```lua
local crypto = require("astra.lua.crypto")

crypto.hash("sha2_512", "MY INPUT")
```

## Base64

Astra also provides encoding and decoding of base64 strings, including URL safe variants:

```lua
local input = "MY VERY COOL STRING"

local encoded = crypto.base64.encode(input)
print(encoded)

local decoded = crypto.base64.decode(encoded)
print(decoded)
```

## JSON

Often you will have to deal with a medium of structured data between your server and the clients. This could be in form of JSON, YAML, e.t.c. Astra includes some utilities to serialize and deserialize these with native Lua structures.

For JSON, you can import the serializer package (`require("astra.lua.serializer")`), and then use `json.encode()` and `json.decode()` methods which converts JSON data from and into Lua tables.
