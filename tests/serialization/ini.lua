local serde = require("serde")
require("test")

---@param test Test
---@param _roundtrip_test function
---@param _test_data table
---@param read_sample function
return function(test, _roundtrip_test, _test_data, read_sample)
  test.describe("INI", function()
    test.it("encodes a table to INI string", function()
      local result = serde.ini.encode({ key = "value" })
      test.expect(result).to.match("key")
      test.expect(result).to.match("value")
      local decoded = serde.ini.decode(result)
      test.expect(decoded.key).to.equal("value")
    end)

    test.it("decodes an INI string to table", function()
      local result = serde.ini.decode("key = value")
      test.expect(result.key).to.equal("value")
    end)

    test.it("decodes sample.ini from file", function()
      local sample = read_sample("sample.ini")
      local data = serde.ini.decode(sample)
      test.expect(data.name).to.equal('"John Doe"')
      test.expect(data.age).to.equal('"30"')
    end)

    test.it("handles sections", function()
      local ini_str = "[section]\nkey = value\n"
      local data = serde.ini.decode(ini_str)
      test.expect(data.section.key).to.equal("value")
    end)

    test.it("encodes tables with sections", function()
      local result = serde.ini.encode({ section = { key = "value" } })
      test.expect(result).to.match(".*%[section%].*")
      test.expect(result).to.match(".*key=value.*")
    end)

    test.it("roundtrip encode-decode preserves values", function()
      local data = { server = { host = "localhost", port = "8080" } }
      local encoded = serde.ini.encode(data)
      local decoded = serde.ini.decode(encoded)
      test.expect(decoded.server.host).to.equal("localhost")
      test.expect(decoded.server.port).to.equal("8080")
    end)

    test.it("handles numeric values as strings", function()
      local ini_str = "key = 42\n"
      local data = serde.ini.decode(ini_str)
      test.expect(data.key).to.equal("42")
    end)

    test.it("handles boolean-like values as strings", function()
      local ini_str = "flag = true\n"
      local data = serde.ini.decode(ini_str)
      test.expect(data.flag).to.equal("true")
    end)

    test.it("handles INI comments", function()
      local ini_str = "; This is a comment\nkey = value\n"
      local data = serde.ini.decode(ini_str)
      test.expect(data.key).to.equal("value")
    end)

    test.it("handles invalid INI gracefully", function()
      test
        .expect(function()
          serde.ini.decode("")
        end).to_not
        .fail()
    end)

    test.it("handles empty input without error", function()
      local ok = pcall(function()
        serde.ini.decode("")
      end)
      test.expect(ok).to.equal(true)
    end)
  end)
end
