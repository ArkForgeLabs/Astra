local server = Astra.http.server:new()

require("middleware")
local middleware = Astra.http.middleware

local context = middleware.context
local logger = middleware.logger
local chain = middleware.chain
local html = middleware.html

--- `on Entry:`
--- Inserts `Astra.datetime.new_utc_now()` into `ctx.datetime`
---
--- `on Leave:`
---
--- `Depends on:`
--- `context`
local function insert_datetime(next_handler)
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    return function(request, response, ctx)
        ctx.datetime = Astra.datetime.new_utc_now()
        local result = next_handler(request, response, ctx)
        return result
    end
end

---@param ctx { datetime: DateTime }
local function favourite_day(_, _, ctx)
    local today = string.format("%d/%d/%d", ctx.datetime:get_day(), ctx.datetime:get_month(), ctx.datetime:get_year())
    return "My favourite day is " .. today
end

---@param req HTTPServerRequest
---@param res HTTPServerResponse
local function homepage(req, res)
    return "Hi there!"
end

server:get("/", logger(html((homepage))))
server:get("/fn", chain { context, logger, insert_datetime, html } (favourite_day))

server:run()
