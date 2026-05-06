local serde = require("serde")
require("test")

---@param test Test
---@param _roundtrip_test function
---@param _test_data table
---@param read_sample function
return function(test, _roundtrip_test, _test_data, read_sample)
  test.describe("CSV", function()
    test.it("decodes simple CSV", function()
      local csv_data = "name,age,city\nJohn,30,New York\nJane,25,London"
      local result = serde.csv.decode(csv_data)
      test.expect(result.headers[1]).to.equal("name")
      test.expect(result.body[1][1]).to.equal("John")
      test.expect(result.body[2][3]).to.equal("London")
    end)

    test.it("decodes CSV without headers", function()
      local csv_data = "John,30,New York\nJane,25,London"
      local result = serde.csv.decode(csv_data, { has_headers = false })
      test.expect(#result.body).to.equal(2)
    end)

    test.it("handles quoted values", function()
      local csv_data = 'name,value\n"John, Doe","test, value"'
      local result = serde.csv.decode(csv_data)
      test.expect(result.body[1][1]).to.equal("John, Doe")
      test.expect(result.body[1][2]).to.equal("test, value")
    end)

    test.it("handles different delimiters", function()
      local csv_data = "name;age;city\nJohn;30;New York"
      local options = { delimiter = ";" }
      local result = serde.csv.decode(csv_data, options)
      test.expect(#result.headers).to.equal(3)
      test.expect(#result.body).to.equal(2)
    end)

    test.it("handles multiline values", function()
      local csv_data = [[name,value
"test","line1
line2
line3"]]
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("handles empty values", function()
      local csv_data = "col1,col2,col3\nval1,,val3"
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("handles special characters", function()
      local csv_data = 'name,value\nTest,"quoted"'
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("handles CSV with custom delimiter", function()
      local result = serde.csv.decode("name|age\nJohn|30", { delimiter = "|", has_headers = true })
      test.expect(result.headers[1]).to.equal("name")
      test.expect(result.body[1][2]).to.equal(30)
    end)

    test.it("handles empty CSV gracefully", function()
      local ok = pcall(function()
        serde.csv.decode("")
      end)
      test.expect(ok).to.equal(true)
    end)

    test.it("returns correct headers", function()
      local result = serde.csv.decode("name,age,city\nJohn,30,NYC")
      test.expect(result.headers[1]).to.equal("name")
      test.expect(result.headers[2]).to.equal("age")
      test.expect(result.headers[3]).to.equal("city")
    end)

    test.it("returns correct body rows", function()
      local result = serde.csv.decode("name,age\nJohn,30\nJane,25")
      test.expect(#result.body).to.equal(2)
    end)

    test.it("decodes sample.csv from file", function()
      local sample = read_sample("sample.csv")
      local data = serde.csv.decode(sample)
      test.expect(data.headers[1]).to.equal("name")
      test.expect(#data.body).to.equal(3)
    end)
  end)

  test.describe("CSV - Real World Examples", function()
    test.it("decodes CSV with quoted fields containing commas", function()
      local complex_csv = read_sample("quoted_fields.csv")
      local result = serde.csv.decode(complex_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with tab delimiter", function()
      local tab_csv = read_sample("tab_delimited.csv")
      local options = { delimiter = "\t" }
      local result = serde.csv.decode(tab_csv, options)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with semicolon delimiter", function()
      local semi_csv = read_sample("semicolon.csv")
      local options = { delimiter = ";" }
      local result = serde.csv.decode(semi_csv, options)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with quoted fields containing quotes", function()
      local quoted_csv = read_sample("quoted_quotes.csv")
      local result = serde.csv.decode(quoted_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with empty fields", function()
      local csv_empty = read_sample("empty_fields.csv")
      local result = serde.csv.decode(csv_empty)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with special characters", function()
      local special_csv = read_sample("special_chars.csv")
      local result = serde.csv.decode(special_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with escaped quotes", function()
      local escaped_csv = read_sample("escaped_quotes.csv")
      local result = serde.csv.decode(escaped_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with mixed field types", function()
      local mixed_csv = read_sample("mixed_types.csv")
      local result = serde.csv.decode(mixed_csv)
      test.expect(result).to.be.truthy()
    end)
  end)
end
