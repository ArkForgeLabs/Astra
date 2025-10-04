# HTTP Client

Sometimes your server needs to access other servers and make an HTTP Request, for these cases Astra provides a HTTP Client function:

```lua
-- Import
local http = require("astra.lua.http")

-- By default its always a GET request
local response = http.request("https://example.com/"):execute()
pprint(response:status_code())
pprint(response:headers())
pprint(response:remote_address())
pprint(response:body():text()) -- or response:body():json() for json content
```

The `http.request` function returns a `HTTPClientRequest` object which can be further modified to the needs before execution. The way to do these modification is through chained setters.

```lua
local request_client = http.request("https://example.com")
-- - Method. You can pick between one of these:
--   - GET,
--   - POST,
--   - PUT,
--   - PATCH,
--   - DELETE,
--   - HEAD,
  :set_method("POST")
  :set_header("key", "value")
  :set_headers({ key = "value" })
  :set_form("key", "value")
  :set_forms({ key = "value" })
  :set_body("THE CONTENT OF THE BODY")
  :set_json({ key = "value" })
  :set_file("/path/to/file")
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

finally, you can execute the request to obtain the result:

```lua
-- returns the result
local response = request_client:execute()

-- execute in async manner, and run a callback when the response arrives
request_client:execute_task( function(response) end )

-- or execute in streaming manner and get response chunks
request_client:execute_streaming( function(response) end )
```
