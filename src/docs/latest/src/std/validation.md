# Validation

Sometimes during development, your server receives structured data such as JSON
from outside, or a function needs a parameter with a specific structure that
must be verified at runtime. The validation module provides a composable
builder API for defining and checking data structures.

## Builder API

The module returns builders under the `validation` key. Each builder creates a
validator object with a `validate(validator, value)` standalone function.

```luau
local t = require("validation").types

-- You can define types such as this
local UserType = t.struct({ -- containers for values
  id = t.number(),
  name = t.string({ default = "Student" }),
  email = t.optional(t.string()),
  tags = t.array(t.string()),
  metadata = t.optional(t.struct({
    role = t.string(),
    score = t.number({ range = { min = 0, max = 100 } }),
  })),
})
-- In Luau
type UserType = typeof(UserType)

-- Or wrap it with t.build() to make it usable
local User = t.build(UserType)
-- In Luau, you can also use the :type() method to get the derived type with builder API
type User = typeof(User:type())

-- This allows us to do many cool things such as initializing and automatically validating:
local alice = User({
  id = 1,
  name = "Alice",
  tags = { "admin" },
  metadata = { role = "student", score = 85 },
})
print(alice.name) -- Alice

-- And of course you can still use the validate function standalone as well:
assert(t.validate(User, alice))
```

The full API is as follows:

```lua
-- Primitives
t.string()       -- validates type == "string"
t.number()       -- validates type == "number"
t.integer()      -- validates number is an integer
t.boolean()      -- validates type == "boolean"
t.none()          -- validates value == nil

-- Constrained
t.number({ integer = true })              -- integer only
t.number({ range = { min = 0, max = 100 } })  -- inclusive range
t.number({ range = { min = 0, minExclusive = true } })  -- exclusive
t.pattern("^%a+$")                        -- string matching Lua pattern

-- Compound
t.struct({
  id = t.number(),
  name = t.string()
})  -- object shape
t.array(t.string())                        -- array of items
t.optional(t.string())                     -- value or nil
t.union(t.string(), t.number())            -- one of multiple types
t.literal("exact")                         -- exact value match
```

### Regex

```lua
local validation = require("validation")
local my_regex = validation.regex("^hello.*")
```
