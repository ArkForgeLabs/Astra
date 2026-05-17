local t = require("validation").types

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
-- User = { id: number, name: string, email: string?, tags: { string },
--          metadata: { role: string, score: number }? }

local data = {
  id = 1,
  name = "Alice",
  tags = { "admin" },
  metadata = { role = "student", score = 85 },
}

assert(t.validate(User, data), "Invalid!")

-- Use t.build() for callable constructors with defaults
local Point = t.build(t.struct({
  x = t.number({ default = 0 }),
  y = t.number({ default = 0 }),
}))

-- User values override field-level defaults
---@diagnostic disable-next-line: param-type-mismatch
local ok, p = pcall(Point, { x = 1, y = 2 })
if ok then
  print("Point: " .. p.x .. ", " .. p.y)
end

---@diagnostic disable-next-line: param-type-mismatch
local ok2, q = pcall(Point, {})
if ok2 then
  print("Default point: " .. q.x .. ", " .. q.y)
end
