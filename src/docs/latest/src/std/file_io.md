# File IO

Astra provides some File IO functionality to help extend the standard library. Which contains the IO functions. The current list is as follows:

- `get_metadata`
- `read_dir`
- `get_current_dir`
- `get_script_path`
- `get_separator`
- `change_dir`
- `exists`
- `create_dir`
- `create_dir_all`
- `remove`
- `remove_dir`
- `remove_dir_all`

They are fairly self explanitory and does not require further details. Example usage:

```lua
local io = require("io")
pprint(Astra.io.get_script_path())
```
