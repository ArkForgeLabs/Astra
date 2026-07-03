local serde = require("serde")
require("test")

---@param test Test
---@param _roundtrip_test function
---@param _test_data table
---@param read_sample function
return function(test, _roundtrip_test, _test_data, read_sample)
  test.describe("XML", function()
    test.it("encodes and decodes simple elements with root tag", function()
      local data = { name = "John", age = 30 }
      local encoded = serde.xml.encode("person", data)
      test.expect(encoded).to.be.a("string")
      test.expect(encoded).to.match(".*<person>.*")
      test.expect(encoded).to.match(".*<name>John</name>.*")
      test.expect(encoded).to.match(".*<age>30</age>.*")
    end)

    test.it("decode wraps text content in $text field", function()
      local data = { name = "John", age = 30 }
      local encoded = serde.xml.encode("person", data)
      local decoded = serde.xml.decode(encoded)
      test.expect(decoded.name).to.be.a("table")
      test.expect(decoded.name["$text"]).to.equal("John")
      test.expect(decoded.age["$text"]).to.equal("30")
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
      test.expect(encoded).to.match(".*<name>John</name>.*")
      test.expect(encoded).to.match(".*<street>123 Main St</street>.*")
      test.expect(encoded).to.match(".*<city>New York</city>.*")
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
      test.expect(encoded).to.match(".*<id>1</id>.*")
      test.expect(encoded).to.match(".*<name>Item 1</name>.*")
      test.expect(encoded).to.match(".*<id>2</id>.*")
      test.expect(encoded).to.match(".*<name>Item 2</name>.*")
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

    test.it("handles special characters with XML escaping", function()
      local data = { text = "<>&\"'" }
      local encoded = serde.xml.encode("root", data)
      test.expect(encoded).to.be.a("string")
      test.expect(encoded).to.match(".*&lt;&gt;&amp;.*")
    end)

    test.it("handles self-closing tags for empty tables", function()
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
      test.expect(encoded).to.match(".*<title>Book 1</title>.*")
      test.expect(encoded).to.match(".*<title>Book 2</title>.*")
      test.expect(encoded).to.match(".*<author>Author 1</author>.*")
      test.expect(encoded).to.match(".*<author>Author 2</author>.*")
    end)

    test.it("decodes sample.xml from file", function()
      local sample = read_sample("sample.xml")
      local data = serde.xml.decode(sample)
      test.expect(data).to.be.a("table")
      test.expect(data.name["$text"]).to.equal("John Doe")
      test.expect(data.age["$text"]).to.equal("30")
      test.expect(data.address.city["$text"]).to.equal("Anytown")
      test.expect(data.address.street["$text"]).to.equal("123 Main St")
      test.expect(data.metadata.created["$text"]).to.equal("2023-01-15")
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
      test.expect(decoded).to.be.a("table")
      test.expect(decoded["@xmlns:soap"]).to.equal("http://www.w3.org/2003/05/soap-envelope")
      test.expect(decoded.Body).to.be.a("table")
      test.expect(decoded.Body.GetPrice).to.be.a("table")
    end)

    test.it("decodes RSS feed", function()
      local rss_feed = read_sample("rss_feed.xml")
      local decoded = serde.xml.decode(rss_feed)
      test.expect(decoded).to.be.a("table")
      test.expect(decoded["@version"]).to.equal("2.0")
      test.expect(decoded.channel).to.be.a("table")
      test.expect(decoded.channel.title["$text"]).to.equal("Example RSS Feed")
      test.expect(decoded.channel.description["$text"]).to.equal("An example RSS feed")
      test.expect(decoded.channel.link["$text"]).to.equal("https://example.com")
      test.expect(decoded.channel.item).to.be.a("table")
    end)

    test.it("decodes SOAP message", function()
      local soap_message = read_sample("soap.xml")
      local decoded = serde.xml.decode(soap_message)
      test.expect(decoded).to.be.a("table")
      test.expect(decoded.Body).to.be.a("table")
      test.expect(decoded.Body.GetCountryCitizens).to.be.a("table")
      test.expect(decoded.Body.GetCountryCitizens.Country["$text"]).to.equal("Italy")
    end)

    test.it("decodes HTML snippet", function()
      local html_snippet = read_sample("html_snippet.xml")
      local decoded = serde.xml.decode(html_snippet)
      test.expect(decoded).to.be.a("table")
      test.expect(decoded.head).to.be.a("table")
      test.expect(decoded.head.title["$text"]).to.equal("Test Page")
      test.expect(decoded.body).to.be.a("table")
      test.expect(decoded.body.h1["$text"]).to.equal("Welcome")
    end)

    test.it("decodes XML with CDATA", function()
      local xml_cdata = read_sample("cdata.xml")
      local decoded = serde.xml.decode(xml_cdata)
      test.expect(decoded).to.be.a("table")
      test.expect(decoded.script).to.be.a("table")
      local script_text = decoded.script["$text"]
      test.expect(script_text).to.match(".*log.*")
      test.expect(decoded.data["$text"]).to.equal("This is some data with special chars")
    end)

    test.it("decodes complex nested XML", function()
      local complex_xml = read_sample("book_catalog.xml")
      local decoded = serde.xml.decode(complex_xml)
      test.expect(decoded).to.be.a("table")
      test.expect(decoded.book).to.be.a("table")
      test.expect(decoded.book["@id"]).to.be.a("string")
      test.expect(decoded.book.title["$text"]).to.be.a("string")
      test.expect(decoded.book.author["$text"]).to.be.a("string")
      test.expect(#decoded.book.title["$text"]).to.be.least(1)
    end)
  end)
end
