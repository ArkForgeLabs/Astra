---@meta

local io = {}

---@class FileType
---@field is_file fun(file_type: FileType): boolean
---@field is_dir fun(file_type: FileType): boolean
---@field is_symlink fun(file_type: FileType): boolean

---@class DirEntry
---@field file_name fun(dir_entry: DirEntry): string Returns the file_name of the entry
---@field file_type fun(dir_entry: DirEntry): FileType
---@field path fun(dir_entry: DirEntry): string Returns the path of each entry in the list

---@class FileMetadata
---@field last_accessed fun(file_metadata: FileMetadata): number
---@field created_at fun(file_metadata: FileMetadata): number
---@field last_modified fun(file_metadata: FileMetadata): number
---@field file_type fun(file_metadata: FileMetadata): FileType
---@field file_permissions fun(file_metadata: FileMetadata): FileIOPermissions

---@class FileIOPermissions
---@field is_readonly fun(file_io_permissions: FileIOPermissions): boolean
---@field set_readonly fun(file_io_permissions: FileIOPermissions, value: boolean)

---Returns the entire content of the file
---@param path string Path to the file
---@return string
function io.read_file(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_file_string(path)
end

---Returns the entire content of the file as bytes
---@param path string Path to the file
---@return number[]
function io.read_file_bytes(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_file_bytes(path)
end

---Returns the entire content of the file
---@param path string Path to the file
---@param contents string | number[] | table
function io.write_file(path, contents)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__write_file(path, contents)
end

---Returns the metadata of a file or directory
---@param path string
---@return FileMetadata
function io.get_metadata(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_metadata(path)
end

---Returns the content of the directory
---@param path string Path to the file
---@return DirEntry[]
function io.read_dir(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_dir(path)
end

---Returns the path of the current directory
---@return string
function io.get_current_dir() ---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_current_dir()
end

---Returns the path separator based on the operating system
---@return string
function io.get_separator()
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_separator()
end

---Returns the path of the current running script
---@return string
function io.get_script_path()
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_script_path()
end

---Changes the current directory
---@param path string Path to the directory
function io.change_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__change_dir(path)
end

---Checks if a path exists
---@param path string Path to the file or directory
---@return boolean
function io.exists(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__exists(path)
end

---Creates a directory
---@param path string Path to the directory
function io.create_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__create_dir(path)
end

---Creates a directory recursively
---@param path string Path to the directory
function io.create_dir_all(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__create_dir_all(path)
end

---Removes a file
---@param path string Path to the file
function io.remove(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove(path)
end

---Removes a directory
---@param path string Path to the directory
function io.remove_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove_dir(path)
end

---Removes a directory recursively
---@param path string Path to the directory
function io.remove_dir_all(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove_dir_all(path)
end

return io
