--- Validation tests using the validation module
local validation = require("validation")

local schema = {
    field1 = "string",
    field2 = { "number", false },
    field3 = {
        field3_1 = "string",
        field3_2 = { "array", "number" }
    }
}

local test = {
    field1 = "Hello",
    field3 = {
        field3_1 = "meow",
        field3_2 = { 1, 2, 3 }
    }
}

local result, err = validation.validate_table(test, schema)
print(result, err)
