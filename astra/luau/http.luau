--!strict

type HTTPClientCallback = (response: HTTPClientResponse) -> ()
type Callback = (request: HTTPServerRequest, response: HTTPServerResponse) -> any
type WSCallback = (socket: WebSocket) -> any

type Buffer = {
  bytes: (self: Buffer) -> { number },
  text: (self: Buffer) -> string,
  json: (self: Buffer) -> { any },
}

type HTTPClientResponse = {
  status_code: (self: HTTPClientResponse) -> number,
  body: (self: HTTPClientResponse) -> Buffer,
  headers: (self: HTTPClientResponse) -> { any }?,
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
  set_file: (self: HTTPClientRequest, file_path: string) -> HTTPClientRequest,
  execute: (self: HTTPClientRequest) -> HTTPClientResponse,
  execute_streaming: (self: HTTPClientRequest, callback: HTTPClientCallback) -> (),
  execute_websocket: (self: HTTPClientRequest, callback: WSCallback) -> (),
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
  bytes: (self: HTTPMultipartField) -> { any },
}

type HTTPMultipart = {
  fields: (self: HTTPMultipart) -> { any },
  get_field: (self: HTTPMultipart, name: string) -> HTTPMultipartField,
  file_name: (self: HTTPMultipart) -> string?,
  save_file: (self: HTTPMultipart, file_path: string?) -> string?,
}

type HTTPServerRequest = {
  method: (self: HTTPServerRequest) -> string,
  uri: (self: HTTPServerRequest) -> string,
  queries: (self: HTTPServerRequest) -> { any },
  params: (self: HTTPServerRequest) -> { any },
  headers: (self: HTTPServerRequest) -> { any },
  form: (self: HTTPServerRequest) -> { any },
  body: (self: HTTPServerRequest) -> Buffer,
  ip_address: (self: HTTPServerRequest) -> IPAddress,
  multipart: (self: HTTPServerRequest) -> HTTPMultipart,
  get_cookie: (self: HTTPServerRequest, name: string) -> Cookie,
  new_cookie: (self: HTTPServerRequest, name: string, value: string) -> Cookie,
}

type HTTPServerResponse = {
  set_status_code: (self: HTTPServerResponse, new_status_code: number) -> (),
  set_header: (self: HTTPServerResponse, key: string, value: string) -> (),
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
  recv: (self: WebSocket) -> WebSocketMessage?,
  send: (self: WebSocket, message_type: WebSocketMessageType, message: any) -> (),
  send_text: (self: WebSocket, message: string) -> (),
  send_bytes: (self: WebSocket, bytes: { any }) -> (),
  send_close: (self: WebSocket, close_frame: CloseFrame?) -> (),
}

type HTTPServer = {
  version: string,
  hostname: string,
  compression: boolean,
  port: number,
  routes: { HTTPRoute },
  new: (self: HTTPServer) -> HTTPServer,
  get: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  post: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  put: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  delete: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  options: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  patch: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  trace: (self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?) -> (),
  static_dir: (self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?) -> (),
  static_file: (self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?) -> (),
  websocket: (self: HTTPServer, path: string, wscallback: WSCallback, config: HTTPRouteConfiguration?) -> (),
  fallback: (self: HTTPServer, callback: Callback) -> (),
  run: (self: HTTPServer) -> (),
  shutdown: (self: HTTPServer) -> (),
}

local astra_internal__start_server: (server: HTTPServer) -> ()
local astra_internal__http_request: (details: string | HTTPClientRequestTableType) -> HTTPClientRequest

local http = {
  server = {},
  request = function(details: string | HTTPClientRequestTableType): HTTPClientRequest
    return astra_internal__http_request(details)
  end,
  middleware = {
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
  },
}

local HTTPServer: HTTPServer = {
  version = "0.0.0",
  hostname = "127.0.0.1",
  compression = false,
  port = 8080,
  routes = {},
  new = function(self: HTTPServer): HTTPServer
    local server: HTTPServer = {
      version = "0.0.0",
      hostname = "127.0.0.1",
      compression = false,
      port = 8080,
      routes = {},
      new = self.new,
      get = self.get,
      post = self.post,
      put = self.put,
      delete = self.delete,
      options = self.options,
      patch = self.patch,
      trace = self.trace,
      static_dir = self.static_dir,
      static_file = self.static_file,
      websocket = self.websocket,
      fallback = self.fallback,
      run = self.run,
      shutdown = self.shutdown,
    }

    setmetatable(server, self)
    self.__index = self
    return server
  end,
  get = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "get", path, callback, config)
  end,
  post = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "post", path, callback, config)
  end,
  put = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "put", path, callback, config)
  end,
  delete = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "delete", path, callback, config)
  end,
  options = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "options", path, callback, config)
  end,
  patch = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "patch", path, callback, config)
  end,
  trace = function(self: HTTPServer, path: string, callback: Callback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "trace", path, callback, config)
  end,
  static_dir = function(self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?): ()
    table.insert(self.routes, {
      path = path,
      method = "static_dir",
      func = function() end,
      static_dir = serve_path,
      config = config or {},
    })
  end,
  static_file = function(self: HTTPServer, path: string, serve_path: string, config: HTTPRouteConfiguration?): ()
    table.insert(self.routes, {
      path = path,
      method = "static_file",
      func = function() end,
      static_file = serve_path,
      config = config or {},
    })
  end,
  websocket = function(self: HTTPServer, path: string, wscallback: WSCallback, config: HTTPRouteConfiguration?): ()
    add_to_routes(self, "web_socket", path, wscallback, config)
  end,
  fallback = function(self: HTTPServer, callback: Callback): ()
    add_to_routes(self, "fallback", "", callback, {})
  end,
  run = function(self: HTTPServer): ()
    astra_internal__start_server(self)
  end,
  shutdown = function(self: HTTPServer): () end,
}

local function add_to_routes(
  server: HTTPServer,
  method: string,
  path: string,
  callback: any,
  config: HTTPRouteConfiguration?
): ()
  local index = if path == "/" then 1 else #server.routes + 1
  table.insert(server.routes, index, {
    path = path,
    method = method,
    func = callback,
    config = config or {},
  })
end

http.server.new = function(): HTTPServer
  return HTTPServer:new()
end

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

return http
