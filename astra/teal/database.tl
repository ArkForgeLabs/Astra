--- SQL driver
global interface Database is userdata
    execute: function(database: Database, sql: string, parameters?: table)
    query_one: function(database: Database, sql: string, parameters?: table): table | nil
    query_all: function(database: Database, sql: string, parameters?: table): table | nil
    query_pragma_int: function(database: Database, sql: string): number | nil
    query_pragma_text: function(database: Database, sql: string): string | nil
    close: function(database: Database)
end

---Some extra connection options for the databases
global record DatabaseConnectionOptions
    max_connections: integer?
    extensions: string[]? -- SQLite only
    extensions_with_entrypoint: {{string}}? -- SQLite only
    is_immutable: boolean? -- SQLite only
    other_options: {{string}}?
end

global enum DATABASE_TYPE
    "sqlite" "postgres"
end
local type astra_internal__database_connect = function(database_type: DATABASE_TYPE, url: string, connection_options?: DatabaseConnectionOptions): Database
---Opens a new SQL connection using the provided URL and returns a table representing the connection.
local function connect(database_type: DATABASE_TYPE, url: string, connection_options?: DatabaseConnectionOptions): Database
    if not connection_options then
        connection_options = {}
    end
    connection_options.max_connections = connection_options.max_connections
    connection_options.extensions = connection_options.extensions or {}
    connection_options.extensions_with_entrypoint = connection_options.extensions_with_entrypoint or
        {}    -- SQLite only
    connection_options.is_immutable = connection_options.is_immutable ~= nil and connection_options.is_immutable or
        false -- SQLite only
    connection_options.other_options = connection_options.other_options or {}

    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__database_connect(database_type, url, connection_options)
end

return { new = connect }
