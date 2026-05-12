---@diagnostic disable: need-check-nil

-- Test script to verify database schema creation

local db = require("backend.server.database")
local serde = require("serde")

-- Test that tables were created
local tables = db:query_all("SELECT name FROM sqlite_master WHERE type='table';")

print("Tables in database:")
---@diagnostic disable-next-line: param-type-mismatch
for i, table in ipairs(tables) do
  print("  " .. table.name)
end

-- Test inserting and retrieving an event
local test_event = {
  event_type = "test_event",
  user_id = "user123",
  session_id = "session456",
  properties = {
    key1 = "value1",
    key2 = "value2",
  },
}

local success, result = pcall(function()
  local properties_json = serde.json.encode(test_event.properties)
  return db:execute("INSERT INTO events (event_type, user_id, session_id, properties) VALUES ($1, $2, $3, $4);", {
    test_event.event_type,
    test_event.user_id,
    test_event.session_id,
    properties_json,
  })
end)

if success then
  print("Event inserted successfully")

  -- Retrieve the event
  local event = db:query_one("SELECT * FROM events ORDER BY created_at DESC LIMIT 1")
  print("Retrieved event:")
  print("  ID: " .. event.id)
  print("  Event type: " .. event.event_type)
  print("  User ID: " .. event.user_id)
  print("  Session ID: " .. event.session_id)
  print("  Properties: " .. event.properties)
else
  print("Error inserting event: " .. tostring(result))
end

print("Schema test completed")
