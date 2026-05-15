--!nocheck
--!nolint

type HTTPClientCallback = (response: HTTPClientResponse) -> ()
type HTTPServerCallback = (request: HTTPServerRequest, response: HTTPServerResponse) -> any
type WSCallback = (socket: WebSocket) -> any

type Buffer = {
  bytes: (self: Buffer) -> { number },
  text: (self: Buffer) -> string,
  json: (self: Buffer) -> { any },
}

type HTTPClientResponse = {
  --- Gets the response HTTP Status code
  status_code: (self: HTTPClientResponse) -> number,
  --- Gets the response HTTP Body which further can be parsed
  body: (self: HTTPClientResponse) -> Buffer,
  --- Returns the entire headers list from the HTTP response
  headers: (self: HTTPClientResponse) -> { any }?,
  --- Gets the remote address of the HTTP response server
  remote_address: (self: HTTPClientResponse) -> string?,
}

type HTTPClientRequestTableType = {
  url: string,
  method: string?,
  body: any?,
  file: string?,
  headers: { any }?,
  form: { any }?,
}

type HTTPClientRequest = {
  set_method: (self: HTTPClientRequest, method: string) -> HTTPClientRequest,
  set_header: (self: HTTPClientRequest, key: string, value: string) -> HTTPClientRequest,
  set_headers: (self: HTTPClientRequest, headers: { any }) -> HTTPClientRequest,
  set_form: (self: HTTPClientRequest, headers: { any }) -> HTTPClientRequest,
  set_body: (self: HTTPClientRequest, body: any) -> HTTPClientRequest,
  --- Sets the for-upload file path
  set_file: (self: HTTPClientRequest, file_path: string) -> HTTPClientRequest,
  --- Executes the request and returns the response
  execute: (self: HTTPClientRequest) -> HTTPClientResponse,
  --- Executes the request in a streaming manner
  execute_streaming: (self: HTTPClientRequest, callback: (response: HTTPClientResponse) -> ()) -> (),
  --- Executes the request as an async task
  execute_websocket: (self: HTTPClientRequest, callback: (socket: WebSocket) -> any) -> (),
}

type HTTPRouteConfiguration = {
  body_limit: number?,
  compression: boolean?,
  headers: { string: string }?,
}

type HTTPRoute = {
  path: string,
  method: string,
  func: (any, any) -> any,
  static_dir: string?,
  static_file: string?,
  config: HTTPRouteConfiguration?,
}

type IPAddress = {
  address: string,
  --- Converts this address to an IpAddress_V4 if it is an IPv4-mapped IPv6 address, otherwise returns self as-is.
  to_canonical: IPAddress,
  is_ipv4: boolean,
  is_ipv6: boolean,
  is_loopback: boolean,
  is_multicast: boolean,
}

type HTTPMultipartField = {
  name: (self: HTTPMultipartField) -> string,
  file_name: (self: HTTPMultipartField) -> string?,
  content_type: (self: HTTPMultipartField) -> string?,
  headers: (self: HTTPMultipartField) -> { any },
  text: (self: HTTPMultipartField) -> string,
  --- Returns the field data as bytes (table of numbers)
  bytes: (self: HTTPMultipartField) -> { any },
}

type HTTPMultipart = {
  --- Returns all multipart fields as an array
  fields: (self: HTTPMultipart) -> { any },
  --- Returns a specific field by name
  get_field: (self: HTTPMultipart, name: string) -> HTTPMultipartField,
  --- Returns the first filename found in the multipart data
  file_name: (self: HTTPMultipart) -> string?,
  --- Saves the multipart into disk
  save_file: (self: HTTPMultipart, file_path: string?) -> string?,
}

type HTTPServerRequest = {
  --- Returns the HTTP method (e.g., "GET", "POST").
  method: (self: HTTPServerRequest) -> string,
  uri: (self: HTTPServerRequest) -> string,
  queries: (self: HTTPServerRequest) -> { any },
  params: (self: HTTPServerRequest) -> { any },
  headers: (self: HTTPServerRequest) -> { any },
  form: (self: HTTPServerRequest) -> { any },
  --- Returns the body of the request, which can be a table or a string.
  body: (self: HTTPServerRequest) -> Buffer,
  ip_address: (self: HTTPServerRequest) -> IPAddress,
  multipart: (self: HTTPServerRequest) -> HTTPMultipart,
  get_cookie: (self: HTTPServerRequest, name: string) -> Cookie,
  new_cookie: (self: HTTPServerRequest, name: string, value: string) -> Cookie,
}

type HTTPServerResponse = {
  --- Sets the HTTP status code of the response
  set_status_code: (self: HTTPServerResponse, new_status_code: number) -> (),
  set_header: (self: HTTPServerResponse, key: string, value: string) -> (),
  --- Returns the entire headers list that so far has been set for the response
  get_headers: (self: HTTPServerResponse) -> { any }?,
  remove_header: (self: HTTPServerResponse, key: string) -> (),
  set_cookie: (self: HTTPServerResponse, cookie: Cookie) -> (),
  remove_cookie: (self: HTTPServerResponse, cookie: Cookie) -> (),
  redirect_to: (self: HTTPServerResponse, redirect_uri: string) -> (),
  redirect_temporary: (self: HTTPServerResponse, redirect_uri: string) -> (),
  redirect_permanent: (self: HTTPServerResponse, redirect_uri: string) -> (),
}

type Cookie = {
  set_name: (self: Cookie, name: string) -> (),
  set_value: (self: Cookie, value: string) -> (),
  set_domain: (self: Cookie, domain: string) -> (),
  set_path: (self: Cookie, path: string) -> (),
  set_expiration: (self: Cookie, expiration: number) -> (),
  set_http_only: (self: Cookie, http_only: boolean) -> (),
  set_max_age: (self: Cookie, max_age: number) -> (),
  set_permanent: (self: Cookie) -> (),
  get_name: (self: Cookie) -> string?,
  get_value: (self: Cookie) -> string?,
  get_domain: (self: Cookie) -> string?,
  get_path: (self: Cookie) -> string?,
  get_expiration: (self: Cookie) -> number?,
  get_http_only: (self: Cookie) -> boolean?,
  get_max_age: (self: Cookie) -> number?,
}

type CloseFrame = {
  code: number,
  reason: string,
}

type WebSocketMessageType = "text" | "bytes" | "close"

type WebSocketMessage = {
  type: WebSocketMessageType,
  value: string,
}

type WebSocket = {
  --- Receive another message. Returns `nil` if the stream has closed.
  recv: (socket: WebSocket) -> WebSocketMessage?,
  --- A flexible WebSocket message
  send: (socket: WebSocket, message_type: WebSocketMessageType, message: any) -> (),
  --- A text WebSocket message
  send_text: (socket: WebSocket, message: string) -> (),
  --- A binary WebSocket message
  send_bytes: (socket: WebSocket, bytes: { any }) -> (),
  send_close: (socket: WebSocket, close_frame: CloseFrame?) -> (),
}

export type HTTPServer = {
  version: string,
  hostname: string,
  compression: boolean,
  port: number,
  routes: { HTTPRoute },
  new: (self: HTTPServer) -> HTTPServer,
  get: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  post: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  put: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  delete: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  options: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  patch: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  trace: (
    self: HTTPServer,
    path: string,
    callback: HTTPServerCallback,
    config: HTTPRouteConfiguration?
  ) -> (),
  static_dir: (self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?) -> (),
  static_file: (self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?) -> (),
  websocket: (
    self: HTTPServer,
    path: string,
    wscallback: (socket: WebSocket) -> any,
    config: HTTPRouteConfiguration?
  ) -> (),
  fallback: (self: HTTPServer, callback: HTTPServerCallback) -> (),
  run: (self: HTTPServer) -> (),
  shutdown: (self: HTTPServer) -> (),
}

local http = {}
http.server = {}
http.status_codes = {
  CONTINUE = 100,
  SWITCHING_PROTOCOLS = 101,
  PROCESSING = 102,
  EARLY_HINTS = 103,
  UPLOAD_RESUMPTION_SUPPORTED = 104,
  OK = 200,
  CREATED = 201,
  ACCEPTED = 202,
  NON_AUTHORITATIVE_INFORMATION = 203,
  NO_CONTENT = 204,
  RESET_CONTENT = 205,
  PARTIAL_CONTENT = 206,
  MULTI_STATUS = 207,
  ALREADY_REPORTED = 208,
  IM_USED = 226,
  MULTIPLE_CHOICES = 300,
  MOVED_PERMANENTLY = 301,
  FOUND = 302,
  SEE_OTHER = 303,
  NOT_MODIFIED = 304,
  USE_PROXY = 305,
  SWITCH_PROXY_UNUSED = 306,
  TEMPORARY_REDIRECT = 307,
  PERMANENT_REDIRECT = 308,
  BAD_REQUEST = 400,
  UNAUTHORIZED = 401,
  PAYMENT_REQUIRED = 402,
  FORBIDDEN = 403,
  NOT_FOUND = 404,
  METHOD_NOT_ALLOWED = 405,
  NOT_ACCEPTABLE = 406,
  PROXY_AUTHENTICATION_REQUIRED = 407,
  REQUEST_TIMEOUT = 408,
  CONFLICT = 409,
  GONE = 410,
  LENGTH_REQUIRED = 411,
  PRECONDITION_FAILED = 412,
  PAYLOAD_TOO_LARGE = 413,
  URI_TOO_LONG = 414,
  UNSUPPORTED_MEDIA_TYPE = 415,
  RANGE_NOT_SATISFIABLE = 416,
  EXPECTATION_FAILED = 417,
  IM_A_TEAPOT = 418,
  MISDIRECTED_REQUEST = 421,
  UNPROCESSABLE_ENTITY = 422,
  LOCKED = 423,
  FAILED_DEPENDENCY = 424,
  TOO_EARLY = 425,
  UPGRADE_REQUIRED = 426,
  PRECONDITION_REQUIRED = 428,
  TOO_MANY_REQUESTS = 429,
  REQUEST_HEADER_FIELDS_TOO_LARGE = 431,
  UNAVAILABLE_FOR_LEGAL_REASONS = 451,
  INTERNAL_SERVER_ERROR = 500,
  NOT_IMPLEMENTED = 501,
  BAD_GATEWAY = 502,
  SERVICE_UNAVAILABLE = 503,
  GATEWAY_TIMEOUT = 504,
  HTTP_VERSION_NOT_SUPPORTED = 505,
  VARIANT_ALSO_NEGOTIATES = 506,
  INSUFFICIENT_STORAGE = 507,
  LOOP_DETECTED = 508,
  NOT_EXTENDED = 510,
  NETWORK_AUTHENTICATION_REQUIRED = 511,
}

local HTTPServer = {
  version = "0.0.0",
  hostname = "127.0.0.1",
  compression = false,
  port = 8080,
  routes = {},
}

function HTTPServer:new(): HTTPServer
  local server = {
    version = "0.0.0",
    hostname = "127.0.0.1",
    compression = false,
    port = 8080,
    routes = {},
  }

  setmetatable(server, self)
  self.__index = self
  return server
end

function http.request(details: string | HTTPClientRequestTableType): HTTPClientRequest
  return astra_internal__http_request(details)
end

function http.server.new(): HTTPServer
  return HTTPServer:new()
end

local function add_to_routes(
  server: HTTPServer,
  method: string,
  path: string,
  callback: (any, any) -> any,
  config: HTTPRouteConfiguration?
)
  local index = if path == "/" then 1 else #server.routes + 1
  table.insert(server.routes, index, {
    path = path,
    method = method,
    func = callback,
    config = config or {},
  })
end

function HTTPServer:get(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "get", path, callback, config)
end

function HTTPServer:post(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "post", path, callback, config)
end

function HTTPServer:put(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "put", path, callback, config)
end

function HTTPServer:delete(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "delete", path, callback, config)
end

function HTTPServer:options(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "options", path, callback, config)
end

function HTTPServer:patch(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "patch", path, callback, config)
end

function HTTPServer:trace(path: string, callback: HTTPServerCallback, config: HTTPRouteConfiguration?)
  add_to_routes(self, "trace", path, callback, config)
end

function HTTPServer:static_dir(path: string, serve_path: string, config: HTTPRouteConfiguration?)
  table.insert(self.routes, {
    path = path,
    method = "static_dir",
    func = function() end,
    static_dir = serve_path,
    config = config or {},
  })
end

function HTTPServer:static_file(path: string, serve_path: string, config: HTTPRouteConfiguration?)
  table.insert(self.routes, {
    path = path,
    method = "static_file",
    func = function() end,
    static_file = serve_path,
    config = config or {},
  })
end

function HTTPServer:websocket(path: string, wscallback: (socket: WebSocket) -> any, config: HTTPRouteConfiguration?)
  add_to_routes(self, "web_socket", path, wscallback, config)
end

function HTTPServer:fallback(callback: HTTPServerCallback)
  add_to_routes(self, "fallback", "", callback, {})
end

function HTTPServer:run()
  astra_internal__start_server(self)
end

http.middleware = {
  --- Chains middlewares together in order
  chain = function(chain: { (any) -> any }): (any) -> any
    return function(handler: any)
      assert(type(handler) == "function", "Handler must be a function, got " .. type(handler))
      assert(#chain >= 2, "Chain must have at least 2 middlewares")
      for i = #chain, 1, -1 do
        local middleware = chain[i]
        assert(type(middleware) == "function", "Middleware must be a function, got " .. type(middleware))
        handler = middleware(handler)
      end
      return handler
    end
  end,
}

return http
