![Banner](https://astra.arkforge.net/banner.png)

[![Release Linux](https://github.com/ArkForgeLabs/Astra/actions/workflows/linux_release.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/linux_release.yml)
[![Release Windows](https://github.com/ArkForgeLabs/Astra/actions/workflows/windows_release.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/windows_release.yml)
[![Release MacOS](https://github.com/ArkForgeLabs/Astra/actions/workflows/macos_release.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/macos_release.yml)
[![Publish the crate](https://github.com/ArkForgeLabs/Astra/actions/workflows/crates_io_publish.yml/badge.svg)](https://github.com/ArkForgeLabs/Astra/actions/workflows/crates_io_publish.yml)
[![Static Badge](https://img.shields.io/badge/Read_The_Docs-blue?style=flat&logo=docsdotrs&color=%23000000)](https://astra.arkforge.net/docs/latest)

Astra is a Rust based runtime environment for Lua (5.1-5.5), Luau and LuaJIT, and with native support for Teal. The goal is to get as much performance as possible while writing the logic in Lua instead for faster iteration, fault-tolerance and no-build requirements. This project is internally used here at [ArkForge](https://arkforge.net), by universities, research labs, and many large organizations.

For enterprise and business inquiries, send us an email at [contact@arkforge.net](mailto:contact@arkforge.net)

> MSRV: 1.88+

## installation

You can install using an installer script:

### Linux

```bash
sh -c "$(curl -fsSL https://astra.arkforge.net/install.sh)"
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

Or fancy some multi threaded async code

```lua
-- spawn an async task that does not block the running thread
spawn_task(function ()
    -- HTTP Request to check your IP address
    local response = require("http").request("https://myip.wtf/json"):execute()
    pprintln(response:status_code(), response:remote_address(), response:body():json())
end)
```

What about some databases and serialization?

```lua
local my_data = require("serde").json.decode('{"name": "John Astra", "age": 21}')

local db = require("database").new("sqlite", ":memory:")
db:execute([[
    CREATE TABLE IF NOT EXISTS data (id INTEGER PRIMARY KEY, name TEXT, age INTEGER) strict;
    INSERT INTO data (name, age) VALUES ($1, $2);
]], { my_data.name, my_data.age })

pprintln(db:query_all("SELECT * FROM data"))
```

There is also support for cryptography, datetime, jinja2, pubsub/observers, structure validation, async filesystem, and many more, check them at at the [docs](https://astra.arkforge.net/docs/latest)

## Community Projects

- Astra Trails - <https://github.com/0riginaln0/astra-trails>
- Hack Club Clubs API - <https://github.com/hackclub/clubapi>

If you have a project that uses or extends Astra, let us know about it by extending the list above or opening a new [issue](https://github.com/ArkForgeLabs/Astra/issues/new)

## Where is the community?

In the past, we had a discord server where you could join and talk in, however we moved it to [GitHub discussions](https://github.com/ArkForgeLabs/Astra/discussions) instead. Please open conversations here from now on.

## Note

This project may have breaking changes in minor versions until v1.0. Afterwhich semver will be followed. Contributions are always welcome!
