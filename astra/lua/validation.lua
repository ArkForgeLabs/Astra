---@meta

---Schema validation function with support for nested tables and arrays of tables
---@param input_table table
---@param schema table
---@return boolean, string | nil
local function validate_table(input_table, schema)
    -- Helper function to check if a value is of the expected type
    local function check_type(value, expected_type)
        local type_map = {
            number = "number",
            string = "string",
            boolean = "boolean",
            table = "table",
            ["function"] = "function",
            ["nil"] = "nil",
            array = "table"
        }
        return type(value) == type_map[expected_type]
    end

    -- Helper function to check if a value is within a range (if applicable)
    local function check_range(value, min, max)
        -- Only check range for numbers
        if type(value) == "number" then
            return not (min and value < min) and not (max and value > max)
        end
        -- For strings, check length if min/max are numbers
        if type(value) == "string" and type(min) == "number" and type(max) == "number" then
            local length = #value
            return not (min and length < min) and not (max and length > max)
        end
        -- For other types or when no range constraints, consider valid
        return true
    end

    -- Helper function to process schema constraints and extract parameters
    local function process_schema_constraints(constraints, _key)
        local field_info = {
            type = nil,
            required = true,
            min = nil,
            max = nil,
            default = nil,
            schema = nil,
            array_item_type = nil
        }

        if type(constraints) == "string" then
            -- Simple type constraint: "string"
            field_info.type = constraints
        elseif type(constraints) == "table" then
            if #constraints > 0 then
                -- Array format: { "array", "number" } or { "array", {...} } or { "string", false }
                local first_elem = constraints[1]

                if first_elem == "array" then
                    -- Array type
                    field_info.type = "array"
                    if #constraints == 2 then
                        if type(constraints[2]) == "string" then
                            -- Array of primitives: { "array", "number" }
                            field_info.array_item_type = constraints[2]
                        elseif type(constraints[2]) == "table" then
                            -- Array of tables: { "array", {...} }
                            field_info.schema = constraints[2]
                        end
                    end
                else
                    -- Simple type with optional required flag: { "string", false }
                    field_info.type = first_elem
                    if #constraints == 2 and type(constraints[2]) == "boolean" then
                        field_info.required = constraints[2]
                    end
                    -- Handle additional named parameters like min, max, default, etc.
                    if constraints.min then field_info.min = constraints.min end
                    if constraints.max then field_info.max = constraints.max end
                    if constraints.default then field_info.default = constraints.default end
                    if constraints.required == false then field_info.required = false end
                end
            else
                -- Object format: { type = "string", min = 0, max = 100, default = "test", required = false }
                if constraints.type then
                    field_info.type = constraints.type
                else
                    -- Nested schema: { nested_field = "string" }
                    field_info.type = "table"
                    field_info.schema = constraints
                    -- Handle required parameter for nested tables
                    if constraints.required == false then field_info.required = false end
                end

                if constraints.min then field_info.min = constraints.min end
                if constraints.max then field_info.max = constraints.max end
                if constraints.default then field_info.default = constraints.default end
                if constraints.required == false then field_info.required = false end
            end
        end

        return field_info
    end

    -- Helper function to validate nested tables
    local function validate_nested_table(value, nested_schema, path)
        local is_valid, err = validate_table(value, nested_schema)
        if not is_valid then
            return false, "\"" .. path .. "\"" .. err
        end
        return true
    end

    -- Helper function to validate arrays of tables
    local function validate_array_of_tables(value, array_schema, path)
        if type(value) ~= "table" then
            return false, path .. ": Expected an array of tables, got " .. type(value)
        end
        for i, item in ipairs(value) do
            local is_valid, err = validate_nested_table(item, array_schema, path .. "[" .. i .. "]")
            if not is_valid then
                return false, err
            end
        end
        return true
    end

    -- Helper function to validate arrays of primitive types
    local function validate_array_of_primitives(value, array_item_type, path)
        if type(value) ~= "table" then
            return false, path .. ": Expected an array, got " .. type(value)
        end
        for i, item in ipairs(value) do
            if not check_type(item, array_item_type) then
                return false, path .. "[" .. i .. "]: Expected " .. array_item_type .. ", got " .. type(item)
            end
        end
        return true
    end

    -- Iterate over the schema
    for key, constraints in pairs(schema) do
        local field_info = process_schema_constraints(constraints, key)
        local value = input_table[key]
        local expected_type = field_info.type
        local min = field_info.min
        local max = field_info.max
        local nested_schema = field_info.schema
        local default_value = field_info.default
        local path = key
        local required = field_info.required

        -- Check if the key exists in the table and is required
        if required and value == nil then
            return false, "\n" .. "Missing required key: " .. "\"" .. path .. "\""
        end

        -- If the key exists, check its type
        if value ~= nil and not check_type(value, expected_type) then
            return false,
                "\n" .. "Incorrect type for key: " .. path .. ". Expected " .. expected_type .. ", got " .. type(value)
        end

        -- If the value is a nested table, validate it recursively
        if nested_schema and type(value) == "table" and expected_type == "table" then
            local is_valid, err = validate_nested_table(value, nested_schema, path)
            if not is_valid then
                return false, "\n" .. "Error in nested table for key: " .. err
            end
        end

        -- If the value is an array, validate its contents
        if expected_type == "array" and type(value) == "table" then
            if nested_schema then
                -- Array of tables
                local is_valid, err = validate_array_of_tables(value, nested_schema, path)
                if not is_valid then
                    return false, "\n" .. "Error in array of tables for key: " .. err
                end
            elseif field_info.array_item_type then
                -- Array of primitive types
                local is_valid, err = validate_array_of_primitives(value, field_info.array_item_type, path)
                if not is_valid then
                    return false, "\n" .. "Error in array of primitives for key: " .. err
                end
            end
        end

        -- Check range constraints (if applicable)
        if value ~= nil and not check_range(value, min, max) then
            return false, "\n" .. "Value for key " .. path .. " is out of range."
        end

        -- Apply default values if the key is missing and a default is provided
        if value == nil and default_value ~= nil then
            input_table[key] = default_value
        end
    end

    -- Check if the table has any unexpected keys
    for key in pairs(input_table) do
        if not schema[key] then
            return false, "\n" .. "Unexpected key found: " .. key
        end
    end

    return true
end

return { validate_table = validate_table }
