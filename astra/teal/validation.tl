---Schema validation function with support for nested tables and arrays of tables
local function validate_table(input_table: { string: any }, schema: { string: any }): (boolean, string | nil)
	-- Helper function to check if a value is of the expected type
	local function check_type(value: any, expected_type: string): boolean
		local type_map: {string:string} = {
			number = "number",
			string = "string",
			boolean = "boolean",
			table = "table",
			["function"] = "function",
			["nil"] = "nil",
			array = "table",
		}
		return type(value) == type_map[expected_type]
	end

	-- Helper function to check if a value is within a range (if applicable)
	local function check_range(value: number, min: number, max: number): boolean
		return not (min and value < min) and not (max and value > max)
	end

	-- Helper function to validate nested tables
	local function validate_nested_table(value: table, nested_schema: table, path: string): (boolean, string | nil)
		local is_valid, err = validate_table(value, nested_schema)
		if not is_valid then
			return false, '"' .. path .. '"' .. err
		end
		return true
	end

	-- Helper function to validate arrays of tables
	local function validate_array_of_tables(value: {table}, array_schema: table, path: string): (boolean, string | nil)
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
	local function validate_array_of_primitives(value: {table}, array_item_type: string, path: string): (boolean, string | nil)
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
	for key, untyped_constraints in pairs(schema) do
		local constraints: {string:any} = untyped_constraints as table

		local value = input_table[key]
		local expected_type: string = constraints.type as string
		local min = constraints.min as number
		local max = constraints.max as number
		local nested_schema = constraints.schema -- Schema for nested tables
		local default_value = constraints.default
		local path: string = key as string
		local required = true
		if constraints.required == false then
			required = false
		end

		-- Check if the key exists in the table and is required
		if required and value == nil then
			return false, "\n" .. "Missing required key: " .. '"' .. path .. '"'
		end

		-- If the key exists, check its type
		if value ~= nil and not check_type(value, expected_type) then
			return false,
				"\n" .. "Incorrect type for key: " .. path .. ". Expected " .. expected_type .. ", got " .. type(value)
		end

		-- If the value is a nested table, validate it recursively
		if nested_schema and type(value) == "table" and expected_type == "table" then
			local is_valid, err = validate_nested_table(value as table, nested_schema as table, path)
			if not is_valid then
				return false, "\n" .. "Error in nested table for key: " .. err
			end
		end

		-- If the value is an array of tables, validate each element
		if expected_type == "array" and type(value) == "table" and nested_schema then
			local is_valid, err = validate_array_of_tables(value as {table}, nested_schema as table, path)
			if not is_valid then
				return false, "\n" .. "Error in array of tables for key: " .. err
			end
		end

		-- If the value is an array of primitive types, validate each element
		if expected_type == "array" and type(value) == "table" and not nested_schema then
			local is_valid, err = validate_array_of_primitives(value as {table}, constraints.array_item_type as string, path)
			if not is_valid then
				return false, "\n" .. "Error in array of primitives for key: " .. err
			end
		end

		-- Check range constraints (if applicable)
		if value ~= nil and not check_range(value as number, min, max) then
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
			local key_cast = key as string
			return false, "\n" .. "Unexpected key found: " .. key_cast
		end
	end

	return true
end

return { validate_table = validate_table }