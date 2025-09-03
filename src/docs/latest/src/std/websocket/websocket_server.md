# WebSocket Server

Astra offers a WebSocket server powered by axum. Server creation takes a route, and as of now, you will have to inject JS code to have a functioning client, but this is subject to change in the future. You can create a WebSocket server like this:

```lua
local server = Astra.http.server:new()

local function handle_socket(socket)
	print("Connection opened!")
end

server:websocket("/", handle_socket)

server:run()
```

After creating our Astra server, we have to create a function to handle WebSocket behaviour, this function is then used as a callback by the `server:websocket()` function, which first takes the route for our websocket server, then the callback function.

We can print out received messages from our client like this:

```lua

local function handle_socket(socket)
  print("Connection opened!")

  while true do
    pprint(socket:recv())
  end
end

```

For a minimal websocket client, you can paste this code in your browser's console.

```js
// Replace this with your appropriate address and route
const socket = new WebSocket("http://localhost:8080/");

socket.addEventListener("open", (event) => {
  console.log("WebSocket connection opened");

  // Example: send a greeting or trigger a ping behavior
  socket.send("Hello from JS client!");
});

// Listen for messages
socket.addEventListener("message", (event) => {
  console.log("Message from server:", event.data);
  // You can add your logic here to handle incoming messages
});

// Optional: Listen for errors
socket.addEventListener("error", (event) => {
  console.error("WebSocket error:", event);
});

// Optional: Listen for connection close
socket.addEventListener("close", (event) => {
  console.log("WebSocket connection closed:", event.code, event.reason);
});
```

**NOTE**: All further example code will be placed inside the while loop of our callback function

You can send 5 types of messages from a WebSocket: text, bytes, ping, pong, and a close frame. The first 4 all take a string as their message, with bytes, ping, and pong also being able to take a table of 8-bit unsigned bytes, a close frame takes a [close code](https://websocket.org/reference/websocket-api/#websocket-close-codes) and a reason, which is an optional string, both of which should be places inside a lua table.

```lua
-- The first parameter is a type:
  -- text
  -- bytes
  -- ping
  -- pong
  -- close

socket:send("text", "hey there, this is a very informative message.")

-- There are also specialized functions for each type, which skip a lot of type checking to be more direct and concise:
socket:send_text("yet another informative message")

-- I can send a string of bytes:
socket:send_bytes("this will be illegible soon")
-- Or a table of them:
socket:send_ping({0, 88, 14, 67, 45})
socket:send_pong({17, 38, 80, 0, 85})

-- I can also send a close frame, first with the close code, and then the reason:
socket:send_close({1000, "finally, done with everything"})
-- The reason is optional, so you can also just go with this:
socket:send_close(1000)
-- If you're in a rush, you can close it uncleanly too, like this:
socket:send_close()
socket
```
