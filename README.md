![Banner](https://astra.arkforge.net/banner.png)

[![Release Linux](https://github.com/ArkForgeLabs/Astra/actions/workflows/linux_release.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/linux_release.yml)
[![Release Windows](https://github.com/ArkForgeLabs/Astra/actions/workflows/windows_release.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/windows_release.yml)
[![Publish the crate](https://github.com/ArkForgeLabs/Astra/actions/workflows/crates_io_publish.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/crates_io_publish.yml)
[![Static Badge](https://img.shields.io/badge/Join-The_Discord-blue?style=flat&logo=discord&color=blue)](https://discord.com/invite/6PMjUx8x3b)
[![Static Badge](https://img.shields.io/badge/Read_The_Docs-blue?style=flat&logo=docsdotrs&color=%23000000)](https://astra.arkforge.net/docs/latest)

Astra is a web server runtime for Lua (5.1-5.4), Luau and LuaJIT written in Rust with native support for Teal. The goal is to get as much performance as possible while writing the web server logic in Lua instead for faster iteration, fault-tolerance and no-build requirements. This project is internally used here at [ArkForge](https://arkforge.net) and many others.

For Enterprise and business inquiries, send us an email at [contact@arkforge.net](mailto:contact@arkforge.net)

> MSRV: 1.88+

## installation

You can install using an installer script:

### Linux

```bash
sh -c "$(curl -fsSL http://127.0.0.1:8000/install.sh)"
```

### Windows

```powershell
powershell -c "irm https://astra.arkforge.net/install.ps1 | iex"
```

### Cargo

Alternatively you can also install through [cargo](https://doc.rust-lang.org/cargo/) tool, if you have it installed:

```bash
cargo install lua-astra
```

## Example

```lua
-- Create a new server
local server = require("http").server.new()

-- Register a route
server:get("/", function()
    return "hello from default Astra instance!"
end)

-- Configure the server
server.port = 3000

-- Run the server
server:run()
```

You can also use the local variables within routes

```lua
local counter = 0
server:get("/count", function()
    counter = counter + 1
    -- and also can return JSON
    return { counter = counter }
end)
```

Requests and Responses and their configuration are provided when needed

```lua
server:get("/", function(request, response)
    -- set header code
    response:set_status_code(300)
    -- set headers
    response:set_header("header-key", "header-value")

    -- consume the request body
    print(request:body():text())

    return "Responding with Code 300 cuz why not"
end)
```

There are also utilities provided such as a PostgreSQL/SQLite, http client requests, lua extra utils, and async tasks.

```lua
-- spawn an async task that does not block the running thread
spawn_task(function ()
    -- HTTP Request to check your IP address
    local response = require("http").request("https://myip.wtf/json"):execute()
    pprint(response:status_code())
    pprint(response:remote_address())
    pprint(response:body():json())
end)
```

## Community Projects

- Astra Trails - <https://github.com/0riginaln0/astra-trails>

If you have a project that uses or extends Astra, let us know about it by extending the list above or opening a new [issue](https://github.com/ArkForgeLabs/Astra/issues/new)

## Note

This project may have breaking changes in minor versions until v1.0. Afterwhich semver will be followed. Contributions are always welcome!
