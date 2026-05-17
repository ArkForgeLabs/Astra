local v = require("validation").validation
local validate = v.validate

local User = v.struct({
  id = v.number(),
  name = v.string(),
  email = v.optional(v.string()),
  tags = v.array(v.string()),
  score = v.number({ range = { min = 0, max = 100 } }),
})

local data = {
  id = 1,
  name = "Alice",
  email = "alice@example.com",
  tags = { "admin", "power-user" },
  score = 85,
}

local ok, err = validate(User, data)
if ok then
  print("Valid!")
else
  print("Invalid: " .. tostring(err))
end
