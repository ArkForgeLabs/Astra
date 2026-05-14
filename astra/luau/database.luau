--!strict

type DatabaseConnectionOptions = {
  max_connections: number?,
  extensions: { string }?,
  extensions_with_entrypoint: { { string } }?,
  is_immutable: boolean?,
  other_options: { { string } }?,
}

type Database = {
  execute: (self: Database, sql: string, parameters: { any }?) -> (),
  query_one: (self: Database, sql: string, parameters: { any }?) -> { any }?,
  query_all: (self: Database, sql: string, parameters: { any }?) -> { { any } }?,
  query_pragma_int: (self: Database, sql: string) -> number?,
  query_pragma_text: (self: Database, sql: string) -> string?,
  close: (self: Database) -> (),
}

type DatabaseType = "sqlite" | "postgres"

local astra_internal__database_connect: (database_type: DatabaseType, url: string, connection_options: DatabaseConnectionOptions) -> Database

local function connect(
  database_type: DatabaseType,
  url: string,
  connection_options: DatabaseConnectionOptions?
): Database
  local opts = if connection_options then connection_options else {} :: DatabaseConnectionOptions
  opts.max_connections = opts.max_connections
  opts.extensions = opts.extensions or {}
  opts.extensions_with_entrypoint = opts.extensions_with_entrypoint or {}
  opts.is_immutable = if opts.is_immutable ~= nil then opts.is_immutable else false
  opts.other_options = opts.other_options or {}

  return astra_internal__database_connect(database_type, url, opts)
end

return { new = connect }
