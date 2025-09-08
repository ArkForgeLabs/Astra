# Schema Validation

Sometimes during development, your server likely recieves structured data such as JSON from outside. You likely also have a structure in mind for them. For these cases to validate that the structures are correct and to confidently go through them without risk of errors, hopefully, you can use the schema validation utility.

Schema Validation essentially is a function that returns true if a given table is of a given structure. The structure is defined as a separate table that has the field names along the types and requirements. For example:

```lua
local validation = require("astra.lua.validation")

-- Your schema
local schema = {
    -- Type names along their types and requirements
    id = { type = "number" },
    name = { type = "string", required = false }
}
-- Your actual data
local example = { id = "123", name = 456 }
-- Check the validation
local is_valid, err = validation.validate_table(example, schema)
assert(not is_valid, "Validation failed: expected validation to fail")
```

Almost all of the native lua types are accounted for. Deeply nesting is obviously supported as well:

```lua
local schema = {
    user = {
        type = "table",
        schema = {
            profile = {
                type = "table",
                schema = {
                    id = { type = "number" },
                    name = { type = "string" }
                }
            }
        }
    }
}
local example = {
    user = {
        profile = {
            name = "John",
        },
    },
}
local is_valid, err = validation.validate_table(example, schema)
assert(is_valid, "Validation failed: " .. tostring(err))
```

As well as arrays:

```lua
local schema = {
    -- normal single type array
    numbers = { type = "array", array_item_type = "number" },
    strings = { type = "array", array_item_type = "string" },
    -- table array
    entries = {
        type = "array",
        schema = {
            id = { type = "number" },
            text = { type = "string" }
        }
    }
}

local tbl = {
    numbers = { 1, 2, 3 },
    strings = { "a", "b", "c" },
    entries = {
        {
            id = 123,
            text = "hey!"
        },
        {
            id = 456,
            text = "hello!"
        }
    }
}

local is_valid, err = validation.validate_table(tbl, schema)
assert(is_valid, "Validation failed: " .. tostring(err))
```
