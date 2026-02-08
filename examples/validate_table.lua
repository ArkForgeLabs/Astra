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
      optional = { "number", required = false },
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
      optional = 123,
    },
    {
      id = 456,
      text = "hello!",
    },
  },
}

local is_valid, err = require("validation").validate_table(table_to_validate, schema)
if is_valid then
  print("The table is valid!")
else
  print("Validation failed: " .. tostring(err))
end
