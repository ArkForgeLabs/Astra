--- Validation tests using the validation module
local validation = require("validation")

-- Test 1: Basic type validation
print("=== Test 1: Basic type validation ===")
local basic_schema = {
    name = "string",
    age = "number",
    active = "boolean"
}

local valid_basic = {
    name = "John",
    age = 25,
    active = true
}

local invalid_basic = {
    name = "John",
    age = "twenty five",  -- should be number
    active = true
}

local result1, err1 = validation.validate_table(valid_basic, basic_schema)
print("Valid basic types:", result1, err1)

local result2, err2 = validation.validate_table(invalid_basic, basic_schema)
print("Invalid basic types:", result2, err2)

-- Test 2: Required vs optional fields
print("\n=== Test 2: Required vs optional fields ===")
local optional_schema = {
    name = "string",  -- required by default
    age = { "number", false },  -- optional
    email = { type = "string", required = false }
}

local valid_optional = {
    name = "John"
    -- age and email are optional
}

local invalid_optional = {
    -- name is required but missing
    age = 25
}

local result3, err3 = validation.validate_table(valid_optional, optional_schema)
print("Valid optional fields:", result3, err3)

local result4, err4 = validation.validate_table(invalid_optional, optional_schema)
print("Invalid optional fields (missing required):", result4, err4)

-- Test 3: Nested table validation
print("\n=== Test 3: Nested table validation ===")
local nested_schema = {
    user = {
        name = "string",
        email = "string",
        settings = {
            theme = "string",
            notifications = "boolean"
        }
    }
}

local valid_nested = {
    user = {
        name = "John",
        email = "john@example.com",
        settings = {
            theme = "dark",
            notifications = true
        }
    }
}

local invalid_nested = {
    user = {
        name = "John",
        email = "john@example.com",
        settings = {
            theme = "dark",
            notifications = "yes"  -- should be boolean
        }
    }
}

local result5, err5 = validation.validate_table(valid_nested, nested_schema)
print("Valid nested tables:", result5, err5)

local result6, err6 = validation.validate_table(invalid_nested, nested_schema)
print("Invalid nested tables:", result6, err6)

-- Test 4: Array validation
print("\n=== Test 4: Array validation ===")
local array_schema = {
    numbers = { "array", "number" },
    strings = { "array", "string" },
    users = {
        type = "array",
        schema = {
            id = "number",
            name = "string"
        }
    }
}

local valid_array = {
    numbers = { 1, 2, 3, 4 },
    strings = { "a", "b", "c" },
    users = {
        { id = 1, name = "John" },
        { id = 2, name = "Jane" }
    }
}

local invalid_array = {
    numbers = { 1, 2, "three", 4 },  -- invalid number
    strings = { "a", "b", "c" },
    users = {
        { id = 1, name = "John" },
        { id = "two", name = "Jane" }  -- invalid id type
    }
}

local result7, err7 = validation.validate_table(valid_array, array_schema)
print("Valid arrays:", result7, err7)

local result8, err8 = validation.validate_table(invalid_array, array_schema)
print("Invalid arrays:", result8, err8)

-- Test 5: Range constraints
print("\n=== Test 5: Range constraints ===")
local range_schema = {
    age = { type = "number", min = 0, max = 120 },
    score = { type = "number", min = 0, max = 100 },
    username = { type = "string", min = 3, max = 20 }
}

local valid_range = {
    age = 25,
    score = 85,
    username = "john_doe"
}

local invalid_range = {
    age = 150,  -- too high
    score = 85,
    username = "jo"  -- too short
}

local result9, err9 = validation.validate_table(valid_range, range_schema)
print("Valid ranges:", result9, err9)

local result10, err10 = validation.validate_table(invalid_range, range_schema)
print("Invalid ranges:", result10, err10)

-- Test 6: Default values
print("\n=== Test 6: Default values ===")
local default_schema = {
    name = "string",
    age = { type = "number", default = 18 },
    role = { type = "string", default = "user" }
}

local input_with_defaults = {
    name = "John"
    -- age and role will use defaults
}

local result11, err11 = validation.validate_table(input_with_defaults, default_schema)
print("With defaults:", result11, err11)
print("Final table with defaults:", input_with_defaults.age, input_with_defaults.role)

-- Test 7: Error handling - unexpected keys
print("\n=== Test 7: Error handling - unexpected keys ===")
local strict_schema = {
    name = "string",
    age = "number"
}

local input_with_extra = {
    name = "John",
    age = 25,
    extra_field = "should not be here"
}

local result12, err12 = validation.validate_table(input_with_extra, strict_schema)
print("With unexpected keys:", result12, err12)

-- Test 8: Complex nested example (original test)
print("\n=== Test 8: Complex nested example ===")
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

local result13, err13 = validation.validate_table(test, schema)
print("Complex nested example:", result13, err13)

print("\n=== All tests completed ===")
