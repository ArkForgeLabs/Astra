local serde = require("serde")
require("test")

---@param test Test
---@param roundtrip_test function
---@param test_data table
---@param read_sample function
return function(test, roundtrip_test, test_data, read_sample)
  test.describe("YAML", function()
    test.it("encodes and decodes simple types", function()
      roundtrip_test("YAML", test_data.simple, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("encodes and decodes nested structures", function()
      roundtrip_test("YAML", test_data.nested, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("encodes and decodes complex structures", function()
      roundtrip_test("YAML", test_data.complex, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("handles comments", function()
      local data = { value = 42 }
      local encoded = serde.yaml.encode(data)
      test.expect(encoded).to.be.a("string")
    end)

    test.it("handles multiline strings", function()
      local yaml_multiline = [[
      description: |
        This is a multiline string
        that spans multiple lines
        and preserves newlines

      compact: >
        This is a compact string
        that removes newlines
        and joins lines
    ]]
      local decoded = serde.yaml.decode(yaml_multiline)
      test.expect(decoded.description).to.be.a("string")
      test.expect(decoded.compact).to.be.a("string")
    end)

    test.it("handles lists", function()
      local data = { items = { 1, 2, 3, 4, 5 } }
      roundtrip_test("YAML", data, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("handles nested lists", function()
      local data = { matrix = { { 1, 2 }, { 3, 4 }, { 5, 6 } } }
      roundtrip_test("YAML", data, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("handles empty structures", function()
      local empty_obj = {}
      local empty_arr = {}

      local encoded_obj = serde.yaml.encode(empty_obj)
      local decoded_obj = serde.yaml.decode(encoded_obj)
      test.expect(decoded_obj).to.equal(empty_obj)

      local encoded_arr = serde.yaml.encode(empty_arr)
      local decoded_arr = serde.yaml.decode(encoded_arr)
      test.expect(decoded_arr).to.equal(empty_arr)
    end)

    test.it("handles special YAML features", function()
      local data = {
        boolean = true,
        null = nil,
        number = 42,
        string = "value",
      }
      roundtrip_test("YAML", data, serde.yaml.encode, serde.yaml.decode)
    end)

    test.it("decodes sample.yaml from file", function()
      local sample = read_sample("sample.yaml")
      local data = serde.yaml.decode(sample)
      test.expect(data.name).to.equal("John Doe")
      test.expect(data.age).to.equal(30)
      test.expect(data.address.street).to.equal("123 Main St")
    end)

    test.it("handles invalid YAML", function()
      test
        .expect(function()
          serde.yaml.decode(": invalid")
        end).to
        .fail()
    end)
  end)

  test.describe("YAML - Real World Examples", function()
    test.it("decodes YAML with anchors and aliases", function()
      local yaml_with_anchors = read_sample("anchors_aliases.yaml")
      local decoded = serde.yaml.decode(yaml_with_anchors)
      test.expect(decoded.defaults.adapter).to.equal("postgres")
      test.expect(decoded.production.database).to.equal("myapp_production")
    end)

    test.it("decodes Docker Compose-like YAML", function()
      local docker_compose = read_sample("docker_compose.yaml")
      local decoded = serde.yaml.decode(docker_compose)
      test.expect(decoded.version).to.equal("3.8")
      test.expect(decoded.services.web.image).to.equal("nginx:latest")
      test.expect(decoded.services.app.build).to.equal(".")
      test.expect(decoded.services.db.image).to.equal("postgres:13")
    end)

    test.it("decodes YAML with tags and implicit typing", function()
      local yaml_typed = read_sample("typed_values.yaml")
      local decoded = serde.yaml.decode(yaml_typed)
      test.expect(decoded.plain).to.equal(42)
      test.expect(decoded.explicit_int).to.equal(42)
      test.expect(decoded.explicit_float).to.equal(42.0)
      test.expect(decoded.explicit_bool).to.equal(true)
      test.expect(decoded.explicit_str).to.equal("42")
    end)
  end)
end
