local datetime = require("datetime")
local http = require("http")

local server = http.server.new()
local chain = http.middleware.chain

local function homepage()
  return "Hi there!"
end

--- `on Entry:`
--- Inserts `Astra.datetime.new()` into `ctx.datetime`
---
--- `Depends on:`
--- `context`
local function insert_datetime(next_handler)
  ---@param request HTTPServerRequest
  ---@param response HTTPServerResponse
  return function(request, response, ctx)
    ctx.datetime = datetime.new()
    local result = next_handler(request, response, ctx)
    return result
  end
end

--- `on Entry:`
--- Creates a new `ctx` table and passes it as a third argument into the `next_handler`
local function context(next_handler)
  ---@param request HTTPServerRequest
  ---@param response HTTPServerResponse
  return function(request, response)
    local ctx = {}
    return next_handler(request, response, ctx)
  end
end

---@param ctx { datetime: DateTime }
local function favourite_day(_, _, ctx)
  return "My favourite day is " .. ctx.datetime:to_date_string()
end

local long_chain = chain({ context, insert_datetime })

server:get("/", chain({ context, insert_datetime })(homepage))
server:get("/fn", long_chain(favourite_day))

server:run()
