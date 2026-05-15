--!nocheck
--!nolint

--- SQL driver
type Database = {
  execute: (database: Database, sql: string, parameters: { any }?) -> (),
  query_one: (database: Database, sql: string, parameters: { any }?) -> { any }?,
  query_all: (database: Database, sql: string, parameters: { any }?) -> { { any } }?,
  query_pragma_int: (database: Database, sql: string) -> number?,
  query_pragma_text: (database: Database, sql: string) -> string?,
  close: (database: Database) -> (),
}

--- Some extra connection options for the databases
type DatabaseConnectionOptions = {
  max_connections: number?,
  --- SQLite only
  extensions: { string }?,
  --- SQLite only
  extensions_with_entrypoint: { { string } }?,
  --- SQLite only
  is_immutable: boolean?,
  other_options: { { string } }?,
}

--- Opens a new SQL connection using the provided URL and returns a table representing the connection.
local function connect(
  database_type: "sqlite" | "postgres",
  url: string,
  connection_options: DatabaseConnectionOptions?
): Database
  if not connection_options then
    connection_options = {}
  end
  connection_options.max_connections = connection_options.max_connections
  connection_options.extensions = connection_options.extensions or {}
  connection_options.extensions_with_entrypoint = connection_options.extensions_with_entrypoint or {}
  connection_options.is_immutable = connection_options.is_immutable ~= nil and connection_options.is_immutable or false
  connection_options.other_options = connection_options.other_options or {}

  return astra_internal__database_connect(database_type, url, connection_options)
end

return { new = connect }
