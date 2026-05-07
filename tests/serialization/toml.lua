local serde = require("serde")
require("test")

---@param test Test
---@param roundtrip_test function
---@param _test_data table
---@param read_sample function
return function(test, roundtrip_test, _test_data, read_sample)
  test.describe("TOML", function()
    test.it("encodes and decodes simple key-value pairs", function()
      local data = { key1 = "value1", key2 = "value2" }
      roundtrip_test("TOML", data, serde.toml.encode, serde.toml.decode)
    end)

    test.it("encodes and decodes nested tables", function()
      local data = {
        ["table1"] = {
          key = "value",
          nested = {
            inner = "nested_value",
          },
        },
      }
      roundtrip_test("TOML", data, serde.toml.encode, serde.toml.decode)
    end)

    test.it("handles arrays", function()
      local data = { fruits = { "apple", "banana", "cherry" } }
      roundtrip_test("TOML", data, serde.toml.encode, serde.toml.decode)
    end)

    test.it("handles different data types", function()
      local data = {
        integer = 42,
        float = 3.14,
        boolean = true,
        string = "text",
        datetime = "1979-05-27T07:32:00Z",
      }
      roundtrip_test("TOML", data, serde.toml.encode, serde.toml.decode)
    end)

    test.it("handles comments", function()
      local data = { value = 42 }
      local encoded = serde.toml.encode(data)
      test.expect(encoded).to.be.a("string")
    end)

    test.it("handles multiline strings", function()
      local data = { text = [[Line 1
Line 2
Line 3]] }
      local encoded = serde.toml.encode(data)
      local decoded = serde.toml.decode(encoded)
      test.expect(decoded).to.equal(data)
    end)

    test.it("handles empty structures", function()
      local empty = {}
      local encoded = serde.toml.encode(empty)
      local decoded = serde.toml.decode(encoded)
      test.expect(decoded).to.equal(empty)
    end)

    test.it("decodes sample.toml from file", function()
      local sample = read_sample("sample.toml")
      local data = serde.toml.decode(sample)
      test.expect(data.name).to.equal("John Doe")
      test.expect(data.address.street).to.equal("123 Main St")
    end)

    test.it("handles sections", function()
      local toml_str = '[server]\nhost = "localhost"\nport = 8080\n'
      local data = serde.toml.decode(toml_str)
      test.expect(data.server).to.be.a("table")
      test.expect(data.server.host).to.equal("localhost")
    end)

    test.it("handles invalid TOML", function()
      test
        .expect(function()
          serde.toml.decode("= invalid")
        end).to
        .fail()
    end)
  end)

  test.describe("TOML - Real World Examples", function()
    test.it("decodes TOML with datetime", function()
      local toml_datetime = read_sample("datetime.toml")
      local decoded = serde.toml.decode(toml_datetime)
      test.expect(decoded.build.timestamp).to.equal("1979-05-27T07:32:00Z")
      test.expect(decoded.deploy.date).to.equal("1979-05-27 07:32:00.000000")
    end)

    test.it("decodes TOML with arrays of tables", function()
      local toml_arrays = read_sample("products.toml")
      local decoded = serde.toml.decode(toml_arrays)
      test.expect(#decoded.products).to.equal(3)
      test.expect(decoded.products[1].name).to.equal("Hammer")
      test.expect(decoded.products[2].sku).to.equal(284758393)
    end)

    test.it("decodes Cargo.toml-like file", function()
      local cargo_toml = read_sample("cargo.toml")
      local decoded = serde.toml.decode(cargo_toml)
      test.expect(decoded.package.name).to.equal("my-package")
      test.expect(decoded.package.version).to.equal("0.1.0")
      test.expect(decoded.dependencies.serde.version).to.equal("1.0")
      test.expect(#decoded.package.authors).to.equal(1)
    end)

    test.it("decodes TOML with nested tables using dots", function()
      local toml_nested = read_sample("nested_dotted.toml")
      local decoded = serde.toml.decode(toml_nested)
      test.expect(decoded.owner.name).to.equal("John Doe")
      test.expect(decoded.owner.address.city).to.equal("New York")
      test.expect(decoded.database.connection.host).to.equal("localhost")
      test.expect(decoded.database.connection.pool.max).to.equal(10)
    end)
  end)
end
