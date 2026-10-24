# Sandbox

Astra can run scripts in a sandboxed VM that only exposes the capabilities you explicitly allow. Sandbox mode is opt-in: pass any `--allow` list to `astra run`.

## VM policy

| Invocation | VM |
| --- | --- |
| `astra run script.lua` (no flags) | **Fully open** — complete engine standard library (`string`, `table`, `math`, ...) plus every Astra component |
| `astra run --allow=file-system script.lua` | **Sandboxed** — engine stdlibs disabled; only the allowed components register; base globals are sanitized |
| `astra run --allow=none script.lua` | **Sandboxed, nothing allowed** — no components at all, base globals stubbed, `require` removed |
| Packed binaries (`astra pack`) | **Fully open** — same as a no-flag run |

## Flags

Each flag maps to one capability. Repeat flags or comma-separate them:

| Flag | Grants |
| --- | --- |
| `--allow=none` | nothing (runs a fully denied VM) |
| `--allow=globals` | `print`, `getenv`, `setenv`, `loadfile`, `dofile` |
| `--allow=import` | the module loader (`require`) |
| `--allow=file-system` | the `fs` module |
| `--allow=utils` | `utils`: tasks, env helpers, uuid, regex, glob |
| `--allow=crypto` | the `crypto` module |
| `--allow=datetime` | the `datetime` module |
| `--allow=database` | the `database` module |
| `--allow=http-client` | outbound HTTP / WebSockets |
| `--allow=http-server` | binding HTTP servers |
| `--allow=serde` | the `serde` module (JSON, TOML, YAML, INI, XML, CSV, JSON5) |
| `--allow=templates` | the `templates` module (Jinja2, Markdown) |

Examples:

```bash
# everything except network access
astra run server.lua --allow=globals,import,file-system,utils,crypto,datetime,database,serde,templates

# only filesystem access and imports
astra run app.lua --allow=file-system,import

# deny everything
astra run app.lua --allow=none
```

## Base sanitation

Sandboxed VMs stub the base globals that reach the filesystem, environment or code loader before any component registers. Every engine raises the same errors:

```
print is disabled in sandbox mode
loadfile is disabled in sandbox mode
```

`require` is removed (`nil`) instead of stubbed so that Lua 5.x, LuaJIT and Luau behave identically; the import component replaces it when `--allow=import` is passed. Components re-install the real implementations when their flag is allowed, so an allowed capability works exactly as it does in a fully open run.

## Imports

Module resolution follows the same rules in every VM:

- **Embedded standard-library modules** are gated by their flag: with `--allow=import,file-system` `require("fs")` works, while `require("http")` fails with a clean `Could not find the module http` error.
- **Modules without a dedicated flag** (`stores`, `validation`, `test`) are allowed whenever `import` is — they are treated with the same trust as local files.
- **On-disk files** next to the running script (or in its directory tree, the `lua/` folder or the standard-library path) load whenever `import` is allowed. The resolver tries the working directory first, then the runtime standard-library folder, then the requiring script's directory — the first existing match wins.
- Modules are cached: `require` returns the same table for the same module inside one run.

## Notes for packed binaries

`astra pack` snapshots your modules at pack time using the same resolution rules, and the resulting binary always runs in a fully open VM. Unresolvable imports are not embedded; at runtime they fall back to the normal loader exactly as they would in an unpacked run.
