local fs = require("fs")

---@param test Test
return function(test)
  local function read_sample(name)
    return fs.read_file("tests/serialization/samples/" .. name)
  end

  local function roundtrip_test(_format_name, data, encode_fn, decode_fn)
    local encoded = encode_fn(data)
    local decoded = decode_fn(encoded)
    test.expect(decoded).to.equal(data)
  end

  local test_data = {
    simple = {
      string = "hello",
      number = 42,
      boolean = true,
      nil_value = nil,
    },
    nested = {
      user = {
        name = "John",
        age = 30,
        active = true,
        tags = { "admin", "user" },
      },
    },
    complex = {
      metadata = {
        version = "1.0",
        timestamp = 1234567890,
        config = {
          debug = false,
          timeout = 30,
        },
      },
      items = {
        { id = 1, name = "Item 1" },
        { id = 2, name = "Item 2" },
      },
    },
  }

  test.paths.least = {
    test = function(value, min)
      return value >= min,
        "expected " .. tostring(value) .. " to be at least " .. tostring(min),
        "expected " .. tostring(value) .. " to not be at least " .. tostring(min)
    end,
  }
  table.insert(test.paths.be, "least")

  require("tests.serialization.json")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.json5")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.yaml")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.toml")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.xml")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.csv")(test, roundtrip_test, test_data, read_sample)
  require("tests.serialization.ini")(test, roundtrip_test, test_data, read_sample)
end
