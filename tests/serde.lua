local fs = require("fs")
local serde = require("serde")
local test = require("test")

local describe = test.describe
local it = test.it
local expect = test.expect

local function read_sample(name)
  return fs.read_file("tests/serialization_samples/" .. name)
end

local test_data = {
  name = "John Doe",
  age = 30,
  is_student = false,
  courses = { "Math", "Science", "History" },
  address = {
    street = "123 Main St",
    city = "Anytown",
    zipcode = "12345",
  },
  metadata = {
    created = "2023-01-15",
    updated = "2023-12-01",
  },
}

describe("Serde Module", function()
  describe("JSON", function()
    it("encodes a table to JSON string", function()
      local result = serde.json.encode({ hello = "world" })
      expect(result).to.be.a("string")
      expect(result).to.match("hello")
    end)

    it("decodes a JSON string to table", function()
      local result = serde.json.decode('{"hello":"world"}')
      expect(result).to.be.a("table")
      expect(result.hello).to.equal("world")
    end)

    it("round-trip preserves data", function()
      local encoded = serde.json.encode(test_data)
      local decoded = serde.json.decode(encoded)
      expect(decoded.name).to.equal(test_data.name)
      expect(decoded.age).to.equal(test_data.age)
      expect(decoded.is_student).to.equal(test_data.is_student)
    end)

    it("decodes sample.json from file", function()
      local sample = read_sample("sample.json")
      local data = serde.json.decode(sample)
      expect(data.name).to.equal("John Doe")
      expect(data.age).to.equal(30)
      expect(data.address.city).to.equal("Anytown")
    end)

    it("handles invalid JSON", function()
      expect(function()
        serde.json.decode("{invalid json}")
      end).to.fail()
    end)

    it("handles empty object", function()
      local encoded = serde.json.encode({})
      local decoded = serde.json.decode(encoded)
      expect(decoded).to.be.a("table")
    end)

    it("handles arrays", function()
      local encoded = serde.json.encode({ 1, 2, 3 })
      local decoded = serde.json.decode(encoded)
      expect(decoded[1]).to.equal(1)
      expect(decoded[2]).to.equal(2)
      expect(decoded[3]).to.equal(3)
    end)
  end)

  describe("JSON5", function()
    it("encodes a table to JSON5 string", function()
      local result = serde.json5.encode({ hello = "world" })
      expect(result).to.be.a("string")
      expect(result).to.match("hello")
    end)

    it("decodes a JSON5 string to table", function()
      local result = serde.json5.decode('{hello:"world"}')
      expect(result).to.be.a("table")
      expect(result.hello).to.equal("world")
    end)

    it("round-trip preserves data", function()
      local encoded = serde.json5.encode(test_data)
      local decoded = serde.json5.decode(encoded)
      expect(decoded.name).to.equal(test_data.name)
      expect(decoded.age).to.equal(test_data.age)
      expect(decoded.courses[1]).to.equal("Math")
    end)

    it("decodes sample.json5 from file", function()
      local sample = read_sample("sample.json5")
      local data = serde.json5.decode(sample)
      expect(data.name).to.equal("John Doe")
      expect(data.metadata.created).to.equal("2023-01-15")
    end)

    it("handles invalid JSON5", function()
      expect(function()
        serde.json5.decode("{invalid::}")
      end).to.fail()
    end)
  end)

  describe("YAML", function()
    it("encodes a table to YAML string", function()
      local result = serde.yaml.encode({ hello = "world" })
      expect(result).to.be.a("string")
    end)

    it("decodes a YAML string to table", function()
      local result = serde.yaml.decode("hello: world")
      expect(result).to.be.a("table")
      expect(result.hello).to.equal("world")
    end)

    it("round-trip preserves data", function()
      local encoded = serde.yaml.encode(test_data)
      local decoded = serde.yaml.decode(encoded)
      expect(decoded.name).to.equal(test_data.name)
      expect(decoded.age).to.equal(test_data.age)
      expect(decoded.is_student).to.equal(test_data.is_student)
    end)

    it("decodes sample.yaml from file", function()
      local sample = read_sample("sample.yaml")
      local data = serde.yaml.decode(sample)
      expect(data.name).to.equal("John Doe")
      expect(data.age).to.equal(30)
      expect(data.address.street).to.equal("123 Main St")
    end)

    it("handles invalid YAML", function()
      expect(function()
        serde.yaml.decode(": invalid")
      end).to.fail()
    end)
  end)

  describe("TOML", function()
    it("encodes a table to TOML string", function()
      local result = serde.toml.encode({ hello = "world" })
      expect(result).to.be.a("string")
    end)

    it("decodes a TOML string to table", function()
      local result = serde.toml.decode('hello = "world"')
      expect(result).to.be.a("table")
      expect(result.hello).to.equal("world")
    end)

    it("round-trip preserves data", function()
      local encoded = serde.toml.encode(test_data)
      local decoded = serde.toml.decode(encoded)
      expect(decoded.name).to.equal(test_data.name)
      expect(decoded.age).to.equal(test_data.age)
      expect(decoded.is_student).to.equal(test_data.is_student)
    end)

    it("decodes sample.toml from file", function()
      local sample = read_sample("sample.toml")
      local data = serde.toml.decode(sample)
      expect(data.name).to.equal("John Doe")
      expect(data.address.street).to.equal("123 Main St")
    end)

    it("handles sections", function()
      local toml_str = '[server]\nhost = "localhost"\nport = 8080\n'
      local data = serde.toml.decode(toml_str)
      expect(data.server).to.be.a("table")
      expect(data.server.host).to.equal("localhost")
    end)

    it("handles invalid TOML", function()
      expect(function()
        serde.toml.decode("= invalid")
      end).to.fail()
    end)
  end)

  describe("INI", function()
    it("encodes a table to INI string", function()
      local result = serde.ini.encode({ key = "value" })
      expect(result).to.be.a("string")
    end)

    it("decodes an INI string to table", function()
      local result = serde.ini.decode("key = value")
      expect(result).to.be.a("table")
    end)

    it("decodes sample.ini from file", function()
      local sample = read_sample("sample.ini")
      local data = serde.ini.decode(sample)
      expect(data).to.be.a("table")
    end)

    it("handles sections", function()
      local ini_str = "[section]\nkey = value\n"
      local data = serde.ini.decode(ini_str)
      expect(data.section).to.be.a("table")
    end)

    it("handles invalid INI gracefully", function()
      local ok = pcall(function()
        serde.ini.decode("")
      end)
      expect(ok).to.equal(true)
    end)
  end)

  describe("XML", function()
    it("encodes a table to XML string with root", function()
      local result = serde.xml.encode("data", { name = "test" })
      expect(result).to.be.a("string")
      expect(result).to.match("data")
    end)

    it("decodes an XML string to table", function()
      local result = serde.xml.decode("<data><name>test</name></data>")
      expect(result).to.be.a("table")
    end)

    it("decodes sample.xml from file", function()
      local sample = read_sample("sample.xml")
      local data = serde.xml.decode(sample)
      expect(data).to.be.a("table")
    end)

    it("round-trip preserves nested structure", function()
      local data = { person = { name = "Alice", age = 25 } }
      local encoded = serde.xml.encode("root", data)
      local decoded = serde.xml.decode(encoded)
      expect(decoded).to.be.a("table")
    end)

    it("handles invalid XML", function()
      expect(function()
        serde.xml.decode("<open>no close")
      end).to.fail()
    end)
  end)

  describe("CSV", function()
    it("decodes a CSV string to structured table", function()
      local result = serde.csv.decode("name,age\nJohn,30\nJane,25")
      expect(result).to.be.a("table")
      expect(result.body).to.be.a("table")
      expect(result.headers).to.be.a("table")
    end)

    it("returns correct headers", function()
      local result = serde.csv.decode("name,age,city\nJohn,30,NYC")
      expect(result.headers[1]).to.equal("name")
      expect(result.headers[2]).to.equal("age")
      expect(result.headers[3]).to.equal("city")
    end)

    it("returns correct body rows", function()
      local result = serde.csv.decode("name,age\nJohn,30\nJane,25")
      expect(#result.body).to.equal(2)
    end)

    it("decodes sample.csv from file", function()
      local sample = read_sample("sample.csv")
      local data = serde.csv.decode(sample)
      expect(data.headers[1]).to.equal("name")
      expect(#data.body).to.equal(3)
    end)

    it("handles CSV with custom delimiter", function()
      local result = serde.csv.decode("name|age\nJohn|30", { delimiter = "|", has_headers = true })
      expect(result.headers[1]).to.equal("name")
      expect(result.body[1][2]).to.equal(30)
    end)

    it("handles CSV without headers", function()
      local result = serde.csv.decode("John,30\nJane,25", { has_headers = false })
      expect(#result.body).to.equal(2)
    end)

    it("handles empty CSV gracefully", function()
      local ok = pcall(function()
        serde.csv.decode("")
      end)
      expect(ok).to.equal(true)
    end)
  end)

  describe("Edge Cases", function()
    it("encodes special characters in JSON", function()
      local data = { text = 'hello\nworld\t"quoted"' }
      local encoded = serde.json.encode(data)
      local decoded = serde.json.decode(encoded)
      expect(decoded.text).to.equal(data.text)
    end)

    it("encodes nested empty tables in JSON", function()
      local data = { nested = { empty = {} } }
      local encoded = serde.json.encode(data)
      local decoded = serde.json.decode(encoded)
      expect(decoded.nested.empty).to.be.a("table")
    end)

    it("encodes booleans and numbers correctly in JSON", function()
      local data = { t = true, f = false, n = 42, pi = 3.14 }
      local encoded = serde.json.encode(data)
      local decoded = serde.json.decode(encoded)
      expect(decoded.t).to.equal(true)
      expect(decoded.f).to.equal(false)
      expect(decoded.n).to.equal(42)
    end)

    it("encodes array of mixed types in YAML", function()
      local data = { items = { 1, "two", true } }
      local encoded = serde.yaml.encode(data)
      local decoded = serde.yaml.decode(encoded)
      expect(decoded.items[1]).to.equal(1)
      expect(decoded.items[2]).to.equal("two")
      expect(decoded.items[3]).to.equal(true)
    end)
  end)
end)
