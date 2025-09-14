--- SQL driver
---@class Database
---@field execute fun(database: Database, sql: string, parameters: table | nil)
---@field query_one fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field query_all fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field close fun(database: Database)

---Opens a new SQL connection using the provided URL and returns a table representing the connection.
---@param database_type "sqlite"|"postgres" The type of database to connect to.
---@param url string The URL of the SQL database to connect to.
---@param max_connections number? Max number of connections to the database pool
---@return Database Database that represents the SQL connection.
---@nodiscard
local function connect(database_type, url, max_connections)
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__database_connect(database_type, url, max_connections)
end

return { new = connect }
