--!strict

local http = require("@astra/http")

local server = http.server.new()

-- A simple GET index route with text return
server:get("/", function()
  return "hello from default Astra instance! " .. ASTRA_VERSION
end)

print("🚀 Listening at: http://" .. tostring(server.hostname) .. ":" .. tostring(server.port))
