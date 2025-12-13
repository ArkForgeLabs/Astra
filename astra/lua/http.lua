---@meta

---@class Buffer
---@field bytes fun(): number[]
---@field text fun(): string
---@field json fun(): table Returns the body parsed as JSON -> Lua Table

local http = {}

--- Represents an HTTP client response.
---@class HTTPClientResponse
---@field status_code fun(): number Gets the response HTTP Status code
---@field body fun(): Buffer Gets the response HTTP Body which further can be parsed
---@field headers fun(): table|nil Returns the entire headers list from the HTTP response
---@field remote_address fun(): string|nil Gets the remote address of the HTTP response server

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias http_client_callback fun(response: HTTPClientResponse)

---@class HTTPClientRequestTableType
---@field url string
---@field method string?
---@field body any?
---@field file string?
---@field headers table?
---@field form table?

--- Represents an HTTP client request.
---@class HTTPClientRequest
---@field set_method fun(self: HTTPClientRequest, method: string): HTTPClientRequest
---@field set_header fun(self: HTTPClientRequest, key: string, value: string): HTTPClientRequest
---@field set_headers fun(self: HTTPClientRequest, headers: table): HTTPClientRequest
---@field set_form fun(self: HTTPClientRequest, key: string, value: string): HTTPClientRequest
---@field set_forms fun(self: HTTPClientRequest, headers: table): HTTPClientRequest
---@field set_body fun(self: HTTPClientRequest, body: string): HTTPClientRequest
---@field set_bytes fun(self: HTTPClientRequest, body: integer[]): HTTPClientRequest
---@field set_json fun(self: HTTPClientRequest, json: table): HTTPClientRequest
---@field set_file fun(self: HTTPClientRequest, file_path: string): HTTPClientRequest Sets the for-upload file path
---@field execute fun(self: HTTPClientRequest): HTTPClientResponse Executes the request and returns the response
---@field execute_task fun(self: HTTPClientRequest, callback: http_client_callback) Executes the request as an async task
---@field execute_streaming fun(self: HTTPClientRequest, callback: http_client_callback) Executes the request in a streaming manner
---@field execute_websocket fun(self: HTTPClientRequest, callback: wscallback) Executes the request as an async task

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias callback fun(request: HTTPServerRequest, response: HTTPServerResponse): any

---@class HTTPRouteConfiguration
---@field body_limit? number
---@field compression? boolean

---@class HTTPRoute
---@field path string
---@field method string
---@field func function
---@field static_dir string?
---@field static_file string?
---@field config HTTPRouteConfiguration?

---@class IPAddress
---@field address string
---Converts this address to an `IpAddress_V4` if it is an IPv4-mapped IPv6 address, otherwise returns self as-is.
---@field to_canonical IPAddress
---@field is_ipv4 boolean
---@field is_ipv6 boolean
---@field is_loopback boolean
---@field is_multicast boolean

---@class HTTPMultipartField
---@field name fun(): string
---@field file_name fun(): string|nil
---@field content_type fun(): string|nil
---@field headers fun(): table
---@field text fun(): string
---@field bytes fun(): table Returns the field data as bytes (table of numbers)

---@class HTTPMultipart
---@field fields fun(): table Returns all multipart fields as an array
---@field get_field fun(name: string): HTTPMultipartField Returns a specific field by name
---@field file_name fun(): string|nil Returns the first filename found in the multipart data
---@field save_file fun(multipart: HTTPMultipart, file_path: string | nil): string | nil Saves the multipart into disk

---@class HTTPServerRequest
---@field method fun(self: HTTPServerRequest): string Returns the HTTP method (e.g., "GET", "POST").
---@field uri fun(self: HTTPServerRequest): string
---@field queries fun(self: HTTPServerRequest): table
---@field params fun(self: HTTPServerRequest): table
---@field headers fun(self: HTTPServerRequest): table
---@field body fun(self: HTTPServerRequest): Buffer Returns the body of the request, which can be a table or a string.
---@field ip_address fun(self: HTTPServerRequest): IPAddress
---@field multipart fun(self: HTTPServerRequest): HTTPMultipart
---@field get_cookie fun(self: HTTPServerRequest, name: string): Cookie
---@field new_cookie fun(self: HTTPServerRequest, name: string, value: string): Cookie

---@class HTTPServerResponse
---Sets the HTTP status code of the response
---@field set_status_code fun(self: HTTPServerResponse, new_status_code: number)
---@field set_header fun(self: HTTPServerResponse, key: string, value: string)
---Returns the entire headers list that so far has been set for the response
---@field get_headers fun(self: HTTPServerResponse): table|nil
---@field remove_header fun(self: HTTPServerResponse, key: string)
---@field set_cookie fun(self: HTTPServerResponse, cookie: Cookie)
---@field remove_cookie fun(self: HTTPServerResponse, cookie: Cookie)
---@field redirect_to fun(self: HTTPServerResponse, redirect_uri: string)

---@class Cookie
---@field set_name fun(self: Cookie, name: string)
---@field set_value fun(self: Cookie, value: string)
---@field set_domain fun(self: Cookie, domain: string)
---@field set_path fun(self: Cookie, path: string)
---@field set_expiration fun(self: Cookie, expiration: number)
---@field set_http_only fun(self: Cookie, http_only: boolean)
---@field set_max_age fun(self: Cookie, max_age: number)
---@field set_permanent fun(self: Cookie)
---@field get_name fun(self: Cookie): string?
---@field get_value fun(self: Cookie): string?
---@field get_domain fun(self: Cookie): string?
---@field get_path fun(self: Cookie): string?
---@field get_expiration fun(self: Cookie): number?
---@field get_http_only fun(self: Cookie): boolean?
---@field get_max_age fun(self: Cookie): number?

---@class CloseFrame
---@field code integer
---@field reason string

---@alias WebSocketMessageType "text" | "bytes" | "ping" | "pong" | "close"

---@class WebSocketMessage
---@field type WebSocketMessageType
---@field data string

---@class WebSocket
---Receive another message. Returns `nil` if the stream has closed.
---@field recv fun(socket: WebSocket): WebSocketMessage|nil
---A flexible WebSocket message
---@field send fun(socket: WebSocket, message_type: WebSocketMessageType, message: any)
---A text WebSocket message
---@field send_text fun(socket: WebSocket, message: string)
---A binary WebSocket message
---@field send_bytes fun(socket: WebSocket, bytes: table)
---A ping message with the specified payload. The payload here must have a length less than 125 bytes.
---Ping messages will be automatically responded to by the server so you do not have to worry about dealing with them yourself.
---@field send_ping fun(socket: WebSocket, bytes: string)
---A pong message with the specified payload. The payload here must have a length less than 125 bytes.
---Pong messages will be automatically sent to the client if a ping message is received,
---so you do not have to worry about constructing them yourself unless you want to implement a unidirectional heartbeat.
---@field send_pong fun(socket: WebSocket, bytes: string)
---@field send_close fun(socket: WebSocket, close_frame: CloseFrame?)

---@alias wscallback fun(socket: WebSocket): any

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------


---@class HTTPServer
---@field shutdown fun(HTTPServer) Shuts down the server
---@diagnostic disable-next-line: missing-fields
local HTTPServer = {
    version = "0.0.0",
    hostname = "127.0.0.1",
    --- Enable or disable compression
    compression = false,
    port = 8080,
    --- Contains all of the route details
    routes = {},
}
function HTTPServer:new()
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
    return server
end

http.server = {}
---@return HTTPServer
function http.server.new()
    return HTTPServer:new()
end

local function add_to_routes(server, method, path, callback, config)
    local index = (path == "/") and 1 or #server.routes + 1
    table.insert(server.routes, index, {
        path = path,
        method = method,
        func = callback,
        config = config or {},
    })
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:get(path, callback, config)
    add_to_routes(self, "get", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:post(path, callback, config)
    add_to_routes(self, "post", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:put(path, callback, config)
    add_to_routes(self, "put", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:delete(path, callback, config)
    add_to_routes(self, "delete", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:options(path, callback, config)
    add_to_routes(self, "options", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:patch(path, callback, config)
    add_to_routes(self, "patch", path, callback, config)
end

---@param path string
---@param callback callback
---@param config HTTPRouteConfiguration?
function HTTPServer:trace(path, callback, config)
    add_to_routes(self, "trace", path, callback, config)
end

---@param path string
---@param serve_path string
---@param config HTTPRouteConfiguration?
function HTTPServer:static_dir(path, serve_path, config)
    table.insert(self.routes, {
        path = path,
        method = "static_dir",
        func = function() end,
        static_dir = serve_path,
        config = config or {},
    })
end

---@param path string
---@param serve_path string
---@param config HTTPRouteConfiguration?
function HTTPServer:static_file(path, serve_path, config)
    table.insert(self.routes, {
        path = path,
        method = "static_file",
        func = function() end,
        static_file = serve_path,
        config = config or {},
    })
end

---@param path string
---@param wscallback wscallback
---@param config HTTPRouteConfiguration?
function HTTPServer:websocket(path, wscallback, config)
    add_to_routes(self, "web_socket", path, wscallback, config)
end

---@param callback callback
function HTTPServer:fallback(callback)
    add_to_routes(self, "fallback", "", callback, {})
end

---Runs the server
function HTTPServer:run()
    ---@diagnostic disable-next-line: undefined-global
    astra_internal__start_server(self)
end

http.middleware = {}

--- `on Entry:`
--- Include *on Entry* description if the middleware does something before calling *next_handler*
---
--- `on Leave:`
--- Include *on Leave* description if the middleware does something after calling *next_handler*
---
--- `Depends on:`
--- Include *Depends on* description if the middleware depends on other middlewares
---
---@param next_handler function
local function middleware_template(next_handler)
    --- Next_handler is a function which represents a middleware or a handler

    --- Each middleware must return a function which accepts 3 arguments,
    --- and passes them to the next_handler
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    ---@param ctx { key_inserted_by_middleware_I_depend_on: string }
    return function(request, response, ctx)
        -- Pre-handler logic
        if "something wrong" then
            return "Waaait a minute."
        end
        local result = next_handler(request, response, ctx)
        -- Post-handler logic
        if "you came up with a use case" then
            local things = "Do some on-Leave logic"
        end
        return result
    end
end

---------------
-- Utilities --
---------------

--- Chains middlewares together in order
---@param chain table A list of middlewares
---@return function middleware Composed middleware
---
--- Functionally
--- ```lua
--- chain {context, html, logger} (handler)
--- ```
--- equals to
--- ```lua
--- context(html(logger(handler)))
--- ```
---
--- and
--- ```lua
--- chain {context, html, logger}
--- ```
--- equals to
--- ```lua
--- (function(handler)
---     handler = context(html(logger(handler)))
---     return handler
--- end)
--- ```
function http.middleware.chain(chain)
    return function(handler)
        assert(type(handler) == "function",
            "Handler must be a function, got " .. type(handler))
        for i = #chain, 1, -1 do
            local middleware = chain[i]
            assert(type(middleware) == "function",
                "Middleware must be a function, got " .. type(middleware))
            handler = middleware(handler)
        end
        return handler
    end
end

---Opens a new async HTTP Request. The request is running as a task in parallel
---@param details string | HTTPClientRequestTableType
---@return HTTPClientRequest
---@nodiscard
---@diagnostic disable-next-line: missing-return, lowercase-global
function http.request(details)
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__http_request(details)
end

http.status_codes = {
    --- The server has received the request headers and the client should proceed to send the request body.
    CONTINUE = 100,
    --- The requester has asked the server to switch protocols and the server has agreed to do so.
    SWITCHING_PROTOCOLS = 101,
    --- The server has received and is processing the request, but no response is available yet.
    PROCESSING = 102,
    --- Used to return some response headers before final HTTP message.
    EARLY_HINTS = 103,
    --- The server indicates upload resumption is supported (temporary IANA‑registered code).
    UPLOAD_RESUMPTION_SUPPORTED = 104,

    --- The request has succeeded.
    OK = 200,
    --- The request has been fulfilled and resulted in a new resource being created.
    CREATED = 201,
    --- The request has been accepted for processing, but the processing has not been completed.
    ACCEPTED = 202,
    --- The server successfully processed the request, but is returning information that may be from another source.
    NON_AUTHORITATIVE_INFORMATION = 203,
    --- The server successfully processed the request, but is not returning any content.
    NO_CONTENT = 204,
    --- The server successfully processed the request, but is not returning any content and requires that the requester reset the document view.
    RESET_CONTENT = 205,
    --- The server is delivering only part of the resource due to a range header sent by the client.
    PARTIAL_CONTENT = 206,
    --- The message body that follows is an XML message and can contain a number of separate response codes, depending on how many sub-requests were made.
    MULTI_STATUS = 207,
    --- The members of a DAV binding have already been enumerated in a previous reply to this request, and are not being included again.
    ALREADY_REPORTED = 208,
    --- The server has fulfilled a GET request for the resource, and the response is a representation of the result of one or more instance‑manipulations applied to the current instance.
    IM_USED = 226,

    --- Multiple options for the resource. User agent or user should choose one.
    MULTIPLE_CHOICES = 300,
    --- This and all future requests should be directed to the given URI.
    MOVED_PERMANENTLY = 301,
    --- The URI of the requested resource has been changed temporarily.
    FOUND = 302,
    --- The response to the request can be found under another URI using a GET method.
    SEE_OTHER = 303,
    --- Indicates that the resource has not been modified since the version specified by the request headers.
    NOT_MODIFIED = 304,
    --- The requested resource must be accessed through the proxy given by the Location field.
    USE_PROXY = 305,
    --- Reserved/Unused (was Switch Proxy). Defined by IANA but never implemented.
    SWITCH_PROXY_UNUSED = 306,
    --- The request should be repeated with another URI, but future requests should still use the original URI.
    TEMPORARY_REDIRECT = 307,
    --- The request and all future requests should be repeated using another URI.
    PERMANENT_REDIRECT = 308,

    --- The server cannot or will not process the request due to an apparent client error.
    BAD_REQUEST = 400,
    --- Similar to 403 Forbidden, but specifically for use when authentication is required and has failed or has not yet been provided.
    UNAUTHORIZED = 401,
    --- Reserved for future use.
    PAYMENT_REQUIRED = 402,
    --- The request was valid, but the server is refusing action.
    FORBIDDEN = 403,
    --- The requested resource could not be found but may be available in the future.
    NOT_FOUND = 404,
    --- A request method is not supported for the requested resource.
    METHOD_NOT_ALLOWED = 405,
    --- The requested resource is capable of generating only content not acceptable according to the Accept headers sent in the request.
    NOT_ACCEPTABLE = 406,
    --- The client must first authenticate itself with the proxy.
    PROXY_AUTHENTICATION_REQUIRED = 407,
    --- The server timed out waiting for the request.
    REQUEST_TIMEOUT = 408,
    --- Indicates that the request could not be processed because of conflict in the request.
    CONFLICT = 409,
    --- Indicates that the resource requested is no longer available and will not be available again.
    GONE = 410,
    --- The request did not specify the length of its content, which is required by the requested resource.
    LENGTH_REQUIRED = 411,
    --- The server does not meet one of the preconditions that the requester put on the request.
    PRECONDITION_FAILED = 412,
    --- The request is larger than the server is willing or able to process.
    PAYLOAD_TOO_LARGE = 413,
    --- The URI provided was too long for the server to process.
    URI_TOO_LONG = 414,
    --- The request entity has a media type which the server or resource does not support.
    UNSUPPORTED_MEDIA_TYPE = 415,
    --- The client has asked for a portion of the file, but the server cannot supply that portion.
    RANGE_NOT_SATISFIABLE = 416,
    --- The server cannot meet the requirements of the Expect request‑header field.
    EXPECTATION_FAILED = 417,
    --- This code is defined as unused in the RFC (commonly known as “I’m a teapot”).
    IM_A_TEAPOT = 418,
    --- The request was directed at a server that is not able to produce a response.
    MISDIRECTED_REQUEST = 421,
    --- The request was well‑formed but was unable to be followed due to semantic errors.
    UNPROCESSABLE_ENTITY = 422,
    --- The resource that is being accessed is locked.
    LOCKED = 423,
    --- The request failed due to failure of a previous request.
    FAILED_DEPENDENCY = 424,
    --- Indicates that the server is unwilling to risk processing a request that might be replayed.
    TOO_EARLY = 425,
    --- The client should switch to a different protocol such as TLS/1.0, given in the Upgrade header field.
    UPGRADE_REQUIRED = 426,
    --- The origin server requires the request to be conditional.
    PRECONDITION_REQUIRED = 428,
    --- The user has sent too many requests in a given amount of time.
    TOO_MANY_REQUESTS = 429,
    --- The server is unwilling to process the request because either an individual header field, or all the header fields collectively, are too large.
    REQUEST_HEADER_FIELDS_TOO_LARGE = 431,
    --- The user requests an illegal resource, such as a web page censored by a government.
    UNAVAILABLE_FOR_LEGAL_REASONS = 451,

    --- A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
    INTERNAL_SERVER_ERROR = 500,
    --- The server either does not recognize the request method, or it lacks the ability to fulfill the request.
    NOT_IMPLEMENTED = 501,
    --- The server was acting as a gateway or proxy and received an invalid response from the upstream server.
    BAD_GATEWAY = 502,
    --- The server is currently unavailable (because it is overloaded or down for maintenance).
    SERVICE_UNAVAILABLE = 503,
    --- The server was acting as a gateway or proxy and did not receive a timely response from the upstream server.
    GATEWAY_TIMEOUT = 504,
    --- The server does not support the HTTP protocol version used in the request.
    HTTP_VERSION_NOT_SUPPORTED = 505,
    --- Transparent content negotiation for the request results in a circular reference.
    VARIANT_ALSO_NEGOTIATES = 506,
    --- The server is unable to store the representation needed to complete the request.
    INSUFFICIENT_STORAGE = 507,
    --- The server detected an infinite loop while processing the request.
    LOOP_DETECTED = 508,
    --- Further extensions to the request are required for the server to fulfill it.
    NOT_EXTENDED = 510,
    --- The client needs to authenticate to gain network access.
    NETWORK_AUTHENTICATION_REQUIRED = 511
}

return http
