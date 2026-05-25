local fs = require("fs")
local env = require("utils").env

local os_path = {}

function os_path:join(...)
  local parts = {...}
  local sep = fs.get_separator()
  if #parts == 0 then return "" end
  local result = parts[1]
  for i = 2, #parts do
    local part = parts[i]
    if type(part) ~= "string" then part = tostring(part) end
    if part:sub(1, 1) == sep then
      result = part
    else
      if result:sub(-1) ~= sep then
        result = result .. sep
      end
      result = result .. part
    end
  end
  return result
end

function os_path:basename(path)
  local sep = fs.get_separator()
  local i = path:match("^.*()" .. sep .. "[^" .. sep .. "]*$")
  if i then
    return path:sub(i + 1)
  end
  return path
end

function os_path:dirname(path)
  local sep = fs.get_separator()
  local i = path:match("^.*()" .. sep .. "[^" .. sep .. "]*$")
  if i then
    return path:sub(1, i - 1)
  end
  return "."
end

function os_path:exists(path)
  return fs.exists(path)
end

function os_path:splitext(path)
  local i = path:match("^.+(%.[^.]*)$")
  if i then
    return path:sub(1, #path - #i), i
  end
  return path, ""
end

function os_path:getsize(path)
  local content = fs.read_file(path)
  return #content
end

function os_path:isfile(path)
  local meta = fs.get_metadata(path)
  return meta and meta.file_type == "file" or false
end

function os_path:isdir(path)
  local meta = fs.get_metadata(path)
  return meta and meta.file_type == "directory" or false
end

function os_path:abspath(path)
  local sep = fs.get_separator()
  if path:sub(1, 1) == sep then
    return path
  end
  return os_path:join(fs.get_current_dir(), path)
end

local os_mod = {}

function os_mod:getcwd()
  return fs.get_current_dir()
end

function os_mod:chdir(path)
  fs.change_dir(path)
end

function os_mod:listdir(path)
  path = path or "."
  local entries = fs.read_dir(path)
  local result = {}
  for _, entry in ipairs(entries) do
    result[#result + 1] = entry.name or entry
  end
  return result
end

function os_mod:mkdir(path)
  fs.create_dir(path)
end

function os_mod:makedirs(path)
  fs.create_dir_all(path)
end

function os_mod:remove(path)
  fs.remove(path)
end

function os_mod:rename(old, new)
  local content = fs.read_file(old)
  fs.write_file(new, content)
  fs.remove(old)
end

os_mod.environ = setmetatable({}, {
  __index = function(_, key)
    return env.get(key)
  end,
  __newindex = function(_, key, value)
    env.set(key, value)
  end,
})

os_mod.sep = fs.get_separator()
os_mod.pathsep = ":"
os_mod.linesep = "\n"

os_mod.path = os_path

function os_mod:system(command)
  return os.execute(command)
end

function os_mod:name()
  local sep = fs.get_separator()
  if sep == "\\" then return "nt" end
  return "posix"
end

return os_mod
