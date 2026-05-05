local serde = require("serde")
require("test")

---@param test Test
---@param roundtrip_test function
---@param test_data table
---@param read_sample function
return function(test, roundtrip_test, test_data, read_sample)
  test.describe("JSON5", function()
    test.it("encodes and decodes simple types", function()
      roundtrip_test("JSON5", test_data.simple, serde.json5.encode, serde.json5.decode)
    end)

    test.it("encodes and decodes nested structures", function()
      roundtrip_test("JSON5", test_data.nested, serde.json5.encode, serde.json5.decode)
    end)

    test.it("encodes and decodes complex structures", function()
      roundtrip_test("JSON5", test_data.complex, serde.json5.encode, serde.json5.decode)
    end)

    test.it("handles trailing commas", function()
      local data = { a = 1, b = 2 }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles single-quoted strings", function()
      local data = { text = "single quoted" }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles unquoted keys", function()
      local data = { unquoted_key = "value" }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles comments in JSON5", function()
      local data = { value = 42 }
      local encoded = serde.json5.encode(data)
      test.expect(encoded).to.be.a("string")
      test.expect(#encoded).to.equal(#encoded)
    end)

    test.it("handles multiline strings", function()
      local data = { text = [[Line 1
Line 2
Line 3]] }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles relaxed syntax", function()
      local data = {
        relaxed = true,
        numbers = { 1, 2, 3 },
        nested = { inner = "value" },
      }
      roundtrip_test("JSON5", data, serde.json5.encode, serde.json5.decode)
    end)

    test.it("decodes sample.json5 from file", function()
      local sample = read_sample("sample.json5")
      local data = serde.json5.decode(sample)
      test.expect(data.name).to.equal("John Doe")
      test.expect(data.metadata.created).to.equal("2023-01-15")
    end)

    test.it("handles invalid JSON5", function()
      test
        .expect(function()
          serde.json5.decode("{invalid::}")
        end).to
        .fail()
    end)
  end)
end
