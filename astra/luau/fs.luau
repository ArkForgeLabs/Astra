--!nocheck
--!nolint

type File = {
  path: (self: File) -> string,
  --- Pulls some bytes from this source into the specified buffer, returning how many bytes were read.
  read: (self: File, buffer: Buffer) -> (),
  --- Pulls some bytes from this source into the specified buffer, advancing the buffer's internal cursor.
  read_buffer: (self: File, buffer: Buffer) -> (),
  --- Reads the exact number of bytes required to fill buffer.
  read_exact: (self: File, buffer: Buffer) -> (),
  --- This function will attempt to write the entire contents of buffer.
  write: (self: File, buffer: Buffer) -> (),
  --- This method will continuously call write until buffer remaining calls returns false.
  write_buffer: (self: File, buffer: Buffer) -> (),
}

type EntryType = {
  is_file: (self: EntryType) -> boolean,
  is_dir: (self: EntryType) -> boolean,
  is_symlink: (self: EntryType) -> boolean,
}

type DirEntry = {
  --- Returns the file_name of the entry
  file_name: (self: DirEntry) -> string,
  type: (self: DirEntry) -> EntryType,
  --- Returns the path of each entry in the list
  path: (self: DirEntry) -> string,
}

type Metadata = {
  last_accessed: (self: Metadata) -> number,
  created_at: (self: Metadata) -> number,
  last_modified: (self: Metadata) -> number,
  type: (self: Metadata) -> EntryType,
  file_permissions: (self: Metadata) -> FileIOPermissions,
}

type FileIOPermissions = {
  is_readonly: (self: FileIOPermissions) -> boolean,
  set_readonly: (self: FileIOPermissions, value: boolean) -> (),
}

type GlobResult = {
  --- The directory path that entries are in
  base_path: string,
  entries: {string}
}

local fs = {}

--- Parses a path and matches entries with given filenames.
---
--- For example "examples/templates/**/*.html"
function fs.parse_glob(path: string): GlobResult
  return astra_internal__parse_glob(path)
end

--- Creates a new buffer with size in bytes allocated
function fs.new_buffer(capacity: number): Buffer
  return astra_internal__new_buffer(capacity)
end

--- Opens the file in the given path
function fs.open(path: string): File
  return astra_internal__open_file(path)
end

--- Returns the entire content of the file
function fs.read_file(path: string): string
  return astra_internal__read_file_string(path)
end

--- Returns the entire content of the file as bytes
function fs.read_file_bytes(path: string): { number }
  return astra_internal__read_file_bytes(path)
end

--- Returns the entire content of the file
function fs.write_file(path: string, contents: string | { number } | { any }): ()
  return astra_internal__write_file(path, contents)
end

--- Returns the metadata of a file or directory
function fs.get_metadata(path: string): Metadata
  return astra_internal__get_metadata(path)
end

--- Returns the content of the directory
function fs.read_dir(path: string): { DirEntry }
  return astra_internal__read_dir(path)
end

--- Returns the path of the current directory
function fs.get_current_dir(): string
  return astra_internal__get_current_dir()
end

--- Returns the path separator based on the operating system
function fs.get_separator(): string
  return astra_internal__get_separator()
end

--- Returns the path of the current running script
function fs.get_script_path(): string
  return astra_internal__get_script_path()
end

--- Changes the current directory
function fs.change_dir(path: string): ()
  astra_internal__change_dir(path)
end

--- Checks if a path exists
function fs.exists(path: string): boolean
  return astra_internal__exists(path)
end

--- Creates a directory
function fs.create_dir(path: string): ()
  astra_internal__create_dir(path)
end

--- Creates a directory recursively
function fs.create_dir_all(path: string): ()
  astra_internal__create_dir_all(path)
end

--- Removes a file
function fs.remove(path: string): ()
  astra_internal__remove(path)
end

--- Removes a directory
function fs.remove_dir(path: string): ()
  astra_internal__remove_dir(path)
end

--- Removes a directory recursively
function fs.remove_dir_all(path: string): ()
  astra_internal__remove_dir_all(path)
end

return fs
