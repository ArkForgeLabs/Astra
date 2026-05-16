--!strict

local templates = require("@astra/templates")
local template_engine = templates.jinja2.new("examples/templates/**/*.html")

template_engine:exclude_templates({ "base.html" })

template_engine:add_function("test", function(args)
  return args.name
end)

local server = require("@astra/http").server.new()

template_engine:add_to_server(server, { count = 5 })

local count = 0
server:get("/hydrate", function(_request, response)
  count = count + 1
  response:set_header("Content-Type", "text/html")
  return template_engine:render("index.html", { count = count })
end)

print("Listening at: http://" .. tostring(server.hostname) .. ":" .. tostring(server.port))

server:run()
