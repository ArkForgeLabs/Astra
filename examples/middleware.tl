local http = require("astra.teal.http")
local datetime = require("astra.teal.datetime")

local server = http.server.new()
local chain = http.middleware.chain


local function homepage(): string
    return "Hi there!"
end

local type next_handler_type = function(request: HTTPServerRequest, response: HTTPServerResponse, ctx?: {string: DateTime}): function

--- `on Entry:`
--- Inserts `Astra.datetime.new()` into `ctx.datetime`
---
--- `Depends on:`
--- `context`
local function insert_datetime(next_handler: next_handler_type): function
    return function(request: HTTPServerRequest, response: HTTPServerResponse, ctx?: {string: DateTime}): function
        ctx.datetime = datetime.new()
        local result = next_handler(request, response, ctx)
        return result
    end
end

--- `on Entry:`
--- Creates a new `ctx` table and passes it as a third argument into the `next_handler`
local function context(next_handler: next_handler_type): function
    return function(request: HTTPServerRequest, response: HTTPServerResponse): function
        local ctx = {}
        return next_handler(request, response, ctx)
    end
end

local function favourite_day(_, _, ctx: {string: DateTime}): string
    return "My favourite day is " .. ctx.datetime:to_date_string()
end

local long_chain = chain { context, insert_datetime }

server:get("/", chain { context, insert_datetime } (homepage) as HTTPServerCallback)
server:get("/fn", long_chain(favourite_day) as HTTPServerCallback)

server:run()
