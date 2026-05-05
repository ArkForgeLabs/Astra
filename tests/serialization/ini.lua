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
      test.expect(result).to.be.a("string")
    end)

    test.it("decodes an INI string to table", function()
      local result = serde.ini.decode("key = value")
      test.expect(result).to.be.a("table")
    end)

    test.it("decodes sample.ini from file", function()
      local sample = read_sample("sample.ini")
      local data = serde.ini.decode(sample)
      test.expect(data).to.be.a("table")
    end)

    test.it("handles sections", function()
      local ini_str = "[section]\nkey = value\n"
      local data = serde.ini.decode(ini_str)
      test.expect(data.section).to.be.a("table")
    end)

    test.it("handles invalid INI gracefully", function()
      local ok = pcall(function()
        serde.ini.decode("")
      end)
      test.expect(ok).to.equal(true)
    end)
  end)
end
