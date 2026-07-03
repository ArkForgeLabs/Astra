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

    test.it("decodes trailing commas", function()
      local decoded = serde.json5.decode([[{a: 1, b: 2,}]])
      test.expect(decoded.a).to.equal(1)
      test.expect(decoded.b).to.equal(2)
    end)

    test.it("decodes unquoted keys", function()
      local decoded = serde.json5.decode([[{name: "value", count: 42}]])
      test.expect(decoded.name).to.equal("value")
      test.expect(decoded.count).to.equal(42)
    end)

    test.it("decodes JSON5 comments", function()
      local result = serde.json5.decode([[
        {
          // line comment
          value: 42,
          /* block
             comment */
          name: "test"
        }
      ]])
      test.expect(result.value).to.equal(42)
      test.expect(result.name).to.equal("test")
    end)

    test.it("decodes hex numbers", function()
      local decoded = serde.json5.decode([[{hex: 0xFF, hex2: 0x1A}]])
      test.expect(decoded.hex).to.equal(255)
      test.expect(decoded.hex2).to.equal(26)
    end)

    test.it("decodes Infinity and NaN values", function()
      local decoded = serde.json5.decode([[{inf: Infinity, neg_inf: -Infinity, nan: NaN}]])
      test.expect(decoded.inf > 1e308).to.be.truthy()
      test.expect(decoded.neg_inf < -1e308).to.be.truthy()
      test.expect(decoded.nan ~= decoded.nan).to.be.truthy()
    end)

    test.it("encode roundtrips with decode", function()
      local data = { text = "hello\nworld", value = 42, flag = true }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles multiline strings via roundtrip", function()
      local data = { text = [[Line 1
Line 2
Line 3]] }
      local encoded = serde.json5.encode(data)
      local decoded = serde.json5.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("encodes and decodes complex structure with roundtrip", function()
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
