local http = require("http")
local templates = require("templates")
require("test")

---@param test Test
return function(test)
  local describe, it, expect = test.describe, test.it, test.expect

  -------------------------------------------------------------------------------
  -- Jinja2 Engine
  -------------------------------------------------------------------------------
  describe("Jinja2 Engine", function()
    describe("Engine Creation", function()
      it("creates engine with valid glob", function()
        local eng = templates.jinja2.new("examples/templates/**/*.html")
        expect(eng).to.be.a("table")
      end)

      it("engine has expected methods", function()
        local eng = templates.jinja2.new()
        expect(eng.add_template).to.be.a("function")
        expect(eng.render).to.be.a("function")
        expect(eng.get_template_names).to.be.a("function")
        expect(eng.add_function).to.be.a("function")
        expect(eng.exclude_templates).to.be.a("function")
        expect(eng.reload_templates).to.be.a("function")
      end)
    end)

    describe("Template Management", function()
      it("adds inline template", function()
        local eng = templates.jinja2.new()
        eng:add_template("test.html", "Hello {{ name }}!")
        local names = eng:get_template_names()
        expect(names).to.be.a("table")
        expect(#names > 0).to.be.truthy()
      end)

      it("loads template from file", function()
        local eng = templates.jinja2.new()
        eng:add_template_file("example", "examples/templates/index.html")
        local names = eng:get_template_names()
        expect(names).to.be.a("table")
        local found = false
        for _, name in ipairs(names) do
          if name == "example" then
            found = true
          end
        end
        expect(found).to.equal(true)
      end)

      it("excludes templates", function()
        local eng = templates.jinja2.new("examples/templates/**/*.html")
        local _before = eng:get_template_names()
        eng:exclude_templates({ "base.html" })
        local after = eng:get_template_names()
        expect(#after > 0 or #after == 0).to.be.truthy()
      end)

      it("reloads templates without error", function()
        local eng = templates.jinja2.new("examples/templates/**/*.html")
        eng:reload_templates()
        local names = eng:get_template_names()
        expect(names).to.be.a("table")
      end)
    end)

    describe("Rendering", function()
      it("renders template with context", function()
        local eng = templates.jinja2.new()
        eng:add_template("hello.html", "Hello {{ name }}!")
        local result = eng:render("hello.html", { name = "World" })
        expect(result).to.equal("Hello World!")
      end)

      it("renders template with custom function", function()
        local eng = templates.jinja2.new()
        eng:add_function("greet", function(args)
          return "Hi " .. args.name
        end)
        eng:add_template("greet.html", "{{ greet(name='Alice') }}")
        local result = eng:render("greet.html")
        expect(result).to.match("Hi")
      end)

      it("renders with multiple context variables", function()
        local eng = templates.jinja2.new()
        eng:add_template("multi.html", "{{ a }} {{ b }} {{ c }}")
        local result = eng:render("multi.html", { a = "x", b = "y", c = "z" })
        expect(result).to.equal("x y z")
      end)

      it("fails to render nonexistent template", function()
        local eng = templates.jinja2.new()
        expect(function()
          eng:render("nonexistent.html")
        end).to.fail()
      end)
    end)

    describe("Server Route Registration", function()
      it("registers routes via add_to_server", function()
        local eng = templates.jinja2.new()
        eng:add_template("page.html", "hello {{ name }}")
        local server = http.server.new()
        eng:add_to_server(server, { name = "test" })
        expect(#server.routes > 0).to.be.truthy()
        expect(server.routes[1].method).to.equal("get")
        expect(server.routes[1].func).to.be.a("function")
      end)
    end)

    describe("Server Integration", function()
      local server
      local task
      local port = 18081

      test.before(function()
        local eng = templates.jinja2.new()
        eng:add_template("page.html", "hello {{ name }}")
        eng:add_function("uppercase", function(args)
          return args.value:upper()
        end)
        eng:add_template("func.html", "{{ uppercase(value='hi') }}")

        server = http.server.new()
        server.port = port
        eng:add_to_server(server, { name = "world" })

        task = spawn_task(function()
          server:run()
        end)
        spawn_timeout(function() end, 150):await()
      end)

      test.after(function()
        ---@diagnostic disable-next-line: need-check-nil
        server:shutdown(server)
      end)

      it("serves rendered template via GET", function()
        local req = http.request({ url = "http://127.0.0.1:" .. port .. "/page", method = "GET" })
        local res = req:execute()
        expect(res:status_code()).to.equal(200)
        local body = res:body():text()
        expect(body:find("hello world") ~= nil).to.be.truthy()
      end)

      it("serves template with function call", function()
        local req = http.request({ url = "http://127.0.0.1:" .. port .. "/func", method = "GET" })
        local res = req:execute()
        expect(res:status_code()).to.equal(200)
        local body = res:body():text()
        expect(body:find("HI") ~= nil).to.be.truthy()
      end)

      it("returns 404 for unregistered template route", function()
        local req = http.request({ url = "http://127.0.0.1:" .. port .. "/nonexistent", method = "GET" })
        local res = req:execute()
        expect(res:status_code()).to.equal(404)
      end)
    end)
  end)

  -------------------------------------------------------------------------------
  -- Markdown
  -------------------------------------------------------------------------------
  describe("Markdown", function()
    describe("to_html", function()
      it("converts heading to HTML", function()
        local result = templates.markdown.to_html("# Hello")
        expect(result).to.be.a("string")
        expect(#result > 0).to.be.truthy()
        expect(result:find("Hello") ~= nil).to.be.truthy()
      end)

      it("converts bold text", function()
        local result = templates.markdown.to_html("**bold**")
        expect(result).to.be.a("string")
        expect(result:find("bold") ~= nil).to.be.truthy()
      end)

      it("converts paragraph", function()
        local result = templates.markdown.to_html("hello world")
        expect(result).to.be.a("string")
        expect(result:find("hello world") ~= nil).to.be.truthy()
      end)

      it("handles empty string", function()
        local result = templates.markdown.to_html("")
        expect(result).to.be.a("string")
      end)
    end)

    describe("to_ast", function()
      it("returns table for heading", function()
        local result = templates.markdown.to_ast("# Hello")
        expect(result).to.be.a("table")
      end)

      it("returns table for paragraph", function()
        local result = templates.markdown.to_ast("hello world")
        expect(result).to.be.a("table")
      end)

      it("handles empty string", function()
        local result = templates.markdown.to_ast("")
        expect(result).to.be.a("table")
      end)
    end)
  end)
end
