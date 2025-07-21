# Middleware

*TL;DR*

The the middleware pattern was inspired by Clojure community.

```lua
local server = Astra.http.server:new()
local middleware = Astra.middleware
local chain = middleware.chain

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
--- Inserts `Astra.datetime.new()` into `ctx.datetime`
---
--- `Depends on:`
--- `ctx`
local function insert_datetime(next_handler)
    return function(request, response, ctx)
        ctx.datetime = Astra.datetime.new()
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

## Handler wrappers

Middleware in Astra is usually built using functions. Middleware wraps the handler in a function that can modify the way a request is processed.

To make composing middlewares less tedious, we introduce a `chain` function that combines all provided handlers into a single handler.

We use a context table to pass data through the handlers.

Astra has several built-in middlewares. You can modify or extend middlewares directly in `.astra/middleware.lua` (after running `astra export`) or in your own files. We are opened to PRs.

For more details, see the [middleware.lua](https://github.com/ArkForgeLabs/Astra/tree/main/src/lua_libs/middleware.lua) and the [middleware_example.lua](https://github.com/ArkForgeLabs/Astra/tree/main/examples/middleware.lua).

