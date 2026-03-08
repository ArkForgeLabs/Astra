# Validation

Sometimes during development, your server likely recieves structured data such as JSON from outside, or a function you have needs to have a certain parameter with a certain structure that you need to verify during runtime as well as development. You likely also have a structure in mind for them. For these cases to validate that the structures are correct and to confidently go through them without risk of errors, you can use the schema validation utility.

Structure Validation essentially is a function that returns true if a given table is of a given structure definition. The structure is defined as a separate table that has the field names along the types and requirements. For example:

```lua
local validation = require("validation")

-- Your schema
local schema = {
  -- Type names along their types and requirements
  id = "number",
  name = { "string", required = false }, -- optional field
}
-- Your actual data
local example = { id = "123", name = 456 }
-- Check the validation
local is_valid, err = validation.validate_table(example, schema)
assert(is_valid, "Validation failed: " .. tostring(err))
```

Almost all of the native lua types are accounted for. Deeply nesting is obviously supported as well:

```lua
local schema = {
  user = {
    "table",
    {
      profile = { "table", { id = "number", name = "string" } }
    }
  }
}
local example = {
  user = { profile = { name = "John" } },
}
local is_valid, err = validation.validate_table(example, schema)
assert(is_valid, "Validation failed: " .. tostring(err))
```

As well as arrays:

```lua
local schema = {
  -- normal single type array
  numbers = { "array", "number" },
  strings = { "array", "string" },
  -- table array
  entries = {
    "array",
    {
      id = "number",
      text = "string",
    },
  },
}

local tbl = {
  numbers = { 1, 2, 3 },
  strings = { "a", "b", "c" },
  entries = {
    {
      id = 123,
      text = "hey!",
    },
    {
      id = 456,
      text = "hello!",
    },
  },
}

local is_valid, err = validation.validate_table(tbl, schema)
assert(is_valid, "Validation failed: " .. tostring(err))
```
