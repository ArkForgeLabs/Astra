--!strict

type Astra = {
  version: string,
  current_script: string,
  main_script: string,
}

local Astra: Astra = {
  version = "@ASTRA_VERSION",
  current_script = "",
  main_script = "",
}

@deprecated
local CURRENT_SCRIPT: string = ""
@deprecated
local MAIN_SCRIPT: string = ""

type TaskHandler = {
  abort: (self: TaskHandler) -> (),
  await: (self: TaskHandler) -> (),
}

local astra_internal__pretty_print: (...: any) -> ()
local astra_internal__uuid: () -> string
local astra_internal__invalidate_cache: (path: string) -> ()
local astra_internal__spawn_task: (callback: () -> ()) -> TaskHandler
local astra_internal__spawn_timeout: (callback: () -> (), timeout: number) -> TaskHandler
local astra_internal__spawn_interval: (callback: () -> (), timeout: number) -> TaskHandler
local astra_internal__dotenv_load: (file_path: string) -> ()
local astra_internal__getenv: (key: string) -> string?
local astra_internal__setenv: (key: string, value: string) -> ()

@nodiscard
function pprint(...: any): ()
  astra_internal__pretty_print(...)
end

@nodiscard
function uuid(): string
  return astra_internal__uuid()
end

@deprecated
function invalidate_cache(path: string): ()
  astra_internal__invalidate_cache(path)
end

function clean_require(path: string): ()
  astra_internal__invalidate_cache(path)
end

function spawn_task(callback: () -> ()): TaskHandler
  return astra_internal__spawn_task(callback)
end

function spawn_timeout(callback: () -> (), timeout: number): TaskHandler
  return astra_internal__spawn_timeout(callback, timeout)
end

function spawn_interval(callback: () -> (), timeout: number): TaskHandler
  return astra_internal__spawn_interval(callback, timeout)
end

@nodiscard
function string.split(input_str: string, separator_str: string): { string }
  local result_table: { string } = {}
  for word in input_str:gmatch("([^" .. separator_str .. "]+)") do
    table.insert(result_table, word)
  end
  return result_table
end

function dotenv_load(file_path: string): ()
  return astra_internal__dotenv_load(file_path)
end

dotenv_load(".env")
dotenv_load(".env.production")
dotenv_load(".env.prod")
dotenv_load(".env.development")
dotenv_load(".env.dev")
dotenv_load(".env.test")
dotenv_load(".env.local")

function os.getenv(key: string): string?
  return astra_internal__getenv(key)
end

function os.setenv(key: string, value: string): ()
  return astra_internal__setenv(key, value)
end
