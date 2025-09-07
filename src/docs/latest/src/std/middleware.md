# Middleware

Middleware modifies the way a request is processed.

Since Lua is a very flexible language, there are lots of ways to implement middlewares.

We decided to take an advantage of Lua functions being a [first-class values](https://www.lua.org/pil/6.html).

> [!NOTE]
> If you are familiar with this concept, feel free to go to the **Full example** at the bottom of the page.

Astra has several built-in middlewares. You can modify or extend middlewares directly in `.astra/middleware.lua` (after running `astra export`) or in your own files. We are opened to PRs.

For more details, see the [middleware.lua](https://github.com/ArkForgeLabs/Astra/blob/main/src/components/http/middleware.lua) and the [middleware_example.lua](https://github.com/ArkForgeLabs/Astra/tree/main/examples/middleware.lua).

## Basic middleware

The following example shows the most basic middleware that changes the response headers.

```lua
local http = require("astra.lua.http")
local server = http.server:new()

local function sunny_day(request, response)
    return "What a great sunny day!"
end

--- `on Leave:`
--- sets `"Content-Type": "text/html"` response header
local function html(next_handler)
    return function(request, response, ctx)
        result = next_handler(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return result
    end
end

server:get("/sunny-day-plain-text", sunny_day)
server:get("/sunny-day-html", html(sunny_day))

server:run()
```

## Context

When we want to pass data through middleware, we can use the third argument and treat it as a context table.

```lua
local datetime = require("astra.lua.datetime")
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
        result = next_handler(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return result
    end
end

server:get("/favourite-day", ctx(insert_datetime(html(favourite_day))))

server:run()
```

## Chaining middlewares

To make it less tedious to compose middleware, we introduced the `chain` function, which combines all provided middleware into a single middleware.

> [!NOTE]
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

## Complex middleware

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

## Full example

```lua
local http = require("astra.lua.http")
local datetime = require("astra.lua.datetime")
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
        result = next_handler(request, response, ctx)
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
