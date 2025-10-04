local server = require("astra.teal.http").server.new()

-- A simple GET index route with text return
server:get("/", function(): string
	return "hello from default Astra instance!"
end)

-- The path parameters also works
server:get("/{id}", function(request: HTTPServerRequest): string
	return "The value of id is: " .. tostring(request:params().id)
end)

-- You can also use the local variables within routes
local counter = 0
server:get("/count", function(): table
	counter = counter + 1
	-- and also can return JSON
	return { counter }
end)

-- The request parameter is optional but contains useful information
server:get("/headers", function(request: HTTPServerRequest): table
	return request:headers()
end)

pprint("🚀 Listening at: http://" .. tostring(server.hostname) .. ":" .. tostring(server.port))

-- Run the server
server:run()
