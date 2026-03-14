local serde = require("serde")
require("test")

---@param test Test
---@param roundtrip_test function
---@param test_data table
return function(test, roundtrip_test, test_data)
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
end
