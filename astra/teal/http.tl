global interface Buffer is userdata
    bytes: function(self: Buffer): {number}
    text: function(self: Buffer): string
    json: function(self: Buffer): table
end

global interface HTTPClientResponse is userdata
    status_code: function(self: HTTPClientResponse): number
    body: function(self: HTTPClientResponse): Buffer
    headers: function(self: HTTPClientResponse): table | nil
    remote_address: function(self: HTTPClientResponse): string | nil
end

local type http_client_callback = function(response: HTTPClientResponse)

global interface HTTPClientRequestTableType
    url: string
    method: string | nil
    body: any
    file: string | nil
    headers: { string: string } | nil
    form: table | nil
end

global interface HTTPClientRequest is userdata
    set_method: function(self: HTTPClientRequest, method: string): HTTPClientRequest
    set_header: function(self: HTTPClientRequest, key: string, value: string): HTTPClientRequest
    set_headers: function(self: HTTPClientRequest, headers: table): HTTPClientRequest
    set_form: function(self: HTTPClientRequest, key: string, value: string): HTTPClientRequest
    set_forms: function(self: HTTPClientRequest, forms: table): HTTPClientRequest
    set_body: function(self: HTTPClientRequest, body: string): HTTPClientRequest
    set_json: function(self: HTTPClientRequest, json: table): HTTPClientRequest
    set_file: function(self: HTTPClientRequest, file_path: string): HTTPClientRequest
    execute: function(self: HTTPClientRequest): HTTPClientResponse
    execute_task: function(self: HTTPClientRequest, callback: http_client_callback)
    execute_streaming: function(self: HTTPClientRequest, callback: http_client_callback)
    execute_websocket: function(self: HTTPClientRequest, callback: HTTPServerWSCallback)
end

global type HTTPServerCallback = function(request?: HTTPServerRequest, response?: HTTPServerResponse): any
global type HTTPServerWSCallback = function(socket: WebSocket): any

global interface HTTPRouteConfiguration
    body_limit: number | nil
    compression: boolean | nil
end

global interface HTTPRoute
    path: string
    method: string
    func: function(request: HTTPServerRequest, response: HTTPServerResponse)
    static_dir: string | nil
    static_file: string | nil
    config: HTTPRouteConfiguration | nil
end

global interface IPAddress
    address: string
    is_ipv4: boolean
    is_ipv6: boolean
    is_loopback: boolean
    is_multicast: boolean
end

global interface HTTPMultipartField is userdata
    name: function(self: HTTPMultipartField): string
    file_name: function(self: HTTPMultipartField): string | nil
    content_type: function(self: HTTPMultipartField): string | nil
    headers: function(self: HTTPMultipartField): {string: string}
    text: function(self: HTTPMultipartField): string
    bytes: function(self: HTTPMultipartField): {number}
end

global interface HTTPMultipart is userdata
    fields: function(self: HTTPMultipart): {HTTPMultipartField}
    get_field: function(self: HTTPMultipart, name: string): HTTPMultipartField
    file_name: function(self: HTTPMultipart): string | nil
    save_file: function(self: HTTPMultipart, file_path?: string)
end

global interface HTTPServerRequest is userdata
    method: function(self: HTTPServerRequest): string
    uri: function(self: HTTPServerRequest): string
    queries: function(self: HTTPServerRequest): table
    params: function(self: HTTPServerRequest): table
    headers: function(self: HTTPServerRequest): table
    form: function(self: HTTPServerRequest): table
    body: function(self: HTTPServerRequest): Buffer
    ip_address: function(self: HTTPServerRequest): IPAddress
    multipart: function(self: HTTPServerRequest): HTTPMultipart
    get_cookie: function(self: HTTPServerRequest, name: string): Cookie
    new_cookie: function(self: HTTPServerRequest, name: string, value: string): Cookie
end

global interface HTTPServerResponse is userdata
    set_status_code: function(self: HTTPServerResponse, new_status_code: number)
    set_header: function(self: HTTPServerResponse, key: string, value: string)
    get_headers: function(self: HTTPServerResponse): table | nil
    remove_header: function(self: HTTPServerResponse, key: string)
    set_cookie: function(self: HTTPServerResponse, cookie: Cookie)
    remove_cookie: function(self: HTTPServerResponse, cookie: Cookie)
    redirect_to: function(self: HTTPServerResponse, redirect_uri: string)
end

global interface Cookie is userdata
    set_name: function(self: Cookie, name: string)
    set_value: function(self: Cookie, value: string)
    set_domain: function(self: Cookie, domain: string)
    set_path: function(self: Cookie, path: string)
    set_expiration: function(self: Cookie, expiration: number)
    set_http_only: function(self: Cookie, http_only: boolean)
    set_max_age: function(self: Cookie, max_age: number)
    set_permanent: function(self: Cookie)
    get_name: function(self: Cookie): string | nil
    get_value: function(self: Cookie): string | nil
    get_domain: function(self: Cookie): string | nil
    get_path: function(self: Cookie): string | nil
    get_expiration: function(self: Cookie): number | nil
    get_http_only: function(self: Cookie): boolean | nil
    get_max_age: function(self: Cookie): number | nil
end

global interface CloseFrame
    code: number
    reason: string
end

local enum WebSocketMessageType "text" "bytes" "ping" "pong" "close" end

global interface WebSocketMessage
    type: WebSocketMessageType
    value: string
end

global interface WebSocket is userdata
    recv: function(self: WebSocket): WebSocketMessage
    send: function(self: WebSocket, message_type: WebSocketMessageType, message: any)
    send_text: function(self: WebSocket, message: string)
    send_bytes: function(self: WebSocket, bytes: table)
    send_ping: function(self: WebSocket, bytes: string)
    send_pong: function(self: WebSocket, bytes: string)
    send_close: function(self: WebSocket, close_frame: CloseFrame | nil)
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

global record HTTPServer
    version: string
    hostname: string
    compression: boolean
    port: number
    routes: {HTTPRoute}

    new: function(self: HTTPServer): HTTPServer
    shutdown: function(self: HTTPServer)
end

local server = {}

function server.new(): HTTPServer
    local http_server: HTTPServer = {
        version = "0.0.0",
        hostname = "127.0.0.1",
        compression = false,
        port = 8080,
        routes = {},
    }
    setmetatable(http_server, { __index = HTTPServer })
    return http_server
end

local function add_to_routes(
    self: HTTPServer,
    method: string,
    path: string,
    callback: HTTPServerCallback,
    wscallback?: HTTPServerWSCallback,
    config?: HTTPRouteConfiguration
)
    local index: integer = (path == "/") and 1 or #self.routes + 1
    local callback_function: function
    if wscallback then
        callback_function = wscallback
    else
        callback_function = callback
    end
    table.insert(self.routes, index, {
        path = path,
        method = method,
        func = callback_function,
        config = config or { body_limit = nil },
    })
end

function HTTPServer:get(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "get", path, callback, nil, config)
end

function HTTPServer:post(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "post", path, callback, nil, config)
end

function HTTPServer:put(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "put", path, callback, nil, config)
end

function HTTPServer:delete(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "delete", path, callback, nil, config)
end

function HTTPServer:options(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "options", path, callback, nil, config)
end

function HTTPServer:patch(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "patch", path, callback, nil, config)
end

function HTTPServer:trace(path: string, callback: HTTPServerCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "trace", path, callback, nil, config)
end

function HTTPServer:static_dir(path: string, serve_path: string, config?: HTTPRouteConfiguration)
    table.insert(self.routes, {
        path = path,
        method = "static_dir",
        static_dir = serve_path,
        func = function():nil end,
        config = config or {},
    })
end

function HTTPServer:static_file(path: string, serve_path: string, config?: HTTPRouteConfiguration)
    table.insert(self.routes, {
        path = path,
        method = "static_file",
        func = function():nil end,
        static_file = serve_path,
        config = config or {},
    })
end

function HTTPServer:websocket(path: string, wscallback: HTTPServerWSCallback, config?: HTTPRouteConfiguration)
    add_to_routes(self, "web_socket", path, function():nil end, wscallback, config)
end

function HTTPServer:fallback(callback: HTTPServerCallback)
    add_to_routes(self, "fallback", "/", callback, nil, {})
end

local type astra_internal__start_server = function(HTTPServer)
---Runs the server
function HTTPServer:run()
    astra_internal__start_server(self)
end

local middleware = {}

local type middleware_HTTPServerCallback = function(...: any): function
function middleware.chain(chain: {function}): function
    return function(handler: function): function
        assert(type(handler) == "function",
            "Handler must be a function, got " .. type(handler))
        for i = #chain, 1, -1 do
            local http_middleware: middleware_HTTPServerCallback = chain[i]
            assert(type(http_middleware) == "function",
                "Middleware must be a function, got " .. type(http_middleware))
            handler = http_middleware(handler)
        end
        return handler
    end
end

local type astra_internal__http_request = function(details: string | HTTPClientRequestTableType): HTTPClientRequest
---Opens a new async HTTP Request. The request is running as a task in parallel
local function http_request(details: string | HTTPClientRequestTableType): HTTPClientRequest
    return astra_internal__http_request(details)
end

local status_codes = {
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

return {
    status_codes = status_codes,
    middleware = middleware,
    request = http_request,
    server = server,
}
