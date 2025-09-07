-- Create a templating engine, read more about template syntax at: https://keats.github.io/tera/docs
local template_engine = Astra.new_templating_engine("examples/templates/**/*.html")
-- Exclude base files from rendering
template_engine:exclude_templates({ "base.html" })
-- You can also add functions to be used within the templates
template_engine:add_function("test", function(args)
	return args.name
end)

-- Create an HTTP Server
local server = require("astra.lua.http").server.new()

-- Serve the templates
template_engine:add_to_server(
	server,
	-- Add some data for the templates
	{ count = 5 }
)

-- Or for debugging
-- template_engine:add_to_server_debug(server)

-- Partial hydration
local count = 0
server:get("/hydrate", function(request, response)
	-- your dynamic data
	count = count + 1
	-- response type
	response:set_header("Content-Type", "text/html")
	-- render the template
	return template_engine:render("index.html", { count = count })
end)

-- Run
server:run()
