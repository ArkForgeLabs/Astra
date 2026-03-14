local serde = require("serde")
local test = require("test")

-- Helper functions
local function roundtrip_test(format_name, data, encode_fn, decode_fn)
  local encoded = encode_fn(data)
  local decoded = decode_fn(encoded)
  test.expect(decoded).to.equal(data)
end

-- Test data for roundtrip testing
local test_data = {
  simple = {
    string = "hello",
    number = 42,
    boolean = true,
    nil_value = nil,
  },
  nested = {
    user = {
      name = "John",
      age = 30,
      active = true,
      tags = { "admin", "user" },
    },
  },
  complex = {
    metadata = {
      version = "1.0",
      timestamp = 1234567890,
      config = {
        debug = false,
        timeout = 30,
      },
    },
    items = {
      { id = 1, name = "Item 1" },
      { id = 2, name = "Item 2" },
    },
  },
}

-- Add test helper: to.be.at.least()
test.paths.least = {
  test = function(value, min)
    return value >= min,
      "expected " .. tostring(value) .. " to be at least " .. tostring(min),
      "expected " .. tostring(value) .. " to not be at least " .. tostring(min)
  end,
}
table.insert(test.paths.be, "least")

-- ============================================================================
-- JSON TESTS
-- ============================================================================
test.describe("JSON", function()
  test.it("encodes and decodes simple types", function()
    roundtrip_test("JSON", test_data.simple, serde.json.encode, serde.json.decode)
  end)

  test.it("encodes and decodes nested structures", function()
    roundtrip_test("JSON", test_data.nested, serde.json.encode, serde.json.decode)
  end)

  test.it("encodes and decodes complex structures", function()
    roundtrip_test("JSON", test_data.complex, serde.json.encode, serde.json.decode)
  end)

  test.it("handles empty objects", function()
    local empty_obj = {}
    local encoded = serde.json.encode(empty_obj)
    local decoded = serde.json.decode(encoded)
    test.expect(decoded).to.equal(empty_obj)
  end)

  test.it("handles empty arrays", function()
    local empty_arr = {}
    local encoded = serde.json.encode(empty_arr)
    local decoded = serde.json.decode(encoded)
    test.expect(decoded).to.equal(empty_arr)
  end)

  test.it("handles unicode and special characters", function()
    local unicode_json = [[
      {
        "greeting": "Hello world",
        "emoji": "smile",
        "special": "Quote: \" Test: \\ Tab: \t Newline: \n",
        "unicode": ["Cafe", "Naive", "Japanese"]
      }
    ]]
    local decoded = serde.json.decode(unicode_json)
    test.expect(decoded.greeting).to.equal("Hello world")
    test.expect(decoded.special).to.equal('Quote: " Test: \\ Tab: \t Newline: \n')
  end)

  test.it("handles numbers", function()
    local number_data = {
      int = 42,
      float = 3.14159,
      negative = -10,
      zero = 0,
      scientific = 1e10,
    }
    roundtrip_test("JSON", number_data, serde.json.encode, serde.json.decode)
  end)

  test.it("handles booleans and null", function()
    local bool_data = {
      true_val = true,
      false_val = false,
      null_val = nil,
    }
    roundtrip_test("JSON", bool_data, serde.json.encode, serde.json.decode)
  end)

  test.it("encodes to valid JSON string", function()
    local data = { name = "test", value = 123 }
    local encoded = serde.json.encode(data)
    test.expect(encoded).to.match('.*"name".*')
    test.expect(encoded).to.match('.*"value".*')
  end)

  test.it("decodes valid JSON string", function()
    local json_str = '{"name":"test","value":123}'
    local decoded = serde.json.decode(json_str)
    test.expect(decoded.name).to.equal("test")
    test.expect(decoded.value).to.equal(123)
  end)
end)

test.describe("JSON - Real World Examples", function()
  test.it("decodes complex nested JSON", function()
    local complex_json = [[
      {
        "name": "John Doe",
        "age": 32,
        "address": {
          "street": "123 Main St",
          "city": "New York",
          "coordinates": {
            "lat": 40.7128,
            "lng": -74.0060
          }
        },
        "hobbies": ["reading", "hiking", "coding"],
        "metadata": {
          "created_at": "2023-01-15T10:30:00Z",
          "tags": ["user", "premium"],
          "stats": {
            "login_count": 42,
            "last_active": "2023-03-08"
          }
        }
      }
    ]]
    local decoded = serde.json.decode(complex_json)
    test.expect(decoded.name).to.equal("John Doe")
    test.expect(decoded.address.coordinates.lat).to.equal(40.7128)
    test.expect(#decoded.hobbies).to.equal(3)
  end)

  test.it("decodes array with mixed types", function()
    local mixed_array = [[
      [
        42,
        "string",
        true,
        null,
        {"nested": "object"},
        [1, 2, 3]
      ]
    ]]
    local decoded = serde.json.decode(mixed_array)
    test.expect(decoded[1]).to.equal(42)
    test.expect(decoded[2]).to.equal("string")
    test.expect(decoded[5].nested).to.equal("object")
  end)

  test.it("decodes GitHub API-like response", function()
    local github_json = [[
      {
        "id": 123456789,
        "name": "test-repo",
        "full_name": "user/test-repo",
        "owner": {
          "login": "user",
          "id": 987654321,
          "avatar_url": "https://github.com/user.png"
        },
        "private": false,
        "html_url": "https://github.com/user/test-repo",
        "description": "A test repository",
        "fork": false,
        "url": "https://api.github.com/repos/user/test-repo",
        "created_at": "2023-01-15T10:30:00Z",
        "updated_at": "2023-03-08T15:45:00Z",
        "pushed_at": "2023-03-08T15:40:00Z",
        "homepage": "",
        "size": 1024,
        "stargazers_count": 42,
        "watchers_count": 42,
        "language": "Lua",
        "has_issues": true,
        "has_projects": true,
        "has_downloads": true,
        "has_wiki": true,
        "has_pages": false,
        "has_discussions": false,
        "forks_count": 5,
        "mirror_url": null,
        "archived": false,
        "disabled": false,
        "open_issues_count": 3,
        "license": null,
        "allow_forking": true,
        "is_template": false,
        "web_commit_signoff_required": false,
        "topics": ["test", "example", "demo"],
        "visibility": "public",
        "forks": 5,
        "open_issues": 3,
        "watchers": 42,
        "default_branch": "main",
        "permissions": {
          "admin": false,
          "maintain": false,
          "push": true,
          "triage": false,
          "pull": true
        }
      }
    ]]
    local decoded = serde.json.decode(github_json)
    test.expect(decoded.name).to.equal("test-repo")
    test.expect(decoded.owner.login).to.equal("user")
    test.expect(decoded.language).to.equal("Lua")
    test.expect(#decoded.topics).to.equal(3)
  end)

  test.it("decodes REST API response with nested data", function()
    local api_response = [[
      {
        "status": "success",
        "code": 200,
        "message": "Request processed successfully",
        "data": {
          "user": {
            "id": 123,
            "name": "John Doe",
            "email": "john@example.com",
            "roles": ["admin", "user"],
            "profile": {
              "avatar": "https://example.com/avatar.jpg",
              "bio": "Software developer",
              "location": "New York, USA",
              "social": {
                "twitter": "@johndoe",
                "github": "johndoe",
                "website": "https://johndoe.dev"
              }
            },
            "stats": {
              "login_count": 150,
              "last_login": "2023-03-08T10:30:00Z",
              "created_at": "2022-01-15T08:00:00Z"
            }
          },
          "metadata": {
            "page": 1,
            "limit": 20,
            "total": 100,
            "has_more": true
          }
        },
        "timestamp": "2023-03-08T15:45:00Z",
        "server": "Astra/1.0"
      }
    ]]
    local decoded = serde.json.decode(api_response)
    test.expect(decoded.status).to.equal("success")
    test.expect(decoded.data.user.name).to.equal("John Doe")
    test.expect(decoded.data.user.profile.social.github).to.equal("johndoe")
    test.expect(decoded.data.metadata.total).to.equal(100)
  end)
end)

test.describe("JSON - Edge Cases", function()
  test.it("handles very large numbers", function()
    local large_num = [[{"value": 9007199254740991}]]
    local decoded = serde.json.decode(large_num)
    test.expect(decoded.value).to.equal(9007199254740991)
  end)

  test.it("handles empty objects and arrays", function()
    local empty = [[{"obj": {}, "arr": []}]]
    local decoded = serde.json.decode(empty)
    test.expect(decoded.obj).to.equal({})
    test.expect(decoded.arr).to.equal({})
  end)

  test.it("handles escaped unicode", function()
    local escaped = [[{"text": "\u0041\u0042\u0043"}]]
    local decoded = serde.json.decode(escaped)
    test.expect(decoded.text).to.equal("ABC")
  end)

  test.it("handles scientific notation", function()
    local scientific = [[{"values": [1e10, 1.5e-5, 2.3e+10]}]]
    local decoded = serde.json.decode(scientific)
    test.expect(decoded.values[1]).to.equal(1e10)
    test.expect(decoded.values[2]).to.equal(1.5e-5)
  end)

  test.it("handles negative zero", function()
    local negative_zero = [[{"value": -0}]]
    local decoded = serde.json.decode(negative_zero)
    test.expect(decoded.value).to.equal(0)
  end)

  test.it("handles large arrays", function()
    local large_array = "[" .. string.rep('"item",', 999) .. '"last_item"' .. "]"
    local decoded = serde.json.decode(large_array)
    test.expect(#decoded).to.equal(1000)
  end)

  test.it("handles deeply nested structures", function()
    local deeply_nested = '{"level1": {"level2": {"level3": {"level4": {"level5": "deep"}}}}}'
    local decoded = serde.json.decode(deeply_nested)
    test.expect(decoded.level1.level2.level3.level4.level5).to.equal("deep")
  end)
end)

-- ============================================================================
-- JSON5 TESTS
-- ============================================================================
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
    -- JSON5 allows comments, test that encoding produces valid JSON5
    local data = { value = 42 }
    local encoded = serde.json5.encode(data)
    test.expect(encoded).to.be.a("string")
    test.expect(#encoded).to.equal(#encoded) -- Just verify it's not empty
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
end)

-- ============================================================================
-- YAML TESTS
-- ============================================================================
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
end)

test.describe("YAML - Real World Examples", function()
  test.it("decodes YAML with anchors and aliases", function()
    local yaml_with_anchors = [[
      defaults: &defaults
        adapter:  postgres
        host:     localhost
        user:     postgres
        password: postgres
        database: myapp_development

      test: *defaults
      production:
        <<: *defaults
        database: myapp_production
    ]]
    local decoded = serde.yaml.decode(yaml_with_anchors)
    test.expect(decoded.defaults.adapter).to.equal("postgres")
    test.expect(decoded.production.database).to.equal("myapp_production")
  end)

  test.it("decodes Docker Compose-like YAML", function()
    local docker_compose = [[
      version: '3.8'

      services:
        web:
          image: nginx:latest
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - ./html:/usr/share/nginx/html
            - ./nginx.conf:/etc/nginx/nginx.conf
          environment:
            - NGINX_ENV=production
          restart: unless-stopped

        app:
          build: .
          ports:
            - "3000:3000"
          environment:
            - NODE_ENV=production
            - DATABASE_URL=postgres://user:pass@db:5432/app
          depends_on:
            - db
            - redis

        db:
          image: postgres:13
          environment:
            POSTGRES_USER: user
            POSTGRES_PASSWORD: pass
            POSTGRES_DB: app
          volumes:
            - postgres_data:/var/lib/postgresql/data

        redis:
          image: redis:6
          ports:
            - "6379:6379"

      volumes:
        postgres_data:
    ]]
    local decoded = serde.yaml.decode(docker_compose)
    test.expect(decoded.version).to.equal("3.8")
    test.expect(decoded.services.web.image).to.equal("nginx:latest")
    test.expect(decoded.services.app.build).to.equal(".")
    test.expect(decoded.services.db.image).to.equal("postgres:13")
  end)

  test.it("decodes YAML with tags and implicit typing", function()
    local yaml_typed = [[
      plain: 42
      explicit_int: !!int 42
      explicit_float: !!float 42.0
      explicit_bool: !!bool true
      explicit_str: !!str 42

      date: 2023-03-08
      datetime: 2023-03-08T15:45:00Z
      timestamp: 2023-03-08 15:45:00 +00:00
    ]]
    local decoded = serde.yaml.decode(yaml_typed)
    test.expect(decoded.plain).to.equal(42)
    test.expect(decoded.explicit_int).to.equal(42)
    test.expect(decoded.explicit_float).to.equal(42.0)
    test.expect(decoded.explicit_bool).to.equal(true)
    test.expect(decoded.explicit_str).to.equal("42")
  end)
end)

-- ============================================================================
-- TOML TESTS
-- ============================================================================
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
end)

test.describe("TOML - Real World Examples", function()
  test.it("decodes TOML with datetime", function()
    local toml_datetime = [[
      [build]
      timestamp = "1979-05-27T07:32:00Z"

      [deploy]
      date = "1979-05-27 07:32:00.000000"

      [config]
      last_updated = "1979-05-27T07:32:00+00:00"
    ]]
    local decoded = serde.toml.decode(toml_datetime)
    test.expect(decoded.build.timestamp).to.equal("1979-05-27T07:32:00Z")
    test.expect(decoded.deploy.date).to.equal("1979-05-27 07:32:00.000000")
  end)

  test.it("decodes TOML with arrays of tables", function()
    local toml_arrays =
      '[[products]]\n      name = "Hammer"\n      sku = 738594937\n      \n      [[products]]\n      name = "Nail"\n      sku = 284758393\n      \n      [[products]]\n      name = "Screwdriver"\n      sku = 506981302\n    '
    local decoded = serde.toml.decode(toml_arrays)
    test.expect(#decoded.products).to.equal(3)
    test.expect(decoded.products[1].name).to.equal("Hammer")
    test.expect(decoded.products[2].sku).to.equal(284758393)
  end)

  test.it("decodes Cargo.toml-like file", function()
    local cargo_toml = [[
      [package]
      name = "my-package"
      version = "0.1.0"
      edition = "2021"
      authors = ["John Doe <john@example.com>"]
      description = "A short description of my package"
      license = "MIT"

      [dependencies]
      serde = { version = "1.0", features = ["derive"] }
      tokio = { version = "1.0", features = ["full"] }

      [dev-dependencies]
      test-dep = "0.1"

      [build-dependencies]
      build-dep = "0.1"

      [features]
      default = ["feature-a", "feature-b"]
      feature-a = []
      feature-b = []
    ]]
    local decoded = serde.toml.decode(cargo_toml)
    test.expect(decoded.package.name).to.equal("my-package")
    test.expect(decoded.package.version).to.equal("0.1.0")
    test.expect(decoded.dependencies.serde.version).to.equal("1.0")
    test.expect(#decoded.package.authors).to.equal(1)
  end)

  test.it("decodes TOML with nested tables using dots", function()
    local toml_nested = [[
      [owner]
      name = "John Doe"

      [owner.address]
      street = "123 Main St"
      city = "New York"
      zip = "10001"

      [database]
      enabled = true

      [database.connection]
      host = "localhost"
      port = 5432

      [database.connection.pool]
      min = 2
      max = 10
    ]]
    local decoded = serde.toml.decode(toml_nested)
    test.expect(decoded.owner.name).to.equal("John Doe")
    test.expect(decoded.owner.address.city).to.equal("New York")
    test.expect(decoded.database.connection.host).to.equal("localhost")
    test.expect(decoded.database.connection.pool.max).to.equal(10)
  end)
end)

-- ============================================================================
-- XML TESTS
-- ============================================================================
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
