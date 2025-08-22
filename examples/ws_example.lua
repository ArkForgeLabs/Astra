local server = Astra.http.server:new()

---@param socket WebSocket
local function handle_socket(socket)
	print("Connection opened!")
	while true do
	    local message, err = socket:recv()
end

server:get("/", function()
	print("hello from root")
end)
server:websocket("/ws", handle_socket)

server:run()
