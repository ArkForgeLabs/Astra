--!strict

local v = require("@astra/validation").validation

local User = v.build(v.struct({
  id = v.number(),
  name = v.string(),
  email = v.optional(v.string()),
  tags = v.array(v.string()),
  metadata = v.optional(v.struct({
    role = v.string(),
    score = v.number({ range = { min = 0, max = 100 } }),
  })),
}))

type User = typeof(User:type())
-- User = { id: number, name: string, email: string?, tags: { string },
--          metadata: { role: string, score: number }? }

local data = User({
  id = 1,
  name = "Alice",
  tags = { "admin" },
  metadata = { score = 85 },
})

local ok, err = v.validate(User, data)
if ok then
  print("Valid!")
else
  print("Invalid: " .. tostring(err))
end

-- Use v.build() for callable constructors with defaults
local PointBuilder = v.build(v.struct({
  x = v.number(),
  y = v.number(),
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
