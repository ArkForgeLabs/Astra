# HTTP Server

Astra offers HTTP1/2 web server through the [axum](https://github.com/tokio-rs/axum) project. On the Lua's side, the server holds configuration and route details, which are then sent to the Rust for running them. Since it is running on Tokio, it can take advantage of all available resources automatically, making it easy for vertical scaling. Throughout this documentation, the word `server` is used to describe an HTTP web server table on the Lua's side. You can create one as such:

```lua
-- create a new server with
local server = require("http").server.new()

-- run the server with
server:run()
```

## Configuration

Astra can be configured in a few ways for runtime. As of now there is no native TLS/SSL support and needs a reverse proxy such as [Caddy](https://caddyserver.com/) to handle that. Check [Deployment](./http_server.md#deployment) for more information.

However every configuration option will be available at the server instead. For example, changing the compression, port and hostname is as such:

```lua
-- configure the server with
server.compression = false
server.port = 8000
server.hostname = "0.0.0.0"
```

You can also configure other languages that compiles to Lua such as [Fennel](https://fennel-lang.org/). Astra's api is for pure Lua however, so it will be up to you to make type definitions and make sure it can call the right functions and tables.

## Routes

The server holds all of the route details. The routes are loaded at the start of the runtime and cannot be dynamically modified later on. There are also methods within the server that makes it easy to add new routes. For example:

```lua
-- A simple GET index route with text return
server:get("/", function()
    return "hello from default Astra instance! " .. Astra.version
end)
```

The syntax are as follows:

```lua
server:ROUTE_TYPE(ROUTE_PATH, CALLBACK);

-- Where callback is:
function(request?, response?);
```

The following route types are supported as of now:

- GET
- POST
- PUT
- PATCH
- PARSE
- DELETE
- OPTIONS
- TRACE

All lowercase and snake_case when calling with astra of course. There are two additional ones available:

- STATIC_DIR
- STATIC_FILE

Which does as expected, serves a file or directory over a route.

## Route Logic

Each route function needs a callback which contains a route's logic. This callback function optionally can have two arguments: `request` and `response` respectively, and may optionally have a return.

Interally requests and responses are each a struct in Rust initialized but not parsed/deserialized beforehand. This is to save performance overhead of serialization. However its content and be modified or accessed through their methods. We will discuss them later on.

Return types of the callback can optionally be either empty, string, or a table. The table responses are parsed in Rust and serialized to JSON, and then returned. Empty responses does not include any content. Responses, or lack of them, are by default sent with status code of 200.

## Requests

Requests are provided as the first argument of the route callbacks as a table (not deseralized). Each request in the route callbacks can be accessed through its methods. The following methods are available:

- body: `Body`
- headers: `table<string, string>`
- params: `table<string, string | number>`
- uri: `string`
- queries: `table<any, any>`
- method: `string`
- multipart: `Multipart`

where Body has:

- text: `string`
- json: `table`

and where Multipart has:

- `save_file(file_path: string | nil)`

Example:

```lua
server:get("/", function(req)
    -- access the headers
    pprint(req:headers())

    -- print the body as text
    print(req:body():text())
end)
```

## Responses

Responses are the second argument provided in the route callback. They allow you to modify the response to the way you want. Each response has the default 200 OK status along content header based on your response. The following methods are available:

- `set_status_code(status_code: number)`
- `set_header(key: string, value: string)`
- `remove_header(key: string)`
- `get_headers()`: `table<string, string>`

Example:

```lua
server:get("/", function(req, res)
    -- set header code
    res:set_status_code(300)
    -- set headers
    res:set_header("header-key", "header-value")

    return "Responding with Code 300 cuz why not"
end)
```

The headers, as stated, will include content type when sending to user, but can be changed while setting the type yourself.

## Cookies

Cookies allow you to store data on each HTTP request, if supported. Astra does not currently support signed and private cookies. You can create a new cookie by getting it from a request:

```lua
server:get("/", function(request)
    local cookie = request:new_cookie("key", "value")

    return "HEY"
end)
```

You can also get a previously set cookie:

```lua
local cookie = request:get_cookie("key")
```

After modification or creation, they will have no effect unless you set them to the response

```lua
response:set_cookie("key", cookie)
```

And similary, remove them with

```lua
response:remove_cookie("key")
```

Each cookie contains extra details and functions which are as follows:

```lua
set_name(cookie: Cookie, name: string)
set_value(cookie: Cookie, value: string)
set_domain(cookie: Cookie, domain: string)
set_path(cookie: Cookie, path: string)
set_expiration(cookie: Cookie, expiration: number)
set_http_only(cookie: Cookie, http_only: boolean)
set_max_age(cookie: Cookie, max_age: number)
set_permanent(cookie: Cookie)
get_name(cookie: Cookie): string?
get_value(cookie: Cookie): string?
get_domain(cookie: Cookie): string?
get_path(cookie: Cookie): string?
get_expiration(cookie: Cookie): number?
get_http_only(cookie: Cookie): boolean?
get_max_age(cookie: Cookie): number?
```

## WebSocket

Astra offers a WebSocket server powered by axum. Server creation takes a route similar to any other normal routes:

```lua
local server = require("astra.http").server:new()

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
socket:send_close({code = 1000, reason = "finally, done with everything"})
-- The reason is optional, so you can also just go with this:
socket:send_close(1000)
-- If you're in a rush, you can close it uncleanly too, like this:
socket:send_close()
socket
```

## Middleware

Middleware modifies the way a request is processed.

Since Lua is a very flexible language, there are lots of ways to implement middlewares.

We decided to take an advantage of Lua functions being a [first-class values](https://www.lua.org/pil/6.html).

> **Note:**
> If you are familiar with this concept, feel free to go to the **Full example** at the bottom of the page.

### Basic middleware

The following example shows the most basic middleware that changes the response headers.

```lua
local http = require("http")
local server = http.server:new()

local function sunny_day(request, response)
    return "What a great sunny day!"
end

--- `on Leave:`
--- sets `"Content-Type": "text/html"` response header
local function html(next_handler)
    return function(request, response, ctx)
        local result = next_handler(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return result
    end
end

server:get("/sunny-day-plain-text", sunny_day)
server:get("/sunny-day-html", html(sunny_day))

server:run()
```

### Context

When we want to pass data through middleware, we can use the third argument and treat it as a context table.

```lua
local datetime = require("datetime")
local server = http.server:new()

---@param ctx { datetime: DateTime }
local function favourite_day(_request, _response, ctx)
    local today = string.format(
        "%d/%d/%d",
        ctx.datetime:get_day(),
        ctx.datetime:get_month(),
        ctx.datetime:get_year()
    )
    return "My favourite day is " .. today
end

--- `on Entry:`
--- Inserts `datetime.new()` into `ctx.datetime`
---
--- `Depends on:`
--- `ctx`
local function insert_datetime(next_handler)
    return function(request, response, ctx)
        ctx.datetime = datetime.new()
        return next_handler(request, response, ctx)
    end
end

--- `on Entry:`
--- Creates a new `ctx` table and passes it as a third argument into the `next_handler`
local function ctx(next_handler)
    return function(request, response)
        local ctx = {}
        return next_handler(request, response, ctx)
    end
end

--- `on Leave:`
--- sets `"Content-Type": "text/html"` response header
local function html(next_handler)
    return function(request, response, ctx)
        local result = next_handler(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return result
    end
end

server:get("/favourite-day", ctx(insert_datetime(html(favourite_day))))

server:run()
```

### Chaining middlewares

To make it less tedious to compose middleware, we introduced the `chain` function, which combines all provided middleware into a single middleware.

> **Note:**
> Read more about why we can drop parenthesis while calling `chain` function here: [Writing a DSL in Lua](https://leafo.net/guides/dsl-in-lua.html)

```lua
local chain = http.middleware.chain

-- This will behave exactly the same as ctx(insert_datetime(html(favourite_day)))
server:get("/favourite-day", chain {ctx, insert_datetime, html} (favourite_day) )

-- We can create a common middlewares and reuse them
local composed_middleware = chain {ctx, insert_datetime, html}
server:get("/favourite-day-again", composed_middleware(favourite_day))

server:run()
```

### Complex middleware

We can use Lua [closures](https://www.lua.org/pil/6.1.html) to create more complex middlewares.

This example shows how to create a file logger:

```lua
--- `on Entry:`
--- Logs request method and uri into the file
---@param file_handler file* A file handler opened with an append mode `io.open("filepath", "a")`
---@param flush_interval number? The number of log entries after which the file handler will be flushed
local function file_logger(file_handler, flush_interval)
    local flush_interval = flush_interval or 1
    local flush_countdown = flush_interval
    return function(next_handler)
        return function(request, response, ctx)
            local str = string.format("[New Request %s] %s %s\n", os.date(), request:method(), request:uri())
            file_handler:write(str)

            flush_countdown = flush_countdown - 1
            if flush_countdown == 0 then
                file_handler:flush()
                flush_countdown = flush_interval
            end
            return next_handler(request, response, ctx)
        end
    end
end
local file_handler, err = io.open("logs.txt", "a")
if not file_handler then error(err) end
local logger = file_logger(file_handler)

local common = chain { ctx, logger, html }

server:get("/sunny-day", common(sunny_day))
server:get("/normal-day", common(normal_day))
server:get("/favourite-day", chain { common, insert_datetime } (favourite_day))

server:run()
```

The `logger` we got from the `file_logger` is gonna be used in all routes we pass it as a middleware.

### Full example

```lua
local http = require("http")
local datetime = require("datetime")
local server = http.server:new()
local chain = http.middleware.chain

local function sunny_day(_request, _response)
    return "What a great sunny day!"
end

local function normal_day(_request, _response)
    return "It's a normal day... I guess..."
end

---@param ctx { datetime: DateTime }
local function favourite_day(_request, _response, ctx)
    local today = string.format(
        "%d/%d/%d",
        ctx.datetime:get_day(),
        ctx.datetime:get_month(),
        ctx.datetime:get_year()
    )
    return "My favourite day is " .. today
end

--- `on Entry:`
--- Creates a new `ctx` table and passes it as a third argument into the `next_handler`
local function ctx(next_handler)
    return function(request, response)
        local ctx = {}
        return next_handler(request, response, ctx)
    end
end

--- `on Entry:`
--- Inserts `datetime.new()` into `ctx.datetime`
---
--- `Depends on:`
--- `ctx`
local function insert_datetime(next_handler)
    return function(request, response, ctx)
        ctx.datetime = datetime.new()
        return next_handler(request, response, ctx)
    end
end

--- `on Leave:`
--- sets `"Content-Type": "text/html"` response header
local function html(next_handler)
    return function(request, response, ctx)
        local result = next_handler(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return result
    end
end

--- `on Entry:`
--- Logs request method and uri into the file
---@param file_handler file* A file handler opened with an append mode `io.open("filepath", "a")`
---@param flush_interval number? The number of log entries after which the file handler will be flushed
local function file_logger(file_handler, flush_interval)
    local flush_interval = flush_interval or 1
    local flush_countdown = flush_interval
    return function(next_handler)
        return function(request, response, ctx)
            local str = string.format("[New Request %s] %s %s\n", os.date(), request:method(), request:uri())
            file_handler:write(str)

            flush_countdown = flush_countdown - 1
            if flush_countdown == 0 then
                file_handler:flush()
                flush_countdown = flush_interval
            end
            return next_handler(request, response, ctx)
        end
    end
end
local file_handler, err = io.open("logs.txt", "a")
if not file_handler then error(err) end
local logger = file_logger(file_handler)

server:get("/sunny-day", logger(html(sunny_day)))
server:get("/normal-day", chain { logger, html } (normal_day))
server:get("/favourite-day", chain { ctx, logger, insert_datetime, html } (favourite_day))

server:run()

```

## Deployment

You can follow the steps covered in [Configuration](./configuration.md) to setup the Astra itself.

Astra does not support TLS/SSL as of yet, but may support by the 1.0 release. However generally a reverse proxy service is recommended for deployment. We recommend [Caddy](https://caddyserver.com/) as it is easy to setup and use, especially for majority of our, and hopefully your, usecases. What caddy also does is automatically fetching TLS certificates for your domain as well which is always a good idea. You can install caddy through your system's package manager.

Then open a new file with the name `Caddyfile` with the following content:

```caddy
your_domain.tld {
    encode zstd gzip
    reverse_proxy :8080 {
        # Can also pass extra details such as IP addresses
        header_up X-Forwarded-For {client_ip}
        header_up X-Real-IP {client_ip}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
    }
}
```

and change `your_domain.tld` to your domain, and `:8080` to the port you have set for your server. After this, make sure your `443` and `80` ports are open through your firewall. For a linux server running ufw you can open them by:

```bash
sudo ufw allow 80
sudo ufw allow 443
```

And finally run the caddy:

```bash
caddy run
```

Make sure your server is running before that. That is pretty much it for the basic deployment.

## Fault Tolerance

Astra ensures fault tolerance through several methods [internally](https://github.com/ArkForgeLabs/Astra/blob/main/src/main.rs#L1-L2) and offers guidence on how you can ensure it on the Lua's endpoint as well.

Fault-tolerance essentially describes the ability to tolerate crashing errors and continue execution whereas otherwise caused the server to shut down. In Astra's internal case, this is ensured by removing all of the crashing points and handle every error that could occur during runtime. This was achieved through denying unwraps and expects throughout the codebase for the runtime. However there are still crashes on startup for cases that needs to be looked into, such as Lua parsing and errors, bad path, and/or system issues such as port being unavailable or unauthorized for Astra.

In Lua however, the errors are usually crash by default, which are still tolerated with Astra and does not shutdown the server. To handle the errors as values, where it allows you to ensure the server does not crash and the issues are handled, you can use features such as the [pcall](https://www.lua.org/pil/8.4.html). This is always recommended over any other method. For Astra's case, there are usually chained calls that each can faily on their own as well, hence wrapping them in lambda functions or individually pcall wrapping them always is a good idea.

## Shutdown

You can also shutdown your server using the `:shutdown()` method.
