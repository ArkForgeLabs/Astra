---@meta

local fs = {}

---@class File
---Pulls some bytes from this source into the specified buffer, returning how many bytes were read. A nonzero n value indicates that the buffer buf has been filled in with n bytes of data from this source.
---@field read fun(self: File, buffer: Buffer)
---Pulls some bytes from this source into the specified buffer, advancing the buffer's internal cursor. A nonzero n value indicates that the buffer buf has been filled in with n bytes of data from this source.
---@field read_buf fun(self: File, buffer: Buffer)
---Reads the exact number of bytes required to fill buffer.
---@field read_exact fun(self: File, buffer: Buffer)
---This function will attempt to write the entire contents of buffer, but the entire write may not succeed, or the write may also generate an error. A call to write represents at most one attempt to write to any wrapped object. If the return value is n then it must be guaranteed that n <= len(buf). A return value of 0 typically means that the underlying object is no longer able to accept bytes and will likely not be able to in the future as well, or that the buffer provided is empty.
---@field write fun(self: File, buffer: Buffer)
---This method will continuously call write until buffer remaining calls returns false. This method will not return until the entire buffer has been successfully written or an error occurs. The first error generated will be returned. The buffer is advanced after each chunk is successfully written.
---@field write_buf fun(self: File, buffer: Buffer)

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

---Creates a new buffer with size in bytes allocated
---@param capacity number
---@return Buffer
function fs.new_buffer(capacity)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__new_buffer(capacity)
end

---Opens the file in the given path
---@param path string
---@return File
function fs.open(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__open_file(path)
end

---Returns the entire content of the file
---@param path string Path to the file
---@return string
function fs.read_file(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_file_string(path)
end

---Returns the entire content of the file as bytes
---@param path string Path to the file
---@return number[]
function fs.read_file_bytes(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_file_bytes(path)
end

---Returns the entire content of the file
---@param path string Path to the file
---@param contents string | number[] | table
function fs.write_file(path, contents)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__write_file(path, contents)
end

---Returns the metadata of a file or directory
---@param path string
---@return FileMetadata
function fs.get_metadata(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_metadata(path)
end

---Returns the content of the directory
---@param path string Path to the file
---@return DirEntry[]
function fs.read_dir(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__read_dir(path)
end

---Returns the path of the current directory
---@return string
function fs.get_current_dir() ---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_current_dir()
end

---Returns the path separator based on the operating system
---@return string
function fs.get_separator()
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_separator()
end

---Returns the path of the current running script
---@return string
function fs.get_script_path()
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__get_script_path()
end

---Changes the current directory
---@param path string Path to the directory
function fs.change_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__change_dir(path)
end

---Checks if a path exists
---@param path string Path to the file or directory
---@return boolean
function fs.exists(path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__exists(path)
end

---Creates a directory
---@param path string Path to the directory
function fs.create_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__create_dir(path)
end

---Creates a directory recursively
---@param path string Path to the directory
function fs.create_dir_all(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__create_dir_all(path)
end

---Removes a file
---@param path string Path to the file
function fs.remove(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove(path)
end

---Removes a directory
---@param path string Path to the directory
function fs.remove_dir(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove_dir(path)
end

---Removes a directory recursively
---@param path string Path to the directory
function fs.remove_dir_all(path)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__remove_dir_all(path)
end

return fs
