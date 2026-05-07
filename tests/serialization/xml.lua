local serde = require("serde")
require("test")

---@param test Test
---@param _roundtrip_test function
---@param _test_data table
---@param read_sample function
return function(test, _roundtrip_test, _test_data, read_sample)
  test.describe("XML", function()
    test.it("encodes and decodes simple elements", function()
      local data = { name = "John", age = 30 }
      local encoded = serde.xml.encode("person", data)
      test.expect(encoded).to.be.a("string")
      test.expect(encoded).to.match(".*<person>.*")
    end)

    test.it("handles nested elements", function()
      local data = {
        user = {
          name = "John",
          address = {
            street = "123 Main St",
            city = "New York",
          },
        },
      }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.be.a("string")
      test.expect(encoded).to.match(".*<user>.*")
    end)

    test.it("handles arrays", function()
      local data = {
        items = {
          { id = 1, name = "Item 1" },
          { id = 2, name = "Item 2" },
        },
      }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.be.a("string")
    end)

    test.it("handles attributes", function()
      local data = { element = {
        ["@id"] = "123",
        ["@class"] = "test",
      } }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.match('id="123"')
      test.expect(encoded).to.match('class="test"')
    end)

    test.it("handles text content", function()
      local data = { element = "text content" }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.match("text content")
    end)

    test.it("handles special characters", function()
      local data = { text = string.char(60, 62, 38, 34, 39) }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.be.a("string")
    end)

    test.it("handles self-closing tags", function()
      local data = { empty = {} }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.match("/>")
    end)

    test.it("handles nested structures with arrays", function()
      local data = {
        catalog = {
          book = {
            { title = "Book 1", author = "Author 1" },
            { title = "Book 2", author = "Author 2" },
          },
        },
      }
      local encoded = serde.xml.encode("library", data)
      test.expect(encoded).to.be.a("string")
    end)

    test.it("decodes sample.xml from file", function()
      local sample = read_sample("sample.xml")
      local data = serde.xml.decode(sample)
      test.expect(data).to.be.a("table")
    end)

    test.it("handles invalid XML", function()
      test
        .expect(function()
          serde.xml.decode("<open>no close")
        end).to
        .fail()
    end)
  end)

  test.describe("XML - Real World Examples", function()
    test.it("decodes XML with namespaces", function()
      local xml_with_ns = read_sample("namespaces.xml")
      local decoded = serde.xml.decode(xml_with_ns)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes RSS feed", function()
      local rss_feed = read_sample("rss_feed.xml")
      local decoded = serde.xml.decode(rss_feed)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes SOAP message", function()
      local soap_message = read_sample("soap.xml")
      local decoded = serde.xml.decode(soap_message)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes HTML snippet", function()
      local html_snippet = read_sample("html_snippet.xml")
      local decoded = serde.xml.decode(html_snippet)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes XML with CDATA", function()
      local xml_cdata = read_sample("cdata.xml")
      local decoded = serde.xml.decode(xml_cdata)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes complex nested XML", function()
      local complex_xml = read_sample("book_catalog.xml")
      local decoded = serde.xml.decode(complex_xml)
      test.expect(decoded).to.be.truthy()
    end)
  end)
end
