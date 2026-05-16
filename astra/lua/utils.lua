---@meta

--[[
    All of the smaller scale components that are not big enough to need their own files, are here
]]

---@return string
local function uuid()
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__uuid()
end

---Modules are cached upon importing at Astra, you can use this
---function to remove those caches
---@param path string
local function clean_require(path)
  ---@diagnostic disable-next-line: undefined-global
  astra_internal__invalidate_cache(path)
end

---Represents an async task
---@class TaskHandler
---@field abort fun(self: TaskHandler) Aborts the running task
---@field await fun(self: TaskHandler) Waits for the task to finish

---Starts a new async task
---@param callback fun() The callback to run the content of the async task
---@return TaskHandler
local function spawn_task(callback)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__spawn_task(callback)
end

---Starts a new async task with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
local function spawn_timeout(callback, timeout)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__spawn_timeout(callback, timeout)
end

---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
local function spawn_interval(callback, timeout)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__spawn_interval(callback, timeout)
end

---Load your own file into env
---@param file_path string
function dotenv_load(file_path)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__dotenv_load(file_path)
end

---@param key string
local function env_get(key)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__getenv(key)
end

---Sets the environment variable.
---
---NOT SAFE WHEN USED IN MULTITHREADING ENVIRONMENT
---@param key string
---@param value string
local function env_set(key, value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__setenv(key, value)
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
    set = env_set,
  },
}
