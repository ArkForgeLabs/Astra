local serde = require("serde")
require("test")

---@param test Test
---@param _roundtrip_test function
---@param _test_data table
return function(test, _roundtrip_test, _test_data)
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
      local data = { text = "<>&\"'" }
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
  end)

  test.describe("XML - Real World Examples", function()
    test.it("decodes XML with namespaces", function()
      local xml_with_ns = [[
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
        <soap:Body>
          <m:GetPrice xmlns:m="http://www.example.org/stock">
            <m:StockName>IBM</m:StockName>
          </m:GetPrice>
        </soap:Body>
      </soap:Envelope>
    ]]
      local decoded = serde.xml.decode(xml_with_ns)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes RSS feed", function()
      local rss_feed = [[
      <rss version="2.0">
        <channel>
          <title>Example RSS Feed</title>
          <link>https://example.com</link>
          <description>An example RSS feed</description>
          <item>
            <title>First Article</title>
            <link>https://example.com/article1</link>
            <description>This is the first article</description>
            <pubDate>Mon, 08 Mar 2023 15:45:00 GMT</pubDate>
            <guid>https://example.com/article1</guid>
          </item>
          <item>
            <title>Second Article</title>
            <link>https://example.com/article2</link>
            <description>This is the second article</description>
            <pubDate>Tue, 09 Mar 2023 10:30:00 GMT</pubDate>
            <guid>https://example.com/article2</guid>
          </item>
        </channel>
      </rss>
    ]]
      local decoded = serde.xml.decode(rss_feed)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes SOAP message", function()
      local soap_message = [[
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://www.example.org/webservices/">
        <soapenv:Header/>
        <soapenv:Body>
          <web:GetCountryCitizens>
            <web:Country>Italy</web:Country>
          </web:GetCountryCitizens>
        </soapenv:Body>
      </soapenv:Envelope>
    ]]
      local decoded = serde.xml.decode(soap_message)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes HTML snippet", function()
      local html_snippet = [[
      <html>
        <head>
          <title>Test Page</title>
        </head>
        <body>
          <h1>Welcome</h1>
          <p>This is a paragraph with <strong>bold</strong> text.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
            <li>Item 3</li>
          </ul>
        </body>
      </html>
    ]]
      local decoded = serde.xml.decode(html_snippet)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes XML with CDATA", function()
      local xml_cdata =
        '<root>\n        <script><![CDATA[function test() { console.log("Hello, World!"); }]]></script>\n        <data><![CDATA[This is some data with special chars]]></data>\n      </root>\n    '
      local decoded = serde.xml.decode(xml_cdata)
      test.expect(decoded).to.be.truthy()
    end)

    test.it("decodes complex nested XML", function()
      local complex_xml = [[
      <catalog>
        <book id="bk101">
          <author>Gambardella, Matthew</author>
          <title>XML Developer's Guide</title>
          <genre>Computer</genre>
          <price>44.95</price>
          <publish_date>2000-10-01</publish_date>
          <description>
            An in-depth look at creating applications
            with XML and the .NET platform.
          </description>
        </book>
        <book id="bk102">
          <author>Ralls, Kim</author>
          <title>Midnight Rain</title>
          <genre>Fantasy</genre>
          <price>5.95</price>
          <publish_date>2000-12-16</publish_date>
          <description>
            A former architect battles corporate zombies,
            an evil sorceress, and her own childhood to become queen
            of the world.
          </description>
        </book>
      </catalog>
    ]]
      local decoded = serde.xml.decode(complex_xml)
      test.expect(decoded).to.be.truthy()
    end)
  end)

  -- ============================================================================
  -- CSV TESTS
  -- ============================================================================
  test.describe("CSV", function()
    test.it("decodes simple CSV", function()
      local csv_data = "name,age,city\nJohn,30,New York\nJane,25,London"
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("decodes CSV with headers", function()
      local csv_data = "name,age,city\nJohn,30,New York\nJane,25,London"
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("decodes CSV without headers", function()
      local csv_data = "John,30,New York\nJane,25,London"
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("handles quoted values", function()
      local csv_data = 'name,value\n"John, Doe","test, value"'
      local result = serde.csv.decode(csv_data)
      test.expect(result).to.be.a("table")
    end)

    test.it("handles different delimiters", function()
      local csv_data = "name;age;city\nJohn;30;New York"
      local options = { delimiter = ";" }
      local result = serde.csv.decode(csv_data, options)
      test.expect(result).to.be.a("table")
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
  end)

  test.describe("CSV - Real World Examples", function()
    test.it("decodes CSV with quoted fields containing commas", function()
      local complex_csv = [[
      name,description,price,category
      "Product A","This is a product, with a comma, and more text","$10.99","Electronics"
      "Product B","Another product, with more commas, and quotes, and special chars","$20.50","Clothing"
      "Product C","Simple product without commas","$5.99","Books"
    ]]
      local result = serde.csv.decode(complex_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with tab delimiter", function()
      local tab_csv = "name\tage\tcity\nJohn\t30\tNew York\nJane\t25\tLondon"
      local options = { delimiter = "\t" }
      local result = serde.csv.decode(tab_csv, options)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with semicolon delimiter", function()
      local semi_csv = "name;age;city\nJohn;30;New York\nJane;25;London"
      local options = { delimiter = ";" }
      local result = serde.csv.decode(semi_csv, options)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with quoted fields containing quotes", function()
      local quoted_csv = [[
      name,value
      "Product A","Value with \"quoted\" text"
      "Product B","Another \"quoted\" value"
    ]]
      local result = serde.csv.decode(quoted_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with empty fields", function()
      local csv_empty = [[
      col1,col2,col3,col4
      "val1",,"val3",
      ,"val2",,"val4"
      "val5","val6",,
    ]]
      local result = serde.csv.decode(csv_empty)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with special characters", function()
      local special_csv = [[
      name,description
      "Test 1","Line 1\nLine 2\nLine 3"
      "Test 2","Special: @#$%^&*()"
      "Test 3","Unicode: 世界 🌍"
    ]]
      local result = serde.csv.decode(special_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with escaped quotes", function()
      local escaped_csv = [[
      name,value
      "Product A","Value with \"escaped\" quotes"
      "Product B","Another \"example\""
    ]]
      local result = serde.csv.decode(escaped_csv)
      test.expect(result).to.be.truthy()
    end)

    test.it("decodes CSV with mixed field types", function()
      local mixed_csv = [[
      id,name,price,in_stock,rating
      1,"Product A",19.99,true,4.5
      2,"Product B",29.99,false,3.8
      3,"Product C",9.99,true,4.2
    ]]
      local result = serde.csv.decode(mixed_csv)
      test.expect(result).to.be.truthy()
    end)
  end)
end
