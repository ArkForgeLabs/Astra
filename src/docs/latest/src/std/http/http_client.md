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
pprint(response:body():text())
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
  -- You can also execute as an async task
  :execute_task(function (result) end)
```
