# Filesystem

Astra provides some Filesystem functionality to help extend the standard library. Some of the common ones are as follows:

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
local fs = require("fs")
pprintln(fs.get_script_path())
```

The Filesystem also supports buffers and buffered read and write of files as well.

```lua
-- Begin with creating a buffer with capacity of 10 bytes
local buffer = fs.new_buffer(10)

-- Then open a file to do operations on
local file = fs.open("myfile.txt")

-- You can read the contents
file:read(buffer)

-- Or write
file:write(buffer)
```

There are variations of them as well. Here is the full list:

- `read`
- `read_buffer`
- `read_exact`
- `write`
- `write_buffer`
