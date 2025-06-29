---@meta

Astra.io = {}

---@class FileMetadata
local FileMetadata = {}

---@return number
function FileMetadata:last_accessed() end

---@return number
function FileMetadata:created_at() end

---@return number
function FileMetadata:last_modified() end

---@return FileType
function FileMetadata:file_type() end

---@return FileIOPermissions
function FileMetadata:file_permissions() end

---Returns the metadata of a file or directory
---@param path string
---@return FileMetadata
function Astra.io.get_metadata(path) end

---Returns the content of the directory
---@param path string Path to the file
---@return DirEntry[]
function Astra.io.read_dir(path) end

---Returns the path of the current directory
---@return string
function Astra.io.get_current_dir() end

---Returns the path separator based on the operating system
---@return string
function Astra.io.get_separator() end

---Returns the path of the current running script
---@return string
function Astra.io.get_script_path() end

---Changes the current directory
---@param path string Path to the directory
function Astra.io.change_dir(path) end

---Checks if a path exists
---@param path string Path to the file or directory
---@return boolean
function Astra.io.exists(path) end

---Creates a directory
---@param path string Path to the directory
function Astra.io.create_dir(path) end

---Creates a directory recursively
---@param path string Path to the directory
function Astra.io.create_dir_all(path) end

---Removes a file
---@param path string Path to the file
function Astra.io.remove(path) end

---Removes a directory
---@param path string Path to the directory
function Astra.io.remove_dir(path) end

---Removes a directory recursively
---@param path string Path to the directory
function Astra.io.remove_dir_all(path) end

---@class FileType
local FileType = {}

---@return boolean
function FileType:is_file() end

---@return boolean
function FileType:is_dir() end

---@return boolean
function FileType:is_symlink() end

---@class DirEntry
local DirEntry = {}

---Returns the file_name of the entry
---@return string
function DirEntry:file_name() end

---@return FileType
function DirEntry:file_type() end

---Returns the path of each entry in the list
---@return string
function DirEntry:path() end

---@class FileMetadata
local FileMetadata = {}

---@return number
function FileMetadata:last_accessed() end

---@return number
function FileMetadata:created_at() end

---@return number
function FileMetadata:last_modified() end

---@return FileType
function FileMetadata:file_type() end

---@return FileIOPermissions
function FileMetadata:file_permissions() end

---@class FileIOPermissions
local FileIOPermissions = {}

---@return boolean
function FileIOPermissions:is_readonly() end

---@param value boolean
function FileIOPermissions:set_readonly(value) end
