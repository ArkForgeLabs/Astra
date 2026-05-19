local test = require("test")

print([[
    _    ____ _____ ____      _
   / \  / ___|_   _|  _ \    / \
  / _ \ \___ \ | | | |_) |  / _ \
 / ___ \ ___) || | |  _ <  / ___ \
/_/   \_\____/ |_| |_| \_\/_/   \_\

Test Suite
]])

require("tests.schema_validation")(test)
require("tests.core_utilities")(test)
require("tests.serialization")(test)
require("tests.datetime")(test)
require("tests.crypto")(test)
require("tests.fs")(test)
require("tests.http")(test)
require("tests.templates")(test)
require("tests.database")(test)
require("tests.python")(test)
require("tests.python_tests")(test)
require("tests.stores")(test)

print(
  "\n\n" .. string.char(27) .. "[32m" .. test.passes,
  string.char(27) .. "[0m" .. "passed and",
  string.char(27) .. "[31m" .. test.errors,
  string.char(27) .. "[0m" .. "failed."
)
