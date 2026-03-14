local test = require("test")

local count = 0
test.it_internal = test.it
---@diagnostic disable-next-line: duplicate-set-field
test.it = function(name, fn)
  count = count + 1
  test.it_internal(name, fn)
end

pprint("Astra Tests\n")

require("tests.schema_validation")(test)
require("tests.core_utilities")(test)
require("tests.serialization")(test)
require("tests.datetime")(test)
require("tests.crypto")(test)
require("tests.fs")(test)
