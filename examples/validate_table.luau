local t = require("@astra/validation").types

local User = t.struct({
  id = t.number(),
  name = t.string(),
  email = t.optional(t.string()),
  tags = t.array(t.string()),
  metadata = t.optional(t.struct({
    role = t.string(),
    score = t.number({ range = { min = 0, max = 100 } }),
  })),
})

type User = typeof(User)
-- User = { id: number, name: string, email: string?, tags: { string },
--          metadata: { role: string, score: number }? }

local data: User = {
  id = 1,
  name = "Alice",
  tags = { "admin" },
  metadata = { role = "student", score = 85 },
}

assert(t.validate(User, data), "Invalid!")

-- Use t.build() for callable constructors with defaults
local PointBuilder = t.build(t.struct({
  x = t.number(),
  y = t.number(),
}))

type Point = typeof(PointBuilder:type())
-- Point = { x: number, y: number }

local ok, p = pcall(PointBuilder, { x = 1, y = 2 })
if ok then
  print("Point: " .. p.x .. ", " .. p.y)
end

local ok2, q = pcall(PointBuilder, {})
if ok2 then
  print("Default point: " .. q.x .. ", " .. q.y)
end
