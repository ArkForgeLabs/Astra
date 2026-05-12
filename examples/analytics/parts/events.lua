local serde = require("serde")

---@param server HTTPServer
---@param db Database
local function handle_event_ingestion(server, db)
  server:post("/apiv1/events", function(request, response)
    local body = request:body()
    if not body then
      response:set_status_code(400)
      return "Invalid request body"
    end

    local event_data = body:json()
    if not event_data or type(event_data) ~= "table" then
      response:set_status_code(400)
      return "Invalid JSON data"
    end

    -- Validate required fields
    if not event_data.event_type then
      response:set_status_code(400)
      return "Missing event_type field"
    end

    -- Insert event into database
    local success, result = pcall(function()
      local properties_json = ""
      if event_data.properties and type(event_data.properties) == "table" then
        properties_json = serde.json.encode(event_data.properties)
      end

      return db:execute("INSERT INTO events (event_type, user_id, session_id, properties) VALUES ($1, $2, $3, $4);", {
        event_data.event_type,
        event_data.user_id or nil,
        event_data.session_id or nil,
        properties_json,
      })
    end)

    if not success then
      response:set_status_code(500)
      return "Database error: " .. tostring(result)
    end

    response:set_status_code(201)
    return { success = true, message = "Event recorded" }
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_batch_event_ingestion(server, db)
  server:post("/apiv1/events/batch", function(request, response)
    local body = request:body()
    if not body then
      response:set_status_code(400)
      return "Invalid request body"
    end

    local events = body:json()
    if not events or type(events) ~= "table" then
      response:set_status_code(400)
      return "Invalid JSON data"
    end

    -- Validate that we have an array of events
    if #events == 0 then
      response:set_status_code(400)
      return "Empty events array"
    end

    -- Process each event
    local results = {}
    for i, event_data in ipairs(events) do
      local success, result = pcall(function()
        local properties_json = ""
        if event_data.properties and type(event_data.properties) == "table" then
          properties_json = serde.json.encode(event_data.properties)
        end

        return db:execute("INSERT INTO events (event_type, user_id, session_id, properties) VALUES ($1, $2, $3, $4);", {
          event_data.event_type,
          event_data.user_id or nil,
          event_data.session_id or nil,
          properties_json,
        })
      end)

      if not success then
        table.insert(results, { success = false, error = tostring(result) })
      else
        table.insert(results, { success = true })
      end
    end

    response:set_status_code(201)
    return { success = true, results = results }
  end)
end

---@param server HTTPServer
---@param db Database
local function initialize_events(server, db)
  handle_event_ingestion(server, db)
  handle_batch_event_ingestion(server, db)
end

return initialize_events
