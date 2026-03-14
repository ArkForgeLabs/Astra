local serde = require("serde")
require("test")

---@param test Test
---@param roundtrip_test function
---@param test_data table
return function(test, roundtrip_test, test_data)
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
end
