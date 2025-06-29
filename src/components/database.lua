---@meta

---SQLx driver
---@class Database
local Database = {}

---@param sql string
---@param parameters table | nil
function Database:execute(sql, parameters) end

---@param sql string
---@param parameters table | nil
---@return table | nil
function Database:query_one(sql, parameters) end

---@param sql string
---@param parameters table | nil
---@return table | nil
function Database:query_all(sql, parameters) end

function Database:close() end

---Opens a new SQL connection using the provided URL and returns a table representing the connection.
---@param database_type "sqlite"|"postgres" The type of database to connect to.
---@param url string The URL of the SQL database to connect to.
---@param max_connections number? Max number of connections to the database pool
---@return Database Database that represents the SQL connection.
---@nodiscard
function Astra.database_connect(database_type, url, max_connections) end
