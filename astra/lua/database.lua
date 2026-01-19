--- SQL driver
---@class Database
---@field execute fun(database: Database, sql: string, parameters: table | nil)
---@field query_one fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field query_all fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field query_pragma_int fun(database: Database, sql: string): number | nil
---@field query_pragma_text fun(database: Database, sql: string): string | nil
---@field close fun(database: Database)

---Some extra connection options for the databases
---@class DatabaseConnectionOptions
---@field max_connections integer?
---@field extensions string[]? -- SQLite only
---@field extensions_with_entrypoint string[][]? -- SQLite only
---@field is_immutable boolean? -- SQLite only
---@field other_options string[][]?

---Opens a new SQL connection using the provided URL and returns a table representing the connection.
---@param database_type "sqlite"|"postgres" The type of database to connect to.
---@param url string The URL of the SQL database to connect to.
---@param connection_options DatabaseConnectionOptions? Max number of connections to the database pool
---@return Database Database that represents the SQL connection.
---@nodiscard
local function connect(database_type, url, connection_options)
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
