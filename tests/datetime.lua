-- datetime.new and getters
local datetime = require("datetime")
assert(datetime ~= nil and datetime.new ~= nil, "datetime.new")

local dt = datetime.new()
assert(dt ~= nil, "new()")
assert(type(dt.get_year) == "function", "get_year")
assert(type(dt.get_month) == "function", "get_month")
local y = dt:get_year()
local m = dt:get_month()
assert(type(y) == "number" and type(m) == "number", "year/month numbers")
assert(y >= 1970 and y <= 2100, "year range")
assert(m >= 1 and m <= 12, "month range")

assert(type(dt.to_rfc3339) == "function", "to_rfc3339")
local s = dt:to_rfc3339()
assert(type(s) == "string" and #s > 0, "to_rfc3339 string")

-- parse from string
local dt2 = datetime.new("2020-01-15T12:00:00Z")
assert(dt2 ~= nil, "new(string)")
assert(dt2:get_year() == 2020, "parsed year")
assert(dt2:get_month() == 1, "parsed month")
assert(dt2:get_day() == 15, "parsed day")
