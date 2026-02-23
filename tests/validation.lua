local validation = require("validation")
local validate_table = validation.validate_table
assert(validate_table ~= nil, "validate_table")

local ok, err = validate_table({ name = "a", count = 1 }, { name = "string", count = "number" })
assert(ok == true, "valid simple")
assert(err == nil, "no err on valid")

ok, err = validate_table({}, { name = "string" })
assert(ok == false, "missing required")
assert(err ~= nil, "err on missing")

ok, err = validate_table({ name = 99 }, { name = "string" })
assert(ok == false, "wrong type")
assert(err ~= nil, "err on wrong type")

ok, err = validate_table({ name = "a", extra = 1 }, { name = "string" })
assert(ok == false, "unexpected key")
assert(err ~= nil, "err on unexpected key")

ok, err = validate_table({}, { name = { "string", false } })
assert(ok == true, "optional missing ok")

ok, err = validate_table({ inner = { x = "y" } }, { inner = { x = "string" } })
assert(ok == true, "nested valid")

ok, err = validate_table({ nums = { 1, 2, 3 } }, { nums = { "array", "number" } })
assert(ok == true, "array of number")
