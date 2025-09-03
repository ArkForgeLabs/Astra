local server = Astra.http.server:new()

---@param socket WebSocket
local function handle_socket(socket)
	print("Connection opened!")
	while true do
		pprint(socket:recv())
		socket:send("text", "hello from the server")
		socket:send_close(1000)
	end
end

server:websocket("/", handle_socket)

server:run()
