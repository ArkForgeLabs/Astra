local schema = {
	-- normal single type array
	numbers = { type = "array", array_item_type = "number" },
	strings = { type = "array", array_item_type = "string" },
	-- table array
	entries = {
		type = "array",
		schema = {
			id = { type = "number" },
			text = { type = "string" },
		},
	},
}

local table_to_validate = {
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

local is_valid, err = require("astra.teal.validation").validate_table(table_to_validate, schema)
if is_valid then
	print("The table is valid!")
else
	print("Validation failed: " .. tostring(err))
end
