--[[
    THIS IS PURELY FOR TESTING, DO NOT USE AS EXAMPLE!
]]

require("../lua/astra_bundle")

-- local db = database_connect("postgres://astra_postgres:password@localhost/astr_database")
-- db:execute("CREATE TABLE IF NOT EXISTS test (id SERIAL PRIMARY KEY, name TEXT)", {});

http_request("https://myip.wtf/json", nil, function(response)
    pretty_print(response:status_code())
    pretty_print(response:headers())
    pretty_print(response:remote_address())
    pretty_print(response:body():json())
end)

Astra.get("/", function(req, res)
    res:set_status_code(300)
    res:set_header("test", "VALLLL")
    req:body():text()

    pretty_print(res:get_headers())
    -- local result = db:query_one("SELECT * FROM test;", {});
    -- print(utils.pretty_table(result))

    return "hello from default Astra instance! " .. Astra.version
end)

-- Astra.get("/insert", function(req)
--     -- local queries = utils.parseurl(req:uri())
--     -- local result = db:query_all("INSERT INTO test (name) VALUES ($1)", {queries.name});
--     -- print(utils.pretty_table(result))

--     return "Successfully inserted name: " .. "queries.name"
-- end)

-- Astra.static_file("/examples", "examples/dev.lua")
