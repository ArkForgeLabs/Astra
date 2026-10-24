# Globals

These globals are provided by Lua itself. They are always registered in fully open runs (`astra run script.lua`), and inside [sandboxed](../sandbox.md) runs (`astra run --allow=globals,...`).

## getenv

Reads an environment variable, returning its value or `nil` when it is not set. This matches `os.getenv` semantics, so the `... or default` idiom works:

```lua
local home = getenv("HOME")
if home then
    print("Home is: " .. home)
end

local workers = getenv("WORKERS") or "4"
```

## setenv

Sets an environment variable for the current process. Newly set variables are visible to `getenv`, to subsequent `dotenv_load` calls, and to any child processes spawned by the runtime:

```lua
setenv("APP_ENV", "production")
print(getenv("APP_ENV")) -- production
```

## loadfile

Loads a Lua file from disk and returns it as a function. On failure it returns `nil` plus a message instead of raising, matching Lua's base `loadfile`:

```lua
local chunk, err = loadfile("optional-plugin.lua")
if chunk then
    chunk()
else
    print("plugin unavailable: " .. err)
end
```

## dofile

Loads, executes and returns the result of a Lua file. Unlike `loadfile`, failures raise:

```lua
dofile("config.lua")
```

## require

The module loader is provided by Astra's [import system](../sandbox.md#imports): it resolves local files next to the running script, the standard-library modules shipped with the runtime (`fs`, `http`, `crypto`, `serde`, `datetime`, `database`, `utils`, `templates`, ...) and falls back to the engine's native loader on full VMs. Modules are cached, so repeated `require` calls return the same table.
