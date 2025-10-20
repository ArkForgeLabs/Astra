--- SQL driver
global interface Database is userdata
    execute: function(database: Database, sql: string, parameters?: table)
    query_one: function(database: Database, sql: string, parameters?: table): table | nil
    query_all: function(database: Database, sql: string, parameters?: table): table | nil
    close: function(database: Database)
end

global enum DATABASE_TYPE
    "sqlite" "postgres"
end
local type astra_internal__database_connect = function(database_type: DATABASE_TYPE, url: string, max_connections?: number): Database
---Opens a new SQL connection using the provided URL and returns a table representing the connection.
local function connect(database_type: DATABASE_TYPE, url: string, max_connections?: number): Database
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__database_connect(database_type, url, max_connections)
end

return { new = connect }
