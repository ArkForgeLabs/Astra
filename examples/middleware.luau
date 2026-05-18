--!strict

local datetime = require("@astra/datetime")
local http = require("@astra/http")

local server = http.server.new()
local chain = http.middleware.chain

local function homepage()
  return "Hi there!"
end

local function insert_datetime(next_handler)
  return function(request, response, ctx)
    ctx.datetime = datetime.new()
    local result = next_handler(request, response, ctx)
    return result
  end
end

local function context(next_handler)
  return function(request, response)
    local ctx = {}
    return next_handler(request, response, ctx)
  end
end

local function favourite_day(_, _, ctx)
  return "My favourite day is " .. ctx.datetime:to_date_string()
end

local long_chain = chain({ context, insert_datetime })

server:get("/", chain({ context, insert_datetime })(homepage))
server:get("/fn", long_chain(favourite_day))

server:run()
