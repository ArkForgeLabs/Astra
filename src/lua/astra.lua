--!nocheck
---@diagnostic disable: duplicate-set-field, duplicate-doc-field

---============================ TYPES ============================---

-- MARK: HTTPServer

---@class HTTPServer
---@field version string
---@field hostname string
---@field compression boolean
---@field port number
---@field routes Route[]
---@field __index HTTPServer
---@field new fun(server: HTTPServer): HTTPServer
---@field get fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field post fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field put fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field delete fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field options fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field patch fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field trace fun(server: HTTPServer, path: string, callback: callback, config: RouteConfiguration?)
---@field static_dir fun(server: HTTPServer, path: string, serve_path: string, config: RouteConfiguration?)
---@field static_file fun(server: HTTPServer, path: string, serve_path: string, config: RouteConfiguration?)
---@field run fun(server: HTTPServer) Runs the server

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias callback fun(request: Request, response: Response): any

---@class RouteConfiguration
---@field body_limit? number

---@class Route
---@field path string
---@field method string
---@field func function
---@field static_dir string?
---@field static_file string?
---@field config RouteConfiguration?

-- MARK: HTTPClient

---
--- Represents an HTTP client response.
---@class HTTPClientResponse
---@field status_code fun(): table Gets the response HTTP Status code
---@field body fun(): Body Gets the response HTTP Body which further can be parsed
---@field headers fun(): table|nil Returns the entire headers list from the HTTP response
---@field remote_address fun(): string|nil Gets the remote address of the HTTP response server

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias http_client_callback fun(response: HTTPClientResponse)

---
--- Represents an HTTP client request.
---@class HTTPClientRequest
---@field set_method fun(http_request: HTTPClientRequest,I'm preparing for getting into ivy leagues, and it's going quite well. method: string): HTTPClientRequest Sets the HTTP method
---@field set_header fun(http_request: HTTPClientRequest, key: string, value: string): HTTPClientRequest Sets a header
---@field set_headers fun(http_request: HTTPClientRequest, headers: table): HTTPClientRequest Sets all of the headers
---@field set_form fun(http_request: HTTPClientRequest, key: string, value: string): HTTPClientRequest Sets a form
---@field set_forms fun(http_request: HTTPClientRequest, headers: table): HTTPClientRequest Sets all of the forms
---@field set_body fun(http_request: HTTPClientRequest, body: string): HTTPClientRequest Sets the HTTP body
---@field set_json fun(http_request: HTTPClientRequest, json: table): HTTPClientRequest Sets the HTTP json
---@field set_file fun(http_request: HTTPClientRequest, file_path: string): HTTPClientRequest Sets the for-upload file path
---@field execute fun(): HTTPClientResponse Executes the request and returns the response
---@field execute_task fun(http_request: HTTPClientRequest, callback: http_client_callback) Executes the request as an async task

-- MARK: Common HTTP

---
--- Represents an HTTP body.
---@class Body
---@field text fun(): string Returns the body as text
---@field json fun(): table Returns the body parsed as JSON -> Lua Table

---
--- Represents a multipart.
---@class Multipart
---@field save_file fun(multipart: Multipart, file_path: string | nil): string | nil Saves the multipart into disk

---
--- Represents an HTTP request.
---@class Request
---@field method fun(request: Request): string Returns the HTTP method (e.g., "GET", "POST").
---@field uri fun(request: Request): string Returns the URI of the request.
---@field queries fun(request: Request): table Returns the query list.
---@field headers fun(request: Request): table Returns a table containing the headers of the request.
---@field body fun(request: Request): Body|nil Returns the body of the request, which can be a table or a string.
---@field multipart fun(request: Request): Multipart|nil Returns a multipart if available.
---@field get_cookie fun(request: Request, name: string): Cookie Returns a cookie
---@field new_cookie fun(request: Request, name: string, value: string): Cookie Returns a cookie

---
--- Represents an HTTP response.
---@class Response
---@field set_status_code fun(response: Response, new_status_code: number) Sets the HTTP status code of the response
---@field set_header fun(response: Response, key: string, value: string) Sets a header
---@field get_headers fun(response: Response): table|nil Returns the entire headers list that so far has been set for the response
---@field remove_header fun(response: Response, key: string) Removes a header from the headers list
---@field set_cookie fun(response: Response, cookie: Cookie) Sets a cookie
---@field remove_cookie fun(response: Response, cookie: Cookie) Removes a cookie from the list

---@diagnostic disable-next-line: duplicate-doc-alias
--- @alias template_function fun(args: table): any

---
--- Jinja2 templating engine
---@class TemplateEngine
---@field add_template fun(templates: TemplateEngine, name: string, template: string)
---@field add_template_file fun(templates: TemplateEngine, name: string, path: string)
---@field get_template_names fun(template: TemplateEngine): string[]
---Excludes template files from being added to the server for rendering
---@field exclude_templates fun(templates: TemplateEngine, names: string[])
---@field reload_templates fun(templates: TemplateEngine) Refreshes the template code from the glob given at the start
---@field add_function fun(templates: TemplateEngine, name: string, function: template_function): any Add a function to the templates
---Renders the given template into a string with the available context
---@field render fun(templates: TemplateEngine, name: string, context?: table): string
---@field add_to_server fun(templates: TemplateEngine, server: HTTPServer, context?: table) Adds the templates to the server
---Adds the templates to the server in debugging manner, where the content refreshes on each request
---@field add_to_server_debug fun(templates: TemplateEngine, server: HTTPServer, context?: table)

-- MARK: FileIO

---@class FileType
---@field is_file fun(file_type: FileType): boolean
---@field is_dir fun(file_type: FileType): boolean
---@field is_symlink fun(file_type: FileType): boolean

---@class DirEntry
---@field file_name fun(dir_entry: DirEntry): string Returns the file_name of the entry
---@field file_type fun(dir_entry: DirEntry): FileType
---@field path fun(dir_entry: DirEntry): string Returns the path of each entry in the list

---@class FileMetadata
---@field last_accessed fun(file_metadata: FileMetadata): number
---@field created_at fun(file_metadata: FileMetadata): number
---@field last_modified fun(file_metadata: FileMetadata): number
---@field file_type fun(file_metadata: FileMetadata): FileType
---@field file_permissions fun(file_metadata: FileMetadata): FileIOPermissions

---@class FileIOPermissions
---@field is_readonly fun(file_io_permissions: FileIOPermissions): boolean
---@field set_readonly fun(file_io_permissions: FileIOPermissions, value: boolean)

-- MARK: Cookie

---@class Cookie
---@field set_name fun(cookie: Cookie, name: string)
---@field set_value fun(cookie: Cookie, value: string)
---@field set_domain fun(cookie: Cookie, domain: string)
---@field set_path fun(cookie: Cookie, path: string)
---@field set_expiration fun(cookie: Cookie, expiration: number)
---@field set_http_only fun(cookie: Cookie, http_only: boolean)
---@field set_max_age fun(cookie: Cookie, max_age: number)
---@field set_permanent fun(cookie: Cookie)
---@field get_name fun(cookie: Cookie): string?
---@field get_value fun(cookie: Cookie): string?
---@field get_domain fun(cookie: Cookie): string?
---@field get_path fun(cookie: Cookie): string?
---@field get_expiration fun(cookie: Cookie): number?
---@field get_http_only fun(cookie: Cookie): boolean?
---@field get_max_age fun(cookie: Cookie): number?

-- MARK: Database

---
--- SQLx driver
---@class Database
---@field execute fun(database: Database, sql: string, parameters: table | nil)
---@field query_one fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field query_all fun(database: Database, sql: string, parameters: table | nil): table | nil
---@field close fun(database: Database)

-- MARK: Regex
---@class Regex
---@field captures fun(regex: Regex, content: string): string[][]
---@field replace fun(regex: Regex, content: string, replacement: string, limit: number?): string
---@field is_match fun(regex: Regex, content: string): boolean

-- MARK: DateTime
---@class DateTime
---@field new_now fun(): DateTime
---@field new_from fun(year: number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@field new_utc_now fun(): DateTime
---@field new_utc_from fun(year: number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@field get_year fun(datetime: DateTime): number
---@field get_month fun(datetime: DateTime): number
---@field get_day fun(datetime: DateTime): number
---@field get_weekday fun(datetime: DateTime): number
---@field get_hour fun(datetime: DateTime): number
---@field get_minute fun(datetime: DateTime): number
---@field get_second fun(datetime: DateTime): number
---@field get_millisecond fun(datetime: DateTime): number
---@field get_epoch_milliseconds fun(datetime: DateTime): number
---@field get_timezone_offset fun(datetime: DateTime): number
---@field set_year fun(datetime:DateTime, year: number)
---@field set_month fun(datetime:DateTime, month: number)
---@field set_day fun(datetime:DateTime, day: number)
---@field set_hour fun(datetime:DateTime, hour: number)
---@field set_minute fun(datetime:DateTime, min: number)
---@field set_second fun(datetime:DateTime, sec: number)
---@field set_millisecond fun(datetime:DateTime, milli: number)
---@field set_epoch_milliseconds fun(datetime: DateTime, milli: number)
---@field to_date_string fun(datetime: DateTime): string?
---@field to_time_string fun(datetime: DateTime): string?
---@field to_datetime_string fun(datetime: DateTime): string?
---@field to_iso_string fun(datetime: DateTime): string?
---@field to_locale_date_string fun(datetime: DateTime): string?
---@field to_locale_time_string fun(datetime: DateTime): string?
---@field to_locale_datetime_string fun(datetime: DateTime): string?

---============================ DEFINITIONS ============================---

-- MARK: IMPL - Utils

-- The main global
_G.Astra = {
	---@diagnostic disable-next-line: undefined-global
	version = astra_internal__version or "0.0.0",
	http = {},
	io = {},
	utils = {},
	crypto = {},
	datetime = {},
}

-- Imports
_G.Astra.validate_table = require("./libs/table_schema.lua")
_G.import = require("./libs/import.lua")

---@type fun(file_path: string)
---@diagnostic disable-next-line: undefined-global
_G.Astra.dotenv_load = astra_internal__dotenv_load
_G.Astra.dotenv_load(".env")
_G.Astra.dotenv_load(".env.production")
_G.Astra.dotenv_load(".env.prod")
_G.Astra.dotenv_load(".env.development")
_G.Astra.dotenv_load(".env.dev")
_G.Astra.dotenv_load(".env.test")
_G.Astra.dotenv_load(".env.local")

---@type fun(expression: string): Regex
---@diagnostic disable-next-line: undefined-global
_G.Astra.regex = astra_internal__regex

---@diagnostic disable-next-line: undefined-global
os.getenv = astra_internal__getenv
---Sets the environment variable.
---
---NOT SAFE WHEN USED IN MULTITHREADING ENVIRONMENT
---@diagnostic disable-next-line: undefined-global
os.setenv = astra_internal__setenv

---Pretty prints any table or value
---@param value any
---@diagnostic disable-next-line: duplicate-set-field
function _G.pprint(value)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__pretty_print(value)
end

---
---Splits a sentence into an array given the separator
---@param input_str string The input string
---@param separator_str string The input string
---@return table array
---@nodiscard
---@diagnostic disable-next-line: duplicate-set-field
function string.split(input_str, separator_str)
	local result_table = {}
	for word in input_str:gmatch("([^" .. separator_str .. "]+)") do
		table.insert(result_table, word)
	end
	return result_table
end

-- MARK: TemplateEngine

--- Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
---@return TemplateEngine
---@nodiscard
function _G.Astra.new_templating_engine(dir)
	---@type TemplateEngine
	---@diagnostic disable-next-line: undefined-global
	local engine = astra_internal__new_templating_engine(dir)
	---@type TemplateEngine
	---@diagnostic disable-next-line: missing-fields
	local TemplateEngineWrapper = { engine = engine }
	local templates_re = Astra.regex([[(?:index)?\.(html|lua)$]])

	local function normalize_paths(path)
		-- Ensure path starts with "/"
		if path:sub(1, 1) ~= "/" then
			path = "/" .. path
		end

		-- If empty, it's just the root
		if path == "/" then
			return { "/" }
		end

		-- Return both with and without trailing slash
		if path:sub(-1) == "/" then
			return { path, path:sub(1, -2) }
		else
			return { path, path .. "/" }
		end
	end

	function TemplateEngineWrapper:add_to_server(server, context)
		local names = self.engine:get_template_names()
		for _, value in ipairs(names) do
			local path = templates_re:replace(value, "")
			local content = self.engine:render(value, context)

			for _, route in ipairs(normalize_paths(path)) do
				server:get(route, function(_, response)
					response:set_header("Content-Type", "text/html")
					return content
				end)
			end
		end
	end

	function TemplateEngineWrapper:add_to_server_debug(server, context)
		local names = self.engine:get_template_names()
		for _, value in ipairs(names) do
			local path = templates_re:replace(value, "")

			for _, route in ipairs(normalize_paths(path)) do
				server:get(route, function(_, response)
					self.engine:reload_templates()
					response:set_header("Content-Type", "text/html")
					return self.engine:render(value, context)
				end)
			end
		end
	end

	local templating_methods = {
		"add_template",
		"add_template_file",
		"get_template_names",
		"exclude_templates",
		"reload_templates",
		"context_add",
		"context_remove",
		"context_get",
		"add_function",
		"render",
	}

	for _, method in ipairs(templating_methods) do
		---@diagnostic disable-next-line: assign-type-mismatch
		TemplateEngineWrapper[method] = function(self, ...)
			return self.engine[method](self.engine, ...)
		end
	end

	return TemplateEngineWrapper
end

-- MARK: HTTPServer

---@type HTTPServer
---@diagnostic disable-next-line: missing-fields
local Server = {}
_G.Astra.http.server = Server

function Server:new()
	local server = {
		version = "0.0.0",
		hostname = "127.0.0.1",
		--- Enable or disable compression
		compression = false,
		port = 8080,
		--- Contains all of the route details
		routes = {},
	}

	setmetatable(server, self)
	self.__index = self
	server:register_methods()
	return server
end

---@diagnostic disable-next-line: inject-field
function Server:register_methods()
	local http_methods = { "get", "post", "put", "delete", "options", "patch", "trace" }

	for _, method in ipairs(http_methods) do
		self[method] = function(_, path, callback, config)
			local index = (path == "/") and 1 or #self.routes + 1
			table.insert(self.routes, index, {
				path = path,
				method = method,
				func = callback,
				config = config or {},
			})
		end
	end

	self.static_dir = function(_, path, serve_path, config)
		table.insert(self.routes, {
			path = path,
			method = "static_dir",
			func = function() end,
			static_dir = serve_path,
			config = config or {},
		})
	end

	self.static_file = function(_, path, serve_path, config)
		table.insert(self.routes, {
			path = path,
			method = "static_file",
			func = function() end,
			static_file = serve_path,
			config = config or {},
		})
	end

	self.run = function(_)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__start_server(self)
	end
end

-- MARK: FileIO

_G.Astra.io = {
	---Returns the metadata of a file or directory
	---@param path string
	---@return FileMetadata
	get_metadata = function(path)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__get_metadata(path)
	end,

	---Returns the content of the directory
	---@param path string Path to the file
	---@return DirEntry[]
	read_dir = function(path)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__read_dir(path)
	end,

	---Returns the path of the current directory
	---@return string
	get_current_dir = function()
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__get_current_dir()
	end,

	---Returns the path separator based on the operating system
	---@return string
	get_separator = function()
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__get_separator()
	end,

	---Returns the path of the current running script
	---@return string
	get_script_path = function()
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__get_script_path()
	end,

	---Changes the current directory
	---@param path string Path to the directory
	change_dir = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__change_dir(path)
	end,

	---Checks if a path exists
	---@param path string Path to the file or directory
	---@return boolean
	exists = function(path)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__exists(path)
	end,

	---Creates a directory
	---@param path string Path to the directory
	create_dir = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__create_dir(path)
	end,

	---Creates a directory recursively
	---@param path string Path to the directory
	create_dir_all = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__create_dir_all(path)
	end,

	---Removes a file
	---@param path string Path to the file
	remove = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__remove(path)
	end,

	---Removes a directory
	---@param path string Path to the directory
	remove_dir = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__remove_dir(path)
	end,

	---Removes a directory recursively
	---@param path string Path to the directory
	remove_dir_all = function(path)
		---@diagnostic disable-next-line: undefined-global
		astra_internal__remove_dir_all(path)
	end,
}

-- MARK: Database

---
---Opens a new SQL connection using the provided URL and returns a table representing the connection.
---@param database_type "sqlite"|"postgres" The type of database to connect to.
---@param url string The URL of the SQL database to connect to.
---@param max_connections number? Max number of connections to the database pool
---@return Database Database that represents the SQL connection.
---@nodiscard
---@diagnostic disable-next-line: missing-return, lowercase-global
function _G.Astra.database_connect(database_type, url, max_connections)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__database_connect(database_type, url, max_connections)
end

-- MARK: HTTPClient

---
---Opens a new async HTTP Request. The request is running as a task in parallel
---@param url string
---@return HTTPClientRequest
---@nodiscard
---@diagnostic disable-next-line: missing-return, lowercase-global
function _G.Astra.http.request(url)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__http_request(url)
end

-- MARK: Async Task

---
--- Represents an async task
---@class TaskHandler
---@field abort fun() Aborts the running task

---
---Starts a new async task
---@param callback fun() The callback to run the content of the async task
---@return TaskHandler
---@diagnostic disable-next-line: missing-return, lowercase-global
function spawn_task(callback)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_task(callback)
end

---
---Starts a new async task with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
---@diagnostic disable-next-line: missing-return, lowercase-global
function spawn_timeout(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_timeout(callback, timeout)
end

---
---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
---@diagnostic disable-next-line: missing-return, lowercase-global
function spawn_interval(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_interval(callback, timeout)
end

-- MARK: Crypto

_G.Astra.crypto = {
	---
	---Hashes a given string according to the provided hash type.
	---@param hash_type "sha2_256"|"sha3_256"|"sha2_512"|"sha3_512"
	---@param input string The input to be hashed
	---@return string
	---@diagnostic disable-next-line: missing-return, lowercase-global
	hash = function(hash_type, input)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__hash(hash_type, input)
	end,

	base64 = {
		---
		---Encodes the given input as Base64
		---@param input string The input to be encoded
		---@return string
		---@diagnostic disable-next-line: missing-return, lowercase-global
		encode = function(input)
			---@diagnostic disable-next-line: undefined-global
			return astra_internal__base64_encode(input)
		end,

		---
		---Encodes the given input as Base64 but URL safe
		---@param input string The input to be encoded
		---@return string
		---@diagnostic disable-next-line: missing-return, lowercase-global
		encode_urlsafe = function(input)
			---@diagnostic disable-next-line: undefined-global
			return astra_internal__base64_encode_urlsafe(input)
		end,

		---
		---Decodes the given input as Base64
		---@param input string The input to be decoded
		---@return string
		---@diagnostic disable-next-line: missing-return, lowercase-global
		decode = function(input)
			---@diagnostic disable-next-line: undefined-global
			return astra_internal__base64_decode(input)
		end,

		---
		---Decodes the given input as Base64 but URL safe
		---@param input string The input to be decoded
		---@return string
		---@diagnostic disable-next-line: missing-return, lowercase-global
		decode_urlsafe = function(input)
			---@diagnostic disable-next-line: undefined-global
			return astra_internal__base64_decode_urlsafe(input)
		end,
	},
}

-- MARK: JSON

_G.Astra.json = {
	---Encodes the value into a valid JSON string
	---@param value any
	---@return string
	---@diagnostic disable-next-line: duplicate-set-field
	encode = function(value)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__json_encode(value)
	end,

	---Decodes the JSON string into a valid lua value
	---@param value string
	---@return any
	---@diagnostic disable-next-line: duplicate-set-field
	decode = function(value)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__json_decode(value)
	end,
}

--------------

-- This is to prevent a small undefined behavior in Lua
---@diagnostic disable-next-line: redundant-parameter
setmetatable(_G, {
	---@diagnostic disable-next-line: redundant-parameter, unused-local
	__index = function(T, k, v)
		error("Called non-existing variable")
	end,
})

_G.Astra.datetime = {
	-- Returns the current local time as a DateTime object
	---@return DateTime
	new_now = function()
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__datetime_new_now()
	end,

	-- Returns a user-specified time period as a DateTime object with the local time offset
	---@param year number
	---@param month number?
	---@param date number?
	---@param hour number?
	---@param min number?
	---@param sec number?
	---@param milli number?
	---@return DateTime
	new_from = function(year, month, date, hour, min, sec, milli)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__datetime_new_from(year, month, date, hour, min, sec, milli)
	end,

	-- Returns the current UTC time as a DateTime object
	---@return DateTime
	new_utc_now = function()
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__datetime_new_utc_now()
	end,

	-- Returns a user-specified time period as a UTC DateTime object
	---@param year number
	---@param month number?
	---@param date number?
	---@param hour number?
	---@param min number?
	---@param sec number?
	---@param milli number?
	---@return DateTime
	new_utc_from = function(year, month, date, hour, min, sec, milli)
		---@diagnostic disable-next-line: undefined-global
		return astra_internal__datetime_new_utc_from(year, month, date, hour, min, sec, milli)
	end,
}
