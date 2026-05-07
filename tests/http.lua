local fs = require("fs")
local http = require("http")
require("test")

---@param test Test
return function(test)
  local describe = test.describe
  local it = test.it
  local expect = test.expect

  -------------------------------------------------------------------------------
  -- HTTP Status Codes
  -------------------------------------------------------------------------------
  describe("HTTP Status Codes", function()
    it("has informational codes (1xx)", function()
      expect(http.status_codes.CONTINUE).to.equal(100)
      expect(http.status_codes.SWITCHING_PROTOCOLS).to.equal(101)
      expect(http.status_codes.PROCESSING).to.equal(102)
      expect(http.status_codes.EARLY_HINTS).to.equal(103)
      expect(http.status_codes.UPLOAD_RESUMPTION_SUPPORTED).to.equal(104)
    end)

    it("has success codes (2xx)", function()
      expect(http.status_codes.OK).to.equal(200)
      expect(http.status_codes.CREATED).to.equal(201)
      expect(http.status_codes.ACCEPTED).to.equal(202)
      expect(http.status_codes.NO_CONTENT).to.equal(204)
      expect(http.status_codes.PARTIAL_CONTENT).to.equal(206)
    end)

    it("has redirection codes (3xx)", function()
      expect(http.status_codes.MULTIPLE_CHOICES).to.equal(300)
      expect(http.status_codes.MOVED_PERMANENTLY).to.equal(301)
      expect(http.status_codes.FOUND).to.equal(302)
      expect(http.status_codes.NOT_MODIFIED).to.equal(304)
      expect(http.status_codes.TEMPORARY_REDIRECT).to.equal(307)
      expect(http.status_codes.PERMANENT_REDIRECT).to.equal(308)
    end)

    it("has client error codes (4xx)", function()
      expect(http.status_codes.BAD_REQUEST).to.equal(400)
      expect(http.status_codes.UNAUTHORIZED).to.equal(401)
      expect(http.status_codes.FORBIDDEN).to.equal(403)
      expect(http.status_codes.NOT_FOUND).to.equal(404)
      expect(http.status_codes.CONFLICT).to.equal(409)
      expect(http.status_codes.TOO_MANY_REQUESTS).to.equal(429)
      expect(http.status_codes.IM_A_TEAPOT).to.equal(418)
    end)

    it("has server error codes (5xx)", function()
      expect(http.status_codes.INTERNAL_SERVER_ERROR).to.equal(500)
      expect(http.status_codes.NOT_IMPLEMENTED).to.equal(501)
      expect(http.status_codes.BAD_GATEWAY).to.equal(502)
      expect(http.status_codes.SERVICE_UNAVAILABLE).to.equal(503)
      expect(http.status_codes.GATEWAY_TIMEOUT).to.equal(504)
    end)
  end)

  -------------------------------------------------------------------------------
  -- HTTP Middleware
  -------------------------------------------------------------------------------
  describe("HTTP Middleware", function()
    it("chains middlewares in correct order", function()
      local order = {}
      local a = function(next)
        return function(...)
          table.insert(order, "a")
          return next(...)
        end
      end
      local b = function(next)
        return function(...)
          table.insert(order, "b")
          return next(...)
        end
      end
      local c = function(next)
        return function(...)
          table.insert(order, "c")
          return next(...)
        end
      end

      local handler = function()
        table.insert(order, "handler")
        return "done"
      end

      local composed = http.middleware.chain({ a, b, c })(handler)
      local result = composed()
      expect(result).to.equal("done")
      expect(order[1]).to.equal("a")
      expect(order[2]).to.equal("b")
      expect(order[3]).to.equal("c")
      expect(order[4]).to.equal("handler")
    end)

    it("passes arguments through middleware chain", function()
      local order = {}
      local a = function(next)
        return function(...)
          table.insert(order, "a")
          return next(...)
        end
      end
      local b = function(next)
        return function(...)
          table.insert(order, "b")
          return next(...)
        end
      end

      local handler = function()
        table.insert(order, "handler")
        return "done"
      end

      local composed = http.middleware.chain({ a, b })(handler)
      local result = composed()
      expect(result).to.equal("done")
      expect(order[1]).to.equal("a")
      expect(order[2]).to.equal("b")
      expect(order[3]).to.equal("handler")
    end)

    it("throws on non-function handler", function()
      expect(function()
        http.middleware.chain({
          function()
            return function() end
          end,
        })(42)
      end).to.fail()
    end)

    it("throws on chain with fewer than 2 middlewares", function()
      expect(function()
        http.middleware.chain({ function() end })(function() end)
      end).to.fail()
    end)

    it("throws on non-function middleware in chain", function()
      expect(function()
        http.middleware.chain({ 42 })(function() end)
      end).to.fail()
    end)

    it("does not modify handler when middleware returns it unchanged", function()
      local identity = function(next)
        return next
      end

      local handler = function()
        return "original"
      end

      local composed = http.middleware.chain({ identity, identity })(handler)
      expect(composed).to.equal(handler)
    end)
  end)

  -------------------------------------------------------------------------------
  -- HTTP Server - Constructor & Routes
  -------------------------------------------------------------------------------
  describe("HTTP Server", function()
    describe("Constructor", function()
      it("creates a server with default values", function()
        local server = http.server.new()
        expect(server.hostname).to.equal("127.0.0.1")
        expect(server.port).to.equal(8080)
        expect(server.compression).to.equal(false)
        expect(server.version).to.equal("0.0.0")
        expect(server.routes).to.be.a("table")
        expect(#server.routes).to.equal(0)
      end)

      it("creates independent server instances", function()
        local s1 = http.server.new()
        local s2 = http.server.new()
        s1.port = 9090
        expect(s1.port).to.equal(9090)
        expect(s2.port).to.equal(8080)
      end)
    end)

    describe("Route Registration", function()
      local basic_routes = {
        { name = "GET", method = "get", path = "/test" },
        { name = "POST", method = "post", path = "/data" },
        { name = "PUT", method = "put", path = "/data" },
        { name = "DELETE", method = "delete", path = "/data" },
      }
      for _, r in ipairs(basic_routes) do
        it("registers " .. r.name .. " route", function()
          local server = http.server.new()
          server[r.method](server, r.path, function() end)
          expect(#server.routes).to.equal(1)
          expect(server.routes[1].method).to.equal(r.method)
          expect(server.routes[1].func).to.be.a("function")
        end)
      end

      it("registers OPTIONS, PATCH, TRACE routes", function()
        local server = http.server.new()
        server:options("/o", function() end)
        server:patch("/p", function() end)
        server:trace("/t", function() end)
        expect(server.routes[1].method).to.equal("options")
        expect(server.routes[2].method).to.equal("patch")
        expect(server.routes[3].method).to.equal("trace")
      end)

      it("prepends root path to the front of routes", function()
        local server = http.server.new()
        server:get("/users", function() end)
        server:get("/", function() end)
        expect(server.routes[1].path).to.equal("/")
        expect(server.routes[2].path).to.equal("/users")
      end)

      local static_routes = {
        {
          name = "static directory",
          method = "static_dir",
          path = "/files",
          field = "static_dir",
          value = "./public",
        },
        {
          name = "static file",
          method = "static_file",
          path = "/robots.txt",
          field = "static_file",
          value = "./robots.txt",
        },
      }
      for _, r in ipairs(static_routes) do
        it("registers " .. r.name .. " route", function()
          local server = http.server.new()
          server[r.method](server, r.path, r.value)
          expect(server.routes[1].method).to.equal(r.method)
          expect(server.routes[1][r.field]).to.equal(r.value)
        end)
      end

      local special_routes = {
        { name = "websocket", method = "websocket", path = "/ws", expected_method = "web_socket" },
        { name = "fallback", method = "fallback", path = nil, expected_method = "fallback" },
      }
      for _, r in ipairs(special_routes) do
        it("registers " .. r.name .. " route", function()
          local server = http.server.new()
          if r.path then
            server[r.method](server, r.path, function() end)
          else
            server[r.method](server, function() end)
          end
          expect(server.routes[1].method).to.equal(r.expected_method)
        end)
      end

      it("stores route configuration", function()
        local server = http.server.new()
        server:get("/upload", function() end, {
          body_limit = 1024 * 1024,
          compression = true,
          headers = { ["X-Custom"] = "value" },
        })
        local config = server.routes[1].config
        expect(config.body_limit).to.equal(1024 * 1024)
        expect(config.compression).to.equal(true)
        expect(config.headers["X-Custom"]).to.equal("value")
      end)
    end)
  end)

  -------------------------------------------------------------------------------
  -- HTTP Server Integration
  -------------------------------------------------------------------------------
  describe("HTTP Server Integration", function()
    local server
    local task
    local port = 18080
    local tmp_dir = "tests/_http_static_test"

    test.before(function()
      -- Setup temp directory for static file test
      fs.create_dir(tmp_dir)
      fs.write_file(tmp_dir .. "/hello.txt", "Hello, World!")
      fs.write_file(tmp_dir .. "/data.json", '{"key": "value"}')

      -- Create and configure server
      server = http.server.new()
      server.port = port

      server:get("/ping", function()
        return "pong"
      end)

      server:get("/echo", function(request)
        return {
          method = request:method(),
          uri = request:uri(),
        }
      end)

      server:get("/users/{id}", function(request)
        return { id = request:params().id }
      end)

      server:get("/search", function(request)
        return { q = request:queries().q }
      end)

      server:post("/data", function(request)
        local body = request:body():text()
        return { received = body }
      end)

      server:get("/echo-header", function(request)
        local headers = request:headers()
        return { x_test = headers["X-Test"] }
      end)

      server:get("/status/{code}", function(request, response)
        local code = tonumber(request:params().code)
        assert(code)
        response:set_status_code(code)
        return tostring(code)
      end)

      server:get("/set-cookie", function(request, response)
        local cookie = request:new_cookie("test_cookie", "test_value")
        cookie:set_path("/")
        response:set_cookie(cookie)
        return "ok"
      end)

      server:static_dir("/files", tmp_dir)

      server:fallback(function(_request, response)
        response:set_status_code(http.status_codes.NOT_FOUND)
        return "not found"
      end)

      -- Start server in background task
      task = spawn_task(function()
        server:run()
      end)
      -- Yield briefly to let the server start listening
      spawn_timeout(function() end, 150):await()
    end)

    test.after(function()
      -- Shutdown server and clean up temp files
      server:shutdown(server)
      fs.remove_dir_all(tmp_dir)
    end)

    it("serves a GET request and returns correct body", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/ping", method = "GET" })
      local res = req:execute()
      expect(res:status_code()).to.equal(200)
      expect(res:body():text()).to.equal("pong")
    end)

    it("returns correct method and URI in handler", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/echo", method = "GET" })
      local res = req:execute()
      local body = res:body():json()
      expect(body.method).to.equal("GET")
      expect(body.uri).to.equal("/echo")
    end)

    it("handles route path parameters", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/users/42", method = "GET" })
      local res = req:execute()
      local body = res:body():json()
      expect(body.id).to.equal(42)
    end)

    it("handles query string parameters", function()
      local req = http.request({
        url = "http://127.0.0.1:" .. port .. "/search?q=hello+world",
        method = "GET",
      })
      local res = req:execute()
      local body = res:body():json()
      expect(body.q).to.equal("hello world")
    end)

    it("handles POST request with body", function()
      local req = http.request({
        url = "http://127.0.0.1:" .. port .. "/data",
        method = "POST",
        body = "test payload",
      })
      local res = req:execute()
      local body = res:body():json()
      expect(body.received).to.equal("test payload")
    end)

    it("echoes custom request headers", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/echo-header", method = "GET" })
      req:set_header("X-Test", "custom-value")
      local res = req:execute()
      expect(res:status_code()).to.equal(200)
      local text = res:body():text()
      expect(text).to.be.a("string")
    end)

    it("returns 404 for unregistered routes", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/nonexistent", method = "GET" })
      local res = req:execute()
      expect(res:status_code()).to.equal(404)
      expect(res:body():text()).to.equal("not found")
    end)

    it("returns custom status codes", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/status/201", method = "GET" })
      local res = req:execute()
      expect(res:status_code()).to.equal(201)
    end)

    it("serves static files from directory", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/files/hello.txt", method = "GET" })
      local res = req:execute()
      expect(res:status_code()).to.equal(200)
      expect(res:body():text()).to.equal("Hello, World!")
    end)

    it("serves static JSON files", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/files/data.json", method = "GET" })
      local res = req:execute()
      local body = res:body():json()
      expect(body.key).to.equal("value")
    end)

    it("sets cookies on response", function()
      local req = http.request({ url = "http://127.0.0.1:" .. port .. "/set-cookie", method = "GET" })
      local res = req:execute()
      local headers = res:headers()
      expect(headers).to.be.a("table")
    end)
  end)
end
