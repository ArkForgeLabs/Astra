local http = require("http")
local server = http.server.new()

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

-- And catch all the routes that does not exist
server:fallback(function(request: HTTPServerRequest)
	return string.format("404, no way Jose! %s does not exist!", request:uri())
end)

-- Or accept files with multipart
server:post("/upload", function(request: HTTPServerRequest, response: HTTPServerResponse): nil
	local multipart = request:multipart()
	if multipart == nil then
		response:set_status_code(http.status_codes.BAD_REQUEST)
		return nil
	end

	-- You can access its fields
	local file_name = multipart:file_name() or "Myfile"
	-- optionally set name for the file you want to save
	multipart:save_file(file_name)
end, { body_limit = 1024 * 1024 * 64 }) -- with 64MB body limit

pprint("🚀 Listening at: http://" .. tostring(server.hostname) .. ":" .. tostring(server.port))

-- Run the server
server:run()
