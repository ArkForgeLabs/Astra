-- HTTP server API (logic only: creation, routes, config)
local http = require("http")
assert(http.server ~= nil, "http.server")
local s = http.server.new()
assert(s ~= nil, "server.new")
assert(s.port == 8080, "default port")
assert(s.hostname == "127.0.0.1", "default hostname")
assert(s.routes ~= nil and type(s.routes) == "table", "routes table")

s:get("/", function() return "ok" end)
assert(#s.routes == 1, "one route after get")
assert(s.routes[1].path == "/" and s.routes[1].method == "get", "route get /")

s:post("/post", function() return "posted" end)
assert(#s.routes == 2, "two routes")
assert(s.routes[2].method == "post", "route post")

s:static_dir("/static", "public", { headers = { ["X-Custom"] = "val" } })
assert(s.routes[3].method == "static_dir", "static_dir")
assert(s.routes[3].static_dir == "public", "static_dir path")
assert(s.routes[3].config.headers ~= nil and s.routes[3].config.headers["X-Custom"] == "val", "static_dir headers")

s:static_file("/f", "index.html", { body_limit = 1000 })
assert(s.routes[4].method == "static_file", "static_file")
assert(s.routes[4].static_file == "index.html", "static_file path")
assert(s.routes[4].config.body_limit == 1000, "static_file config")

assert(http.status_codes ~= nil and http.status_codes.OK == 200, "status_codes")
