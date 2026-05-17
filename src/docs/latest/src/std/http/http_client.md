# HTTP Client

Sometimes your server needs to access other servers and make an HTTP Request, for these cases Astra provides a HTTP Client function:

```lua
-- Import
local http = require("http")

-- By default its always a GET request
local response = http.request("https://example.com/"):execute()
print(response:status_code())
print(response:headers())
print(response:remote_address())
print(response:body():text()) -- or response:body():json() for json content
```

The `http.request` function returns a `HTTPClientRequest` object which can be further modified to the needs before execution. The way to do these modification is through chained setters.

```lua
local request_client = http.request("https://example.com")
-- - Method. You can pick between one of these:
--   - CONNECT
--   - OPTIONS
--   - DELETE
--   - TRACE
--   - PATCH
--   - HEAD
--   - POST
--   - PUT
--   - GET
-- Or any custom method, as long as its valid.
  :set_method("POST")
  :set_header("key", "value")
  :set_headers({ key = "value" })
  :set_form("key", "value")
  :set_body("THE CONTENT OF THE BODY")
  :set_file("/path/to/file")
  :execute()
```

You can also instead of chaining functions, just pass a table containing these values as such:

```lua
local request_client = http.request({
  url = "https://example.com",
  method = "POST",
  headers = {},
  body = {
    keys = "body accepts string, table (json), or even byte array"
  }
})
```

For more complex requests, such as API calls with authentication and JSON payloads:

```lua
local http = require("http")

http.request({
    url = "https://api.example-ai-company.com/v1",
    method = "POST",
    headers = {
        ["Authorization"] = "Bearer " .. os.getenv("TOKEN")
    },
    body = {
        model = "CoolCodeAI/CoolModel-3B-Instruct",
        stream = true,
        messages = {
            {
                role = "user",
                content = "Hello!"
            }
        }
    },
}):execute_streaming(function(response)
    -- Handle streaming response chunks
    print(response:body():json())
end)
```

finally, you can execute the request to obtain the result:

```lua
-- returns the result
local response = request_client:execute()

-- execute in async manner, and run a callback when the response arrives
request_client:execute_task( function(response) end )

-- or execute in streaming manner and get response chunks
request_client:execute_streaming( function(response) end )
```
