# Validation

Sometimes during development, your server receives structured data such as JSON
from outside, or a function needs a parameter with a specific structure that
must be verified at runtime. The validation module provides a composable
builder API for defining and checking data structures.

## Builder API

The module returns builders under the `validation` key. Each builder creates a
validator object with a `validate(validator, value)` standalone function.

```lua
local v = require("validation").validation

-- Primitives
v.string()       -- validates type == "string"
v.number()       -- validates type == "number"
v.integer()      -- validates number is an integer
v.boolean()      -- validates type == "boolean"
v.none()          -- validates value == nil

-- Constrained
v.number({ integer = true })              -- integer only
v.number({ range = { min = 0, max = 100 } })  -- inclusive range
v.number({ range = { min = 0, minExclusive = true } })  -- exclusive
v.pattern("^%a+$")                        -- string matching Lua pattern

-- Compound
v.struct({
  id = v.number(),
  name = v.string()
})  -- object shape
v.array(v.string())                        -- array of items
v.optional(v.string())                     -- value or nil
v.union(v.string(), v.number())            -- one of multiple types
v.literal("exact")                         -- exact value match
```

## Validating values

```lua
local v = require("validation").validation
local validate = v.validate

local schema = v.struct({ id = v.number() })

-- Validate a value at runtime
local ok, err = validate(schema, { id = 1 })
-- ok: boolean
-- err: string | nil  (error description if validation fails)
```

## Examples

### Basic usage

```lua
local v = require("validation").validation
local validate = v.validate

local User = v.struct({
  id = v.number(),
  name = v.string(),
  email = v.optional(v.string()),
  tags = v.array(v.string()),
})

local data = { id = 1, name = "Alice", tags = { "admin" } }
local ok, err = validate(User, data)
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

type User = typeof(UserValidator)
-- User = { id: number, name: string, email: string? }

local data: User = { id = 1, name = "Alice" }
```

For `build()` constructors, use `:type()` to get the struct shape:

```luau
local UserBuilder = v.build(v.struct({
  id = v.number(),
  name = v.string(),
}))

type User = typeof(UserBuilder:type())
-- User = { id: number, name: string }

local data: User = UserBuilder({ id = 1, name = "Alice" })
```

## API Reference

### Primitives

| Builder | Returns | Description |
|---|---|---|
| `string(opts?)` | string | Accepts any string. Options: `{ default: string? }` |
| `number(opts?)` | number | Accepts any number. Options: `{ integer?, range?, default: number? }` |
| `integer()` | number | Accepts only integer numbers |
| `boolean(opts?)` | boolean | Accepts true or false. Options: `{ default: boolean? }` |
| `none()` | nil | Accepts only nil |

### Number options

```lua
v.number({
  integer = true,        -- reject non-integers
  default = 0,           -- default value when used with build()
  range = {              -- numeric range check
    min = 0,
    max = 100,
    minExclusive = true, -- value must be > min (not >=)
    maxExclusive = true, -- reject value == max
  },
})
```

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

### Callable constructors

`v.build(schema)` creates a callable constructor that validates input, fills
field-level defaults, and returns the validated table. On failure, it throws
an error — wrap in `pcall` to handle failures.

```lua
local Point = v.build(v.struct({
  x = v.number({ default = 0 }),
  y = v.number({ default = 0 }),
}))

-- Success
local ok, p = pcall(Point, { x = 1, y = 2 })
-- ok = true, p = { x = 1, y = 2 }

-- With defaults
local ok, q = pcall(Point, {})
-- ok = true, q = { x = 0, y = 0 }

-- Failure (throws error)
local ok, err = pcall(Point, { x = "bad" })
-- ok = false, err = "x.expected number, got string"
```

| Builder | Return type (Luau) | Description |
|---|---|---|
| `build(schema)` | T (schema shape) | Callable struct constructor. Fields with `.default` are filled when missing. `:type()` returns the struct validator. |

### Regex

```lua
local validation = require("validation")
local my_regex = validation.regex("^hello.*")
```
