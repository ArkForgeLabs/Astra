require("http")

local fs = {}

global record File
    read: function(self: File, buffer: Buffer)
    read_buffer: function(self: File, buffer: Buffer)
    read_exact: function(self: File, buffer: Buffer)
    write: function(self: File, buffer: Buffer)
    write_buffer: function(self: File, buffer: Buffer)
end

global record FileType is userdata
	is_file: function(self: FileType): boolean
	is_dir: function(self: FileType): boolean
	is_symlink: function(self: FileType): boolean
end

global record DirEntry is userdata
	file_name: function(self: DirEntry): string
	file_type: function(self: DirEntry): FileType
	path: function(self: DirEntry): string
end

global record FileMetadata is userdata
	last_accessed: function(self: FileMetadata): number
	created_at: function(self: FileMetadata):  number
	last_modified: function(self: FileMetadata): number
	file_type: function(self: FileMetadata): FileType
	file_permissions: function(self: FileMetadata): FileIOPermissions
end

global record FileIOPermissions is userdata
	is_readonly: function(self: FileIOPermissions): boolean
	set_readonly: function(self: FileIOPermissions, value: boolean)
end

local type astra_internal__new_buffer = function(capacity: number): Buffer
---Creates a new buffer with size in bytes allocated
function fs.new_buffer(capacity: number): Buffer
	return astra_internal__new_buffer(capacity)
end

local type astra_internal__open_file = function(path: string): File
---Opens the file in the given path
function fs.open(path: string): File
	return astra_internal__open_file(path)
end

local type astra_internal__get_metadata = function(path: string): FileMetadata
---Returns the metadata of a file or directory
function fs.get_metadata(path: string): FileMetadata
	return astra_internal__get_metadata(path)
end

local type astra_internal__read_file_string = function(path: string): string
---Returns the entire content of the file
function fs.read_file(path: string): string
	return astra_internal__read_file_string(path)
end

local type astra_internal__read_file_bytes = function(path: string): {number}
---Returns the entire content of the file as bytes
function fs.read_file_bytes(path: string): {number}
	return astra_internal__read_file_bytes(path)
end

local type astra_internal__write_file = function(path: string, content: string | table)
---Returns the entire content of the file
function fs.write_file(path: string, contents: string | table)
	return astra_internal__write_file(path, contents)
end

local type astra_internal__read_dir = function(path: string): {DirEntry}
---Returns the content of the directory
function fs.read_dir(path: string): {DirEntry}
	return astra_internal__read_dir(path)
end

local type astra_internal__get_current_dir = function(): string
---Returns the path of the current directory
function fs.get_current_dir(): string
	return astra_internal__get_current_dir()
end

local type astra_internal__get_separator = function(): string
---Returns the path separator based on the operating system
function fs.get_separator(): string
	return astra_internal__get_separator()
end

local type astra_internal__get_script_path = function(): string
---Returns the path of the current running script
function fs.get_script_path(): string
	return astra_internal__get_script_path()
end

local type astra_internal__change_dir = function(path: string)
---Changes the current directory
function fs.change_dir(path: string)
	astra_internal__change_dir(path)
end

local type astra_internal__exists = function(path: string): boolean
---Checks if a path exists
function fs.exists(path: string): boolean
	return astra_internal__exists(path)
end

local type astra_internal__create_dir = function(path: string)
---Creates a directory
function fs.create_dir(path: string): string
	astra_internal__create_dir(path)
end

local type astra_internal__create_dir_all = function(path: string)
---Creates a directory recursively
function fs.create_dir_all(path: string): string
	astra_internal__create_dir_all(path)
end

local type astra_internal__remove = function(path: string)
---Removes a file
function fs.remove(path: string)
	astra_internal__remove(path)
end

local type astra_internal__remove_dir = function(path: string)
---Removes a directory
function fs.remove_dir(path: string): string
	astra_internal__remove_dir(path)
end
local type astra_internal__remove_dir_all = function(path: string)
---Removes a directory recursively
function fs.remove_dir_all(path: string): string
	astra_internal__remove_dir_all(path)
end

return fs
