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
  tags = { "admin", "power-user" },
  score = 85,
}

local ok, err = validate(User, data)
if ok then
  print("Valid!")
else
  print("Invalid: " .. tostring(err))
end

-- Use v.build() for callable constructors with defaults
local Point = v.build(v.struct({
  x = v.number({ default = 0 }),
  y = v.number({ default = 0 }),
}))

-- User values override field-level defaults
local ok, p = pcall(Point, { x = 1, y = 2 })
if ok then
  print("Point: " .. p.x .. ", " .. p.y)
end

local ok2, q = pcall(Point, {})
if ok2 then
  print("Default point: " .. q.x .. ", " .. q.y)
end
