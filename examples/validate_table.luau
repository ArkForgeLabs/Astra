--!strict

local v = require("@astra/validation").validation

local UserValidator = v.struct({
	id = v.number(),
	name = v.string(),
	email = v.optional(v.string()),
	tags = v.array(v.string()),
	metadata = v.optional(v.struct({
		role = v.string(),
		score = v.number({ range = { min = 0, max = 100 } }),
	})),
})

type User = typeof(UserValidator:type())
-- User = { id: number, name: string, email: string?, tags: { string },
--          metadata: { role: string, score: number }? }

local data: User = {
	id = 1,
	name = "Alice",
	tags = { "admin" },
	metadata = { role = "developer", score = 85 },
}

local ok, err = UserValidator:validate(data)
if ok then
	print("Valid!")
else
	print("Invalid: " .. tostring(err))
end
