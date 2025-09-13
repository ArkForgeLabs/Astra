local file_io = {}

global interface FileType is userdata
	is_file: function(file_type: FileType): boolean
	is_dir: function(file_type: FileType): boolean
	is_symlink: function(file_type: FileType): boolean
end

global interface DirEntry is userdata
	file_name: function(dir_entry: DirEntry): string
	file_type: function(dir_entry: DirEntry): FileType
	path: function(dir_entry: DirEntry): string
end

global interface FileMetadata is userdata
	last_accessed: function(file_metadata: FileMetadata): number
	created_at: function(file_metadata: FileMetadata):  number
	last_modified: function(file_metadata: FileMetadata): number
	file_type: function(file_metadata: FileMetadata): FileType
	file_permissions: function(file_metadata: FileMetadata): FileIOPermissions
end

global interface FileIOPermissions is userdata
	is_readonly: function(file_io_permissions: FileIOPermissions): boolean
	set_readonly: function(file_io_permissions: FileIOPermissions, value: boolean)
end

local type astra_internal__get_metadata = function(path: string): FileMetadata
---Returns the metadata of a file or directory
function file_io.get_metadata(path: string): FileMetadata
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_metadata(path)
end

local type astra_internal__read_dir = function(path: string): {DirEntry}
---Returns the content of the directory
function file_io.read_dir(path: string): {DirEntry}
	return astra_internal__read_dir(path)
end

local type astra_internal__get_current_dir = function(): string
---Returns the path of the current directory
function file_io.get_current_dir(): string
	return astra_internal__get_current_dir()
end

local type astra_internal__get_separator = function(): string
---Returns the path separator based on the operating system
function file_io.get_separator(): string
	return astra_internal__get_separator()
end

local type astra_internal__get_script_path = function(): string
---Returns the path of the current running script
function file_io.get_script_path(): string
	return astra_internal__get_script_path()
end

local type astra_internal__change_dir = function(path: string)
---Changes the current directory
function file_io.change_dir(path: string)
	astra_internal__change_dir(path)
end

local type astra_internal__exists = function(path: string): boolean
---Checks if a path exists
function file_io.exists(path: string): boolean
	return astra_internal__exists(path)
end

local type astra_internal__create_dir = function(path: string)
---Creates a directory
function file_io.create_dir(path: string): string
	astra_internal__create_dir(path)
end

local type astra_internal__create_dir_all = function(path: string)
---Creates a directory recursively
function file_io.create_dir_all(path: string): string
	astra_internal__create_dir_all(path)
end

local type astra_internal__remove = function(path: string)
---Removes a file
function file_io.remove(path: string)
	astra_internal__remove(path)
end

local type astra_internal__remove_dir = function(path: string)
---Removes a directory
function file_io.remove_dir(path: string): string
	astra_internal__remove_dir(path)
end
local type astra_internal__remove_dir_all = function(path: string)
---Removes a directory recursively
function file_io.remove_dir_all(path: string): string
	astra_internal__remove_dir_all(path)
end

return file_io
