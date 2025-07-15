Astra.http.server = {}

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias callback fun(request: HTTPServerRequest, response: HTTPServerResponse): any

---@class HTTPRouteConfiguration
---@field body_limit? number

---@class HTTPRoute
---@field path string
---@field method string
---@field func function
---@field static_dir string?
---@field static_file string?
---@field config HTTPRouteConfiguration?

---@class HTTPMultipart
---@field save_file fun(multipart: HTTPMultipart, file_path: string | nil): string | nil Saves the multipart into disk

---@class HTTPServerRequest
---@field method fun(request: HTTPServerRequest): string Returns the HTTP method (e.g., "GET", "POST").
---@field uri fun(request: HTTPServerRequest): string Returns the URI of the request.
---@field queries fun(request: HTTPServerRequest): table Returns the query list.
---@field headers fun(request: HTTPServerRequest): table Returns a table containing the headers of the request.
---@field body fun(request: HTTPServerRequest): HTTPBody|nil Returns the body of the request, which can be a table or a string.
---@field multipart fun(request: HTTPServerRequest): HTTPMultipart|nil Returns a multipart if available.
---@field get_cookie fun(request: HTTPServerRequest, name: string): Cookie Returns a cookie
---@field new_cookie fun(request: HTTPServerRequest, name: string, value: string): Cookie Returns a cookie

---@class HTTPServerResponse
---@field set_status_code fun(response: HTTPServerResponse, new_status_code: number) Sets the HTTP status code of the response
---@field set_header fun(response: HTTPServerResponse, key: string, value: string) Sets a header
---@field get_headers fun(response: HTTPServerResponse): table|nil Returns the entire headers list that so far has been set for the response
---@field remove_header fun(response: HTTPServerResponse, key: string) Removes a header from the headers list
---@field set_cookie fun(response: HTTPServerResponse, cookie: Cookie) Sets a cookie
---@field remove_cookie fun(response: HTTPServerResponse, cookie: Cookie) Removes a cookie from the list

---@class Cookie
---@field set_name fun(cookie: Cookie, name: string)
---@field set_value fun(cookie: Cookie, value: string)
---@field set_domain fun(cookie: Cookie, domain: string)
---@field set_path fun(cookie: Cookie, path: string)
---@field set_expiration fun(cookie: Cookie, expiration: number)
---@field set_http_only fun(cookie: Cookie, http_only: boolean)
---@field set_max_age fun(cookie: Cookie, max_age: number)
---@field set_permanent fun(cookie: Cookie)
---@field get_name fun(cookie: Cookie): string?
---@field get_value fun(cookie: Cookie): string?
---@field get_domain fun(cookie: Cookie): string?
---@field get_path fun(cookie: Cookie): string?
---@field get_expiration fun(cookie: Cookie): number?
---@field get_http_only fun(cookie: Cookie): boolean?
---@field get_max_age fun(cookie: Cookie): number?

---@class CloseFrame
---@field code integer
---@field reason string

---@class WebSocketMessage
---@field type "text" | "binary" | "ping" | "pong" | "close"
---@field data string

---@class WebSocket
---Receive another message. Returns `nil` if the stream has closed.
---@field recv fun(socket: WebSocket): WebSocketMessage|nil, nil|string
---
---A text WebSocket message
---@field send_text fun(socket: WebSocket, message: string): boolean|nil, nil|string
---
---A binary WebSocket message
---@field send_binary fun(socket: WebSocket, bytes: string): boolean|nil, nil|string
---
---A ping message with the specified payload
---
---The payload here must have a length less than 125 bytes.
---
---Ping messages will be automatically responded to by the server,
---so you do not have to worry about dealing with them yourself.
---@field send_ping fun(socket: WebSocket, bytes: string): boolean|nil, nil|string
---
---A pong message with the specified payload
---
---The payload here must have a length less than 125 bytes.
---
---Pong messages will be automatically sent to the client if a ping message is received,
---so you do not have to worry about constructing them yourself unless you want to implement a unidirectional heartbeat.
---@field send_pong fun(socket: WebSocket, bytes: string): boolean|nil, nil|string
---
---@field send_close fun(socket: WebSocket, close_frame: CloseFrame?): boolean|nil, nil|string


---@alias wscallback fun(socket: WebSocket): any


----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

---@class HTTPServer
---@diagnostic disable-next-line: missing-fields
local HTTPServer = {
	version = "0.0.0",
	hostname = "127.0.0.1",
	--- Enable or disable compression
	compression = false,
	port = 8080,
	--- Contains all of the route details
	routes = {},
}
function HTTPServer:new()
	local server = {
		version = "0.0.0",
		hostname = "127.0.0.1",
		--- Enable or disable compression
		compression = false,
		port = 8080,
		--- Contains all of the route details
		routes = {},
	}

	setmetatable(server, self)
	self.__index = self
	return server
end

---@return HTTPServer
function Astra.http.server.new()
	return HTTPServer:new()
end

local function add_to_routes(server, method, path, callback, config)
	local index = (path == "/") and 1 or #server.routes + 1
	table.insert(server.routes, index, {
		path = path,
		method = method,
		func = callback,
		config = config or {},
	})
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:get(path, callback, config)
	add_to_routes(self, "get", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:post(path, callback, config)
	add_to_routes(self, "post", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:put(path, callback, config)
	add_to_routes(self, "put", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:delete(path, callback, config)
	add_to_routes(self, "delete", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:options(path, callback, config)
	add_to_routes(self, "options", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:patch(path, callback, config)
	add_to_routes(self, "patch", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:trace(path, callback, config)
	add_to_routes(self, "trace", path, callback, config)
end

---@param path string
---@param serve_path string
---@param config HTTPRouteConfiguration?
function HTTPServer:static_dir(path, serve_path, config)
	table.insert(self.routes, {
		path = path,
		method = "static_dir",
		func = function() end,
		static_dir = serve_path,
		config = config or {},
	})
end

---@param path string
---@param serve_path string
---@param config HTTPRouteConfiguration?
function HTTPServer:static_file(path, serve_path, config)
	table.insert(self.routes, {
		path = path,
		method = "static_file",
		func = function() end,
		static_file = serve_path,
		config = config or {},
	})
end

---@param path string
---@param wscallback wscallback
---@param config table?	// TODO: make a type for websocket config
function HTTPServer:ws(path, wscallback, config)
	table.insert(self.routes, {
		path = path,
		method = "websocket",
		func = wscallback,
		config = config or {},
	})
end

---Runs the server
function HTTPServer:run()
	---@diagnostic disable-next-line: undefined-global
	astra_internal__start_server(self)
end
