local server = Astra.http.server:new()

---@param socket WebSocket
local function handle_socket(socket)
	print("Connection opened!")
	while true do
		local message = socket:recv()
		pprint(message)
		socket:send_text("hello can this be seen")
	end
end

server:get("/", function()
	print("hello from root")
end)
server:websocket("/ws", handle_socket)

server:run()
