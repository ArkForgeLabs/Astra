# Validation

Sometimes during development, your server receives structured data such as JSON
from outside, or a function needs a parameter with a specific structure that
must be verified at runtime. The validation module provides a composable
builder API for defining and checking data structures.

## Builder API

The module returns builders under the `validation` key. Each builder creates a
validator object with `:validate(value)` and `:type()` methods.

```lua
local v = require("validation").validation

-- Primitives
v.string()       -- validates type == "string"
v.number()       -- validates type == "number"
v.integer()      -- validates number is an integer
v.boolean()      -- validates type == "boolean"
v.nil()          -- validates value == nil

-- Constrained
v.number({ integer = true })              -- integer only
v.number({ range = { min = 0, max = 100 } })  -- inclusive range
v.number({ range = { min = 0, minExclusive = true } })  -- exclusive
v.pattern("^%a+$")                        -- string matching Lua pattern

-- Compound
v.struct({ id = v.number(), name = v.string() })  -- object shape
v.array(v.string())                        -- array of items
v.optional(v.string())                     -- value or nil
v.union(v.string(), v.number())            -- one of multiple types
v.literal("exact")                         -- exact value match
```

## Validator methods

Every validator has two methods:

```lua
local validator = v.struct({ id = v.number() })

-- Validate a value at runtime
local ok, err = validator:validate({ id = 1 })
-- ok: boolean
-- err: string | nil  (error description if validation fails)

-- Get the Luau type for typeof() derivation (Luau only)
local validator = v.struct({ id = v.number(), name = v.string() })
type MyType = typeof(validator:type())
-- MyType = { id: number, name: string }
```

## Examples

### Basic usage

```lua
local v = require("validation").validation

local User = v.struct({
  id = v.number(),
  name = v.string(),
  email = v.optional(v.string()),
  tags = v.array(v.string()),
})

local data = { id = 1, name = "Alice", tags = { "admin" } }
local ok, err = User:validate(data)
if ok then
  print("Valid!")
else
  print("Invalid: " .. tostring(err))
end
```

### Nested structures

```lua
local Company = v.struct({
  name = v.string(),
  employees = v.array(v.struct({
    id = v.integer(),
    name = v.string(),
    email = v.optional(v.string()),
  })),
  metadata = v.optional(v.struct({
    founded = v.number(),
    active = v.boolean(),
  })),
})
```

### Type derivation (Luau)

In Luau, you can derive static types from validators:

```luau
local v = require("@astra/validation").validation

local UserValidator = v.struct({
  id = v.number(),
  name = v.string(),
  email = v.optional(v.string()),
})

type User = typeof(UserValidator:type())
-- User = { id: number, name: string, email: string? }

local data: User = { id = 1, name = "Alice" }
UserValidator:validate(data)
```

## API Reference

### Primitives

| Builder | Returns | Description |
|---|---|---|
| `string()` | validator | Accepts any string |
| `number(opts?)` | validator | Accepts any number |
| `integer()` | validator | Accepts only integer numbers |
| `boolean()` | validator | Accepts true or false |
| `nil()` | validator | Accepts only nil |

### Number options

```lua
v.number({
  integer = true,        -- reject non-integers
  range = {              -- numeric range check
    min = 0,
    max = 100,
    minExclusive = true, -- value must be > min (not >=)
    maxExclusive = true, -- reject value == max
  },
})

### Compound builders

| Builder | Return type (Luau) | Description |
|---|---|---|
| `struct({...})` | T (schema shape) | Object with typed fields. Rejects extra keys. |
| `array(item)` | {T} | Array where each element matches item type. |
| `optional(inner)` | T? | Accepts nil or the inner type. |
| `union(a, b)` | T \| U | Accepts if value matches either type. |
| `literal(value)` | T | Exact match using == comparison. |

### Constrained builders

| Builder | Return type | Description |
|---|---|---|
| `range({min?, max?, ...})` | number | Validates number against range with exclusive bounds. |
| `pattern(str)` | string | Validates string against Lua pattern via string.match. |

### Utility

```lua
local validation = require("validation")
local my_regex = validation.regex("^hello.*")
```

The `regex` function remains at the top level of the module export.
