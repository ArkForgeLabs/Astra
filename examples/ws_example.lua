local server = Astra.http.server:new()

---@param socket WebSocket
local function handle_socket(socket)
	print("Connection opened!")
	while true do
		pprint(socket:recv())
		socket:send("text", { message = "Hello from the server" })
	end
end

server:get("/", function()
	print("hello from root")
end)
server:websocket("/ws", handle_socket)

server:run()
