---@param server HTTPServer
---@param db Database
local function handle_ab_test_creation(server, db)
  server:post("/apiv1/ab-tests", function(request, response)
    local body = request:body()
    if not body then
      response:set_status_code(400)
      return "Invalid request body"
    end

    local test_data = body:json()
    if not test_data or type(test_data) ~= "table" then
      response:set_status_code(400)
      return "Invalid JSON data"
    end

    -- Validate required fields
    if not test_data.test_name then
      response:set_status_code(400)
      return "Missing test_name field"
    end

    if not test_data.variants or type(test_data.variants) ~= "table" then
      response:set_status_code(400)
      return "Missing or invalid variants field"
    end

    -- Insert A/B test
    local test_id
    local success, result = pcall(function()
      local test_result = db:execute("INSERT INTO ab_tests (test_name, description) VALUES ($1, $2);", {
        test_data.test_name,
        test_data.description or nil,
      })
      local test_id_query = db:query_one("SELECT last_insert_rowid() as id")
      if not test_id_query then
        error("No variant found for this test")
      end
      test_id = test_id_query["id"]

      return test_result
    end)
    if not success then
      response:set_status_code(500)
      return "Database error: " .. tostring(result)
    end

    -- Insert variants
    for i, variant in ipairs(test_data.variants) do
      local success, result = pcall(function()
        return db:execute(
          "INSERT INTO ab_variants (test_id, variant_name, description, weight) VALUES ($1, $2, $3, $4);",
          {
            test_id,
            variant.variant_name,
            variant.description or nil,
            variant.weight or 1.0,
          }
        )
      end)

      if not success then
        response:set_status_code(500)
        return "Database error inserting variant: " .. tostring(result)
      end
    end

    response:set_status_code(201)
    return { success = true, test_id = test_id }
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_list_ab_tests(server, db)
  server:get("/apiv1/ab-tests", function(request, response)
    local tests = db:query_all([[
            SELECT t.id, t.test_name, t.description, t.created_at,
                   json_group_array(
                       json_object(
                           'id', v.id,
                           'variant_name', v.variant_name,
                           'description', v.description,
                           'weight', v.weight
                       )
                   ) as variants
            FROM ab_tests t
            LEFT JOIN ab_variants v ON t.id = v.test_id
            GROUP BY t.id
            ORDER BY t.created_at DESC
            ]])

    return { tests = tests }
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_get_ab_test(server, db)
  server:get("/apiv1/ab-tests/{test_id}", function(request, response)
    local test_id = request:params()["test_id"]
    if not test_id then
      response:set_status_code(400)
      return "Missing test_id parameter"
    end

    local test = db:query_one(
      [[
            SELECT t.id, t.test_name, t.description, t.created_at,
                   json_group_array(
                       json_object(
                           'id', v.id,
                           'variant_name', v.variant_name,
                           'description', v.description,
                           'weight', v.weight
                       )
                   ) as variants
            FROM ab_tests t
            LEFT JOIN ab_variants v ON t.id = v.test_id
            WHERE t.id = $1
            GROUP BY t.id
            ]],
      { test_id }
    )

    if not test then
      response:set_status_code(404)
      return "Test not found"
    end

    return test
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_assign_user(server, db)
  server:post("/apiv1/ab-tests/{test_id}/assign", function(request, response)
    local test_id = request:params()["test_id"]
    if not test_id then
      response:set_status_code(400)
      return "Missing test_id parameter"
    end

    local body = request:body()
    if not body then
      response:set_status_code(400)
      return "Invalid request body"
    end

    local assign_data = body:json()
    if not assign_data or type(assign_data) ~= "table" then
      response:set_status_code(400)
      return "Invalid JSON data"
    end

    local user_id = assign_data.user_id
    if not user_id then
      response:set_status_code(400)
      return "Missing user_id field"
    end

    -- Check if already assigned
    local existing_assignment =
      db:query_one("SELECT variant_id FROM ab_assignments WHERE user_id = $1 AND test_id = $2", { user_id, test_id })

    if existing_assignment then
      -- Return existing assignment
      local variant =
        db:query_one("SELECT variant_name FROM ab_variants WHERE id = $1", { existing_assignment.variant_id })
      if not variant then
        response:set_status_code(404)
        return "No variant found for this test"
      end

      return {
        user_id = user_id,
        test_id = test_id,
        variant = variant.variant_name,
      }
    end

    -- Get all variants for this test with weights
    local variants =
      db:query_all("SELECT id, variant_name, weight FROM ab_variants WHERE test_id = $1 ORDER BY id", { test_id })

    if not variants or #variants == 0 then
      response:set_status_code(404)
      return "No variants found for this test"
    end

    -- Calculate cumulative weights for weighted random assignment
    local total_weight = 0
    for i, variant in ipairs(variants) do
      total_weight = total_weight + variant.weight
    end

    -- Generate random number between 0 and total_weight
    local random_value = math.random() * total_weight
    local cumulative_weight = 0
    local selected_variant_id = variants[1].id

    for i, variant in ipairs(variants) do
      cumulative_weight = cumulative_weight + variant.weight
      if random_value <= cumulative_weight then
        selected_variant_id = variant.id
        break
      end
    end

    -- Assign user to variant
    local success, result = pcall(function()
      return db:execute(
        "INSERT INTO ab_assignments (user_id, test_id, variant_id) VALUES ($1, $2, $3);",
        { user_id, test_id, selected_variant_id }
      )
    end)

    if not success then
      response:set_status_code(500)
      return "Database error: " .. tostring(result)
    end

    -- Return assigned variant
    local variant = db:query_one("SELECT variant_name FROM ab_variants WHERE id = $1", { selected_variant_id })
    if not variant then
      response:set_status_code(404)
      return "No variant found for this test"
    end

    return {
      user_id = user_id,
      test_id = test_id,
      variant = variant.variant_name,
    }
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_track_metric(server, db)
  server:post("/apiv1/ab-tests/{test_id}/track", function(request, response)
    local test_id = request:params()["test_id"]
    if not test_id then
      response:set_status_code(400)
      return "Missing test_id parameter"
    end

    local body = request:body()
    if not body then
      response:set_status_code(400)
      return "Invalid request body"
    end

    local track_data = body:json()
    if not track_data or type(track_data) ~= "table" then
      response:set_status_code(400)
      return "Invalid JSON data"
    end

    local user_id = track_data.user_id
    if not user_id then
      response:set_status_code(400)
      return "Missing user_id field"
    end

    local metric_name = track_data.metric_name
    if not metric_name then
      response:set_status_code(400)
      return "Missing metric_name field"
    end

    local value = track_data.value
    if value == nil then
      response:set_status_code(400)
      return "Missing value field"
    end

    -- Get user's assigned variant
    local assignment =
      db:query_one("SELECT variant_id FROM ab_assignments WHERE user_id = $1 AND test_id = $2", { user_id, test_id })

    if not assignment then
      response:set_status_code(400)
      return "User not assigned to this test"
    end

    -- Insert metric
    local success, result = pcall(function()
      return db:execute(
        "INSERT INTO ab_metrics (test_id, variant_id, metric_name, value) VALUES ($1, $2, $3, $4);",
        { test_id, assignment.variant_id, metric_name, value }
      )
    end)

    if not success then
      response:set_status_code(500)
      return "Database error: " .. tostring(result)
    end

    response:set_status_code(201)
    return { success = true, message = "Metric tracked" }
  end)
end

---@param server HTTPServer
---@param db Database
local function handle_get_results(server, db)
  server:get("/apiv1/ab-tests/{test_id}/results", function(request, response)
    local test_id = request:params()["test_id"]
    if not test_id then
      response:set_status_code(400)
      return "Missing test_id parameter"
    end

    -- Get test details
    local test = db:query_one("SELECT test_name, description FROM ab_tests WHERE id = $1", { test_id })

    if not test then
      response:set_status_code(404)
      return "Test not found"
    end

    -- Get metrics grouped by variant
    local results = db:query_all(
      [[
            SELECT
                v.variant_name,
                COUNT(am.id) as metric_count,
                AVG(am.value) as average_value,
                MIN(am.value) as min_value,
                MAX(am.value) as max_value,
                json_group_array(
                    json_object(
                        'metric_name', am.metric_name,
                        'value', am.value,
                        'created_at', am.created_at
                    )
                ) as metrics
            FROM ab_metrics am
            JOIN ab_variants v ON am.variant_id = v.id
            WHERE am.test_id = $1
            GROUP BY v.id, v.variant_name
            ORDER BY v.variant_name
            ]],
      { test_id }
    )

    return {
      test_name = test.test_name,
      description = test.description,
      results = results,
    }
  end)
end

---@param server HTTPServer
---@param db Database
local function initialize_ab_tests(server, db)
  handle_ab_test_creation(server, db)
  handle_list_ab_tests(server, db)
  handle_get_ab_test(server, db)
  handle_assign_user(server, db)
  handle_track_metric(server, db)
  handle_get_results(server, db)
end

return initialize_ab_tests
