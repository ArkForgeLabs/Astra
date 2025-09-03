---@meta

--[[
    All of the smaller scale components that are not big enough to need their own files, are here
]]

import = require

---@param modName string
function import(modName)
	---@diagnostic disable-next-line: param-type-mismatch, undefined-global
	local ok, import_result = pcall(astra_internal__import, modName)
	if not ok then
		ok, require_result = require(modName)
		if not ok then
			error("Failed to load module.\nImport Error:" .. import_result .. "\nError: " .. require_result)
		end
		return require_result
	else
		return import_result
	end
end

---Pretty prints any table or value
---@param value any
function pprint(value)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__pretty_print(value)
end

---Represents an async task
---@class TaskHandler
---@field abort fun() Aborts the running task
---@field await fun() Waits for the task to finish

---Starts a new async task
---@param callback fun() The callback to run the content of the async task
---@return TaskHandler
function spawn_task(callback)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_task(callback)
end

---Starts a new async task with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
function spawn_timeout(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_timeout(callback, timeout)
end

---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
function spawn_interval(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_interval(callback, timeout)
end

---Splits a sentence into an array given the separator
---@param input_str string The input string
---@param separator_str string The input string
---@return table array
---@nodiscard
function string.split(input_str, separator_str)
	local result_table = {}
	for word in input_str:gmatch("([^" .. separator_str .. "]+)") do
		table.insert(result_table, word)
	end
	return result_table
end

---Load your own file into env
---@param file_path string
function Astra.dotenv_load(file_path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__dotenv_load(file_path)
end

Astra.dotenv_load(".env")
Astra.dotenv_load(".env.production")
Astra.dotenv_load(".env.prod")
Astra.dotenv_load(".env.development")
Astra.dotenv_load(".env.dev")
Astra.dotenv_load(".env.test")
Astra.dotenv_load(".env.local")

---@param key string
function os.getenv(key)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__getenv(key)
end

---Sets the environment variable.
---
---NOT SAFE WHEN USED IN MULTITHREADING ENVIRONMENT
---@param key string
---@param value string
function os.setenv(key, value)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__setenv(key, value)
end

Astra.json = {}

---Encodes the value into a valid JSON string
---@param value any
---@return string
function Astra.json.encode(value)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__json_encode(value)
end

---Decodes the JSON string into a valid lua value
---@param value string
---@return any
function Astra.json.decode(value)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__json_decode(value)
end

---@class Regex
---@field captures fun(regex: Regex, content: string): string[][]
---@field replace fun(regex: Regex, content: string, replacement: string, limit: number?): string
---@field is_match fun(regex: Regex, content: string): boolean

---@param expression string
---@return Regex
function Astra.regex(expression)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__regex(expression)
end

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
function Astra.database_connect(database_type, url, max_connections)
    ---@diagnostic disable-next-line: undefined-global
	return astra_internal__database_connect(database_type, url, max_connections)
end

Astra.crypto = {}

---Hashes a given string according to the provided hash type.
---@param hash_type "sha2_256"|"sha3_256"|"sha2_512"|"sha3_512"
---@param input string The input to be hashed
---@return string
function Astra.crypto.hash(hash_type, input)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__hash(hash_type, input)
end

Astra.crypto.base64 = {}

---Encodes the given input as Base64
---@param input string The input to be encoded
---@return string
function Astra.crypto.base64.encode(input)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__base64_encode(input)
end

---Encodes the given input as Base64 but URL safe
---@param input string The input to be encoded
---@return string
function Astra.crypto.base64.encode_urlsafe(input)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__base64_encode_urlsafe(input)
end

---Decodes the given input as Base64
---@param input string The input to be decoded
---@return string
function Astra.crypto.base64.decode(input)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__base64_decode(input)
end

---Decodes the given input as Base64 but URL safe
---@param input string The input to be decoded
---@return string
function Astra.crypto.base64.decode_urlsafe(input)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__base64_decode_urlsafe(input)
end
