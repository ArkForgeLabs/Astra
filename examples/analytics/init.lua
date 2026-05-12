local driver = require("database")
local initialize_ab_tests = require("backend.analytics.parts.ab_tests")
local initialize_events = require("backend.analytics.parts.events")
local server = require("http").server.new()

server.port = 20000

---@diagnostic disable-next-line: need-check-nil
local analytics_sql = io.open("backend/analytics/default.sql", "r"):read("*a")

local db = driver.new("sqlite", "analytics.db")
db:execute(analytics_sql, {})

initialize_events(server, db)
initialize_ab_tests(server, db)

print("Listening to " .. server.hostname .. ":" .. server.port)

server:run()
