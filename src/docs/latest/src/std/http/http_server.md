# HTTP Server

Astra offers HTTP1/2 web server through the [axum](https://github.com/tokio-rs/axum) project. On the Lua's side, the server holds configuration and route details, which are then sent to the Rust for running them. Since it is running on Tokio, it can take advantage of all available resources automatically, making it easy for vertical scaling. Throughout this documentation, the word `server` is used to describe an HTTP web server table on the Lua's side. You can create one as such:

```lua
-- create a new server with
local server = require("astra.lua.http").server.new()

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

## Deployment

You can follow the steps covered in [Configuration](./configuration.md) to setup the Astra itself.

Astra does not support TLS/SSL as of yet, but may support by the 1.0 release. However generally a reverse proxy service is recommended for deployment. We recommend [Caddy](https://caddyserver.com/) as it is easy to setup and use, especially for majority of our, and hopefully your, usecases. What caddy also does is automatically fetching TLS certificates for your domain as well which is always a good idea. You can install caddy through your system's package manager.

Then open a new file with the name `Caddyfile` with the following content:

```caddy
your_domain.tld {
    encode zstd gzip
    reverse_proxy :8080
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
