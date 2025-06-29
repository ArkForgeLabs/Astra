---@meta

Astra.http = {}

---Opens a new async HTTP Request. The request is running as a task in parallel
---@param url string
---@return HTTPClientRequest
---@nodiscard
function Astra.http.request(url) end

Astra.http.server = {}

---@return HTTPServer
function Astra.http.server:new() end

---@class HTTPServer
---@field __index HTTPServer
local HTTPServer = {
    version = "0.0.0",
    hostname = "127.0.0.1",
    compression = false,
    port = 8080,
    routes = {}
}

---@return HTTPServer
function HTTPServer:new() end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:get(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:post(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:put(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:delete(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:options(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:patch(path, callback, config) end

---@param path string
---@param callback callback
---@param config RouteConfiguration?
function HTTPServer:trace(path, callback, config) end

---@param path string
---@param serve_path string
---@param config RouteConfiguration?
function HTTPServer:static_dir(path, serve_path, config) end

---@param path string
---@param serve_path string
---@param config RouteConfiguration?
function HTTPServer:static_file(path, serve_path, config) end

---Runs the server
function HTTPServer:run() end

---@alias callback fun(request: Request, response: Response): any

---@class RouteConfiguration
---@field body_limit? number
local RouteConfiguration = {}

---@class Route
---@field path string
---@field method string
---@field func function
---@field static_dir string?
---@field static_file string?
---@field config RouteConfiguration?
local Route = {}

---Represents an HTTP body.
---@class Body
local Body = {}

---Returns the body as text
---@return string
function Body:text() end

---Returns the body parsed as JSON -> Lua Table
---@return table
function Body:json() end

---Represents a multipart.
---@class Multipart
local Multipart = {}

---Saves the multipart into disk
---@param file_path string|nil
---@return string|nil
function Multipart:save_file(file_path) end

---Represents an HTTP request.
---@class Request
local Request = {}

---Returns the HTTP method (e.g., "GET", "POST").
---@return string
function Request:method() end

---Returns the URI of the request.
---@return string
function Request:uri() end

---Returns the query list.
---@return table
function Request:queries() end

---Returns a table containing the headers of the request.
---@return table
function Request:headers() end

---Returns the body of the request, which can be a table or a string.
---@return Body|nil
function Request:body() end

---Returns a multipart if available.
---@return Multipart|nil
function Request:multipart() end

---Returns a cookie
---@param name string
---@return Cookie
function Request:get_cookie(name) end

---Returns a cookie
---@param name string
---@param value string
---@return Cookie
function Request:new_cookie(name, value) end

---Represents an HTTP response.
---@class Response
local Response = {}

---Sets the HTTP status code of the response
---@param new_status_code number
function Response:set_status_code(new_status_code) end

---Sets a header
---@param key string
---@param value string
function Response:set_header(key, value) end

---Returns the entire headers list that so far has been set for the response
---@return table|nil
function Response:get_headers() end

---Removes a header from the headers list
---@param key string
function Response:remove_header(key) end

---Sets a cookie
---@param cookie Cookie
function Response:set_cookie(cookie) end

---Removes a cookie from the list
---@param cookie Cookie
function Response:remove_cookie(cookie) end

---Represents an HTTP client request.
---@class HTTPClientRequest
local HTTPClientRequest = {}

---Sets the HTTP method
---@param method string
---@return HTTPClientRequest
function HTTPClientRequest:set_method(method) end

---Sets a header
---@param key string
---@param value string
---@return HTTPClientRequest
function HTTPClientRequest:set_header(key, value) end

---Sets all of the headers
---@param headers table
---@return HTTPClientRequest
function HTTPClientRequest:set_headers(headers) end

---Sets a form
---@param key string
---@param value string
---@return HTTPClientRequest
function HTTPClientRequest:set_form(key, value) end

---Sets all of the forms
---@param headers table
---@return HTTPClientRequest
function HTTPClientRequest:set_forms(headers) end

---Sets the HTTP body
---@param body string
---@return HTTPClientRequest
function HTTPClientRequest:set_body(body) end

---Sets the HTTP json
---@param json table
---@return HTTPClientRequest
function HTTPClientRequest:set_json(json) end

---Sets the for-upload file path
---@param file_path string
---@return HTTPClientRequest
function HTTPClientRequest:set_file(file_path) end

---Executes the request and returns the response
---@return HTTPClientResponse
function HTTPClientRequest:execute() end

---Executes the request as an async task
---@param callback http_client_callback
function HTTPClientRequest:execute_task(callback) end

---@alias http_client_callback fun(response: HTTPClientResponse)

---Represents an HTTP client response.
---@class HTTPClientResponse
local HTTPClientResponse = {}

---Gets the response HTTP Status code
---@return table
function HTTPClientResponse:status_code() end

---Gets the response HTTP Body which further can be parsed
---@return Body
function HTTPClientResponse:body() end

---Returns the entire headers list from the HTTP response
---@return table|nil
function HTTPClientResponse:headers() end

---Gets the remote address of the HTTP response server
---@return string|nil
function HTTPClientResponse:remote_address() end

---@class Cookie
local Cookie = {}

---@param name string
function Cookie:set_name(name) end

---@param value string
function Cookie:set_value(value) end

---@param domain string
function Cookie:set_domain(domain) end

---@param path string
function Cookie:set_path(path) end

---@param expiration number
function Cookie:set_expiration(expiration) end

---@param http_only boolean
function Cookie:set_http_only(http_only) end

---@param max_age number
function Cookie:set_max_age(max_age) end

function Cookie:set_permanent() end

---@return string?
function Cookie:get_name() end

---@return string?
function Cookie:get_value() end

---@return string?
function Cookie:get_domain() end

---@return string?
function Cookie:get_path() end

---@return number?
function Cookie:get_expiration() end

---@return boolean?
function Cookie:get_http_only() end

---@return number?
function Cookie:get_max_age() end
