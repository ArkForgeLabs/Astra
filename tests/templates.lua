local fs = require("fs")
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

      it("loads template from file and renders it", function()
        local eng = templates.jinja2.new()
        eng:add_template_file("base.html", "examples/templates/base.html")
        eng:add_template_file("index", "examples/templates/index.html")
        eng:add_function("test", function(args)
          return args.name
        end)
        local names = eng:get_template_names()
        expect(names).to.be.a("table")
        local found_index = false
        local found_base = false
        for _, name in ipairs(names) do
          if name == "index" then
            found_index = true
          end
          if name == "base.html" then
            found_base = true
          end
        end
        expect(found_index).to.equal(true)
        expect(found_base).to.equal(true)
        local result = eng:render("index", { count = 3 })
        expect(result:find("Count is: 3") ~= nil).to.be.truthy()
        expect(result:find("Home Page") ~= nil).to.be.truthy()
      end)

      it("excludes templates from name list but keeps them renderable", function()
        local eng = templates.jinja2.new("examples/templates/**/*.html")
        local names = eng:get_template_names()
        local has_base = false
        for _, n in ipairs(names) do
          if n == "base.html" then
            has_base = true
          end
        end
        expect(has_base).to.equal(true)

        eng:exclude_templates({ "base.html" })
        local after = eng:get_template_names()
        local still_has_base = false
        for _, n in ipairs(after) do
          if n == "base.html" then
            still_has_base = true
          end
        end
        expect(still_has_base).to.equal(false)
        local result = eng:render("base.html", {})
        expect(result).to.be.a("string")
        expect(#result > 0).to.be.truthy()
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

      it("renders with conditional", function()
        local eng = templates.jinja2.new()
        eng:add_template("cond.html", "{% if active %}on{% else %}off{% endif %}")
        expect(eng:render("cond.html", { active = true })).to.equal("on")
        expect(eng:render("cond.html", { active = false })).to.equal("off")
      end)

      it("renders with for loop", function()
        local eng = templates.jinja2.new()
        eng:add_template("loop.html", "{% for x in items %}{{ x }} {% endfor %}")
        local result = eng:render("loop.html", { items = { "a", "b", "c" } })
        expect(result).to.equal("a b c ")
      end)

      it("renders with filter", function()
        local eng = templates.jinja2.new()
        eng:add_template("filter.html", "{{ name | upper }}")
        local result = eng:render("filter.html", { name = "hello" })
        expect(result).to.equal("HELLO")
      end)

      local format_cases = {
        {
          name = "JSON-like",
          tmpl = "data.json",
          source = '{"name":"{{ name }}","count":{{ count }}}',
          ctx = { name = "alice", count = 3 },
          expected = '{"name":"alice","count":3}',
        },
        {
          name = "plain text",
          tmpl = "text.txt",
          source = "left {{ mid }} right",
          ctx = { mid = "center" },
          expected = "left center right",
        },
        {
          name = "XML-like",
          tmpl = "data.xml",
          source = "<root><item>{{ value }}</item></root>",
          ctx = { value = "test" },
          expected = "<root><item>test</item></root>",
        },
      }
      for _, fc in ipairs(format_cases) do
        it("renders to " .. fc.name .. " output", function()
          local eng = templates.jinja2.new()
          eng:add_template(fc.tmpl, fc.source)
          local result = eng:render(fc.tmpl, fc.ctx)
          expect(result).to.equal(fc.expected)
        end)
      end

      it("renders with nested context", function()
        local eng = templates.jinja2.new()
        eng:add_template("nested.html", "{{ user.name }} is {{ user.age }}")
        local result = eng:render("nested.html", { user = { name = "Alice", age = 30 } })
        expect(result).to.equal("Alice is 30")
      end)

      it("renders template inheritance with extends and block", function()
        local eng = templates.jinja2.new()
        eng:add_template("base", "{% block content %}original{% endblock %}")
        eng:add_template("child", [[{% extends "base" %}{% block content %}child content{% endblock %}]])
        local result = eng:render("child")
        expect(result).to.equal("child content")
      end)

      it("renders with super() in child block", function()
        local eng = templates.jinja2.new()
        eng:add_template("base", "{% block content %}parent{% endblock %}")
        eng:add_template("child", [[{% extends "base" %}{% block content %}{{ super() }} modified{% endblock %}]])
        local result = eng:render("child")
        expect(result).to.equal("parent modified")
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

    describe("File-Based Reload", function()
      local reload_dir = "tests/_template_reload"

      test.before(function()
        if fs.exists(reload_dir) then
          fs.remove_dir_all(reload_dir)
        end
        fs.create_dir(reload_dir)
        fs.write_file(reload_dir .. "/page.html", "Initial {{ value }}!")
      end)

      test.after(function()
        if fs.exists(reload_dir) then
          fs.remove_dir_all(reload_dir)
        end
      end)

      it("loads and renders from file glob", function()
        local eng = templates.jinja2.new(reload_dir .. "/**/*.html")
        local result = eng:render("page.html", { value = "hello" })
        expect(result).to.equal("Initial hello!")
      end)

      it("reflects file changes after reload", function()
        local eng = templates.jinja2.new(reload_dir .. "/**/*.html")
        local before = eng:render("page.html", { value = "hello" })
        expect(before).to.equal("Initial hello!")

        fs.write_file(reload_dir .. "/page.html", "Updated {{ value }}!")
        eng:reload_templates()
        local after = eng:render("page.html", { value = "world" })
        expect(after).to.equal("Updated world!")
      end)

      it("reload preserves other templates loaded from same glob", function()
        fs.write_file(reload_dir .. "/other.html", "Other {{ x }}")
        local eng = templates.jinja2.new(reload_dir .. "/**/*.html")

        eng:reload_templates()

        local page = eng:render("page.html", { value = "a" })
        local other = eng:render("other.html", { x = "b" })
        expect(page).to.equal("Initial a!")
        expect(other).to.equal("Other b")
      end)

      it("does not discover new files on reload", function()
        local eng = templates.jinja2.new(reload_dir .. "/**/*.html")
        local names_before = eng:get_template_names()

        fs.write_file(reload_dir .. "/new.html", "New file content")
        eng:reload_templates()
        local names_after = eng:get_template_names()

        expect(#names_after).to.equal(#names_before)
      end)
    end)
  end)

  -------------------------------------------------------------------------------
  -- Markdown
  -------------------------------------------------------------------------------
  describe("Markdown", function()
    describe("to_html", function()
      local md_cases = {
        { name = "heading", input = "# Hello", expected = "<h1>Hello</h1>" },
        { name = "bold text", input = "**bold**", expected = "<p><strong>bold</strong></p>" },
        { name = "paragraph", input = "hello world", expected = "<p>hello world</p>" },
        { name = "inline code", input = "use `code` here", expected = "<p>use <code>code</code> here</p>" },
        {
          name = "fenced code block",
          input = "```lua\nlocal x = 1\n```",
          expected = '<pre><code class="language-lua">local x = 1\n</code></pre>',
        },
        {
          name = "link",
          input = "[text](http://example.com)",
          expected = '<p><a href="http://example.com">text</a></p>',
        },
        { name = "empty string", input = "", expected = "" },
      }
      for _, mc in ipairs(md_cases) do
        it("converts " .. mc.name .. " to HTML", function()
          local result = templates.markdown.to_html(mc.input)
          expect(result).to.equal(mc.expected)
        end)
      end
    end)
    describe("to_ast", function()
      it("has root type for heading", function()
        local result = templates.markdown.to_ast("# Hello")
        expect(result.type).to.equal("root")
        expect(result.children[1].type).to.equal("heading")
        expect(result.children[1].depth).to.equal(1)
        expect(result.children[1].children[1].value).to.equal("Hello")
      end)

      it("has paragraph type for plain text", function()
        local result = templates.markdown.to_ast("hello world")
        expect(result.type).to.equal("root")
        expect(result.children[1].type).to.equal("paragraph")
        expect(result.children[1].children[1].value).to.equal("hello world")
      end)

      it("has code type for code block", function()
        local result = templates.markdown.to_ast("```\ncode\n```")
        expect(result.type).to.equal("root")
        expect(result.children[1].type).to.equal("code")
        expect(result.children[1].value).to.equal("code")
      end)

      it("has empty children for empty input", function()
        local result = templates.markdown.to_ast("")
        expect(result.type).to.equal("root")
        expect(#result.children).to.equal(0)
      end)
    end)
  end)
end
