---@meta

---@class Astra
Astra = {
    version = "@ASTRA_VERSION",
}

ASTRA_INTERNAL__CURRENT_SCRIPT = ""

---Pretty prints any table or value
---@param value any
function pprint(value)
	---@diagnostic disable-next-line: undefined-global
	astra_internal__pretty_print(value)
end

---Represents an async task
---@class TaskHandler
---@field abort fun() Aborts the running task
---@field await fun() Waits for the task to finish

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
function Astra.dotenv_load(file_path)
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__dotenv_load(file_path)
end

Astra.dotenv_load(".env")
Astra.dotenv_load(".env.production")
Astra.dotenv_load(".env.prod")
Astra.dotenv_load(".env.development")
Astra.dotenv_load(".env.dev")
Astra.dotenv_load(".env.test")
Astra.dotenv_load(".env.local")
