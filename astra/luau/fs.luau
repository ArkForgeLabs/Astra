--!strict

type File = {
  read: (self: File, buffer: Buffer) -> (),
  read_buffer: (self: File, buffer: Buffer) -> (),
  read_exact: (self: File, buffer: Buffer) -> (),
  write: (self: File, buffer: Buffer) -> (),
  write_buffer: (self: File, buffer: Buffer) -> (),
}

type FileType = {
  is_file: (self: FileType) -> boolean,
  is_dir: (self: FileType) -> boolean,
  is_symlink: (self: FileType) -> boolean,
}

type DirEntry = {
  file_name: (self: DirEntry) -> string,
  file_type: (self: DirEntry) -> FileType,
  path: (self: DirEntry) -> string,
}

type FileMetadata = {
  last_accessed: (self: FileMetadata) -> number,
  created_at: (self: FileMetadata) -> number,
  last_modified: (self: FileMetadata) -> number,
  file_type: (self: FileMetadata) -> FileType,
  file_permissions: (self: FileMetadata) -> FileIOPermissions,
}

type FileIOPermissions = {
  is_readonly: (self: FileIOPermissions) -> boolean,
  set_readonly: (self: FileIOPermissions, value: boolean) -> (),
}

local astra_internal__new_buffer: (capacity: number) -> Buffer
local astra_internal__open_file: (path: string) -> File
local astra_internal__read_file_string: (path: string) -> string
local astra_internal__read_file_bytes: (path: string) -> { number }
local astra_internal__write_file: (path: string, contents: string | { number } | { any }) -> ()
local astra_internal__get_metadata: (path: string) -> FileMetadata
local astra_internal__read_dir: (path: string) -> { DirEntry }
local astra_internal__get_current_dir: () -> string
local astra_internal__get_separator: () -> string
local astra_internal__get_script_path: () -> string
local astra_internal__change_dir: (path: string) -> ()
local astra_internal__exists: (path: string) -> boolean
local astra_internal__create_dir: (path: string) -> ()
local astra_internal__create_dir_all: (path: string) -> ()
local astra_internal__remove: (path: string) -> ()
local astra_internal__remove_dir: (path: string) -> ()
local astra_internal__remove_dir_all: (path: string) -> ()

local fs: {
  new_buffer: (capacity: number) -> Buffer,
  open: (path: string) -> File,
  read_file: (path: string) -> string,
  read_file_bytes: (path: string) -> { number },
  write_file: (path: string, contents: string | { number } | { any }) -> (),
  get_metadata: (path: string) -> FileMetadata,
  read_dir: (path: string) -> { DirEntry },
  get_current_dir: () -> string,
  get_separator: () -> string,
  get_script_path: () -> string,
  change_dir: (path: string) -> (),
  exists: (path: string) -> boolean,
  create_dir: (path: string) -> (),
  create_dir_all: (path: string) -> (),
  remove: (path: string) -> (),
  remove_dir: (path: string) -> (),
  remove_dir_all: (path: string) -> (),
} = {}

fs.new_buffer = function(capacity: number): Buffer
  return astra_internal__new_buffer(capacity)
end

fs.open = function(path: string): File
  return astra_internal__open_file(path)
end

fs.read_file = function(path: string): string
  return astra_internal__read_file_string(path)
end

fs.read_file_bytes = function(path: string): { number }
  return astra_internal__read_file_bytes(path)
end

fs.write_file = function(path: string, contents: string | { number } | { any }): ()
  return astra_internal__write_file(path, contents)
end

fs.get_metadata = function(path: string): FileMetadata
  return astra_internal__get_metadata(path)
end

fs.read_dir = function(path: string): { DirEntry }
  return astra_internal__read_dir(path)
end

fs.get_current_dir = function(): string
  return astra_internal__get_current_dir()
end

fs.get_separator = function(): string
  return astra_internal__get_separator()
end

fs.get_script_path = function(): string
  return astra_internal__get_script_path()
end

fs.change_dir = function(path: string): ()
  astra_internal__change_dir(path)
end

fs.exists = function(path: string): boolean
  return astra_internal__exists(path)
end

fs.create_dir = function(path: string): ()
  astra_internal__create_dir(path)
end

fs.create_dir_all = function(path: string): ()
  astra_internal__create_dir_all(path)
end

fs.remove = function(path: string): ()
  astra_internal__remove(path)
end

fs.remove_dir = function(path: string): ()
  astra_internal__remove_dir(path)
end

fs.remove_dir_all = function(path: string): ()
  astra_internal__remove_dir_all(path)
end

return fs
