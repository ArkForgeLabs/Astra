--!nocheck
--!nolint

--- Represents an async task
type TaskHandler = {
  --- Aborts the running task
  abort: (self: TaskHandler) -> (),
  --- Waits for the task to finish
  await: (self: TaskHandler) -> (),
}

--- UUID v4
local function uuid(): string
  return astra_internal__uuid()
end

--- Modules are cached upon importing at Astra, you can use this
--- function to remove those caches
local function clean_require(path: string): ()
  astra_internal__invalidate_cache(path)
end

--- Starts a new async task
local function spawn_task(callback: () -> ()): TaskHandler
  return astra_internal__spawn_task(callback)
end

--- Starts a new async task with a delay in milliseconds
local function spawn_timeout(callback: () -> (), timeout: number): TaskHandler
  return astra_internal__spawn_timeout(callback, timeout)
end

--- Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
local function spawn_interval(callback: () -> (), timeout: number): TaskHandler
  return astra_internal__spawn_interval(callback, timeout)
end

--- Load your own file into env
local function dotenv_load(file_path: string): ()
  astra_internal__dotenv_load(file_path)
end

--- Fetches an environment variable
local function env_get(key: string): ()
  astra_internal__getenv(key)
end

--- Sets the environment variable.
---
--- NOT SAFE WHEN USED IN MULTITHREADING ENVIRONMENT
local function env_set(key: string, value: string): ()
  astra_internal__setenv(key, value)
end

return {
  uuid = uuid,
  clean_require = clean_require,
  spawn_task = spawn_task,
  spawn_timeout = spawn_timeout,
  spawn_interval = spawn_interval,
  dotenv_load = dotenv_load,
  env = {
    get = env_get,
    set = env_set
  }
}
