---@meta

---@class Astra
Astra = {
	version = "@ASTRA_VERSION",
}

ASTRA_INTERNAL__CURRENT_SCRIPT = ""

--[[
    All of the smaller scale components that are not big enough to need their own files, are here
]]

---Pretty prints any table or value
---@param value any
function pprint(value)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__pretty_print(value)
end

---Invalidates imported module cache
---
---Modules are cached upon importing at Astra, you can use this
---function to remove those caches
---@param path string
function invalidate_cache(path)
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
function spawn_task(callback)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_task(callback)
end

---Starts a new async task with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
function spawn_timeout(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_timeout(callback, timeout)
end

---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
---@param callback fun() The callback to run the content of the async task
---@param timeout number The delay in milliseconds
---@return TaskHandler
function spawn_interval(callback, timeout)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_interval(callback, timeout)
end

---Splits a sentence into an array given the separator
---@param input_str string The input string
---@param separator_str string The input string
---@return table array
---@nodiscard
function string.split(input_str, separator_str)
	local result_table = {}
	for word in input_str:gmatch("([^" .. separator_str .. "]+)") do
		table.insert(result_table, word)
	end
	return result_table
end

---Load your own file into env
---@param file_path string
function dotenv_load(file_path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__dotenv_load(file_path)
end

dotenv_load(".env")
dotenv_load(".env.production")
dotenv_load(".env.prod")
dotenv_load(".env.development")
dotenv_load(".env.dev")
dotenv_load(".env.test")
dotenv_load(".env.local")

---@class Regex
---@field captures fun(regex: Regex, content: string): string[][]
---@field replace fun(regex: Regex, content: string, replacement: string, limit: number?): string
---@field is_match fun(regex: Regex, content: string): boolean

---@param expression string
---@return Regex
function regex(expression)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__regex(expression)
end

---@param key string
function os.getenv(key)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__getenv(key)
end

---Sets the environment variable.
---
---NOT SAFE WHEN USED IN MULTITHREADING ENVIRONMENT
---@param key string
---@param value string
function os.setenv(key, value)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__setenv(key, value)
end
