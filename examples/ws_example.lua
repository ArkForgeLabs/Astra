local http = require("http")
local server = http.server.new()

---@param socket WebSocket
local function handle_socket(socket)
  print("Connection opened!")
  while true do
    pprint(socket:recv())
    socket:send("text", "hello from the server")
    socket:send_close({
      code = 1000,
      reason = "end of chat",
    })
  end
end

server:websocket("/", handle_socket)

server:run()
