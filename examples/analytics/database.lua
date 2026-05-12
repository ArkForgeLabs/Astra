local driver = require("database")

---@diagnostic disable-next-line: need-check-nil
local analytics_sql = io.open("backend/server/sql/analytics.sql", "r"):read("*a")

local db = driver.new("sqlite", "analytics.db")
db:execute(analytics_sql, {})

return db
