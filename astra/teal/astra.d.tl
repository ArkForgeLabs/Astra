global ASTRA_INTERNAL__CURRENT_SCRIPT = ""

local type astra_internal__pretty_print = function(...: any)
---Pretty prints any table or value
global function pprint(...: any)
	astra_internal__pretty_print(...)
end

global function pprintln(...: any)
	astra_internal__pretty_println(...)
end

global function uuid(): string
	return astra_internal__uuid()
end

local type astra_internal__invalidate_cache = function(path: string)
global function invalidate_cache(path: string)
	astra_internal__invalidate_cache(path)
end

---Represents an async task
global interface TaskHandler is userdata
    abort: function(self: TaskHandler)
    await: function(self: TaskHandler)
end

local type astra_internal__spawn_task = function(callback: function()): TaskHandler
---Starts a new async task
global function spawn_task(callback: function()): TaskHandler
	return astra_internal__spawn_task(callback)
end

local type astra_internal__spawn_timeout = function(callback: function(), timeout: number): TaskHandler
---Starts a new async task with a delay in milliseconds
global function spawn_timeout(callback: function(), timeout: number): TaskHandler
	return astra_internal__spawn_timeout(callback, timeout)
end

local type astra_internal__spawn_interval = function(callback: function(), timeout: number): TaskHandler
---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
global function spawn_interval(callback: function(), timeout: number): TaskHandler
	return astra_internal__spawn_interval(callback, timeout)
end

local type astra_internal__dotenv_load = function(file_path: string)
---Load your own file into env
global function dotenv_load(file_path: string)
	astra_internal__dotenv_load(file_path)
end

dotenv_load(".env")
dotenv_load(".env.production")
dotenv_load(".env.prod")
dotenv_load(".env.development")
dotenv_load(".env.dev")
dotenv_load(".env.test")
dotenv_load(".env.local")

global interface Regex is userdata
	captures: function(regex: Regex, content: string): {{string}}
	replace: function(regex: Regex, content: string, replacement: string, limit?: number): string
	is_match: function(regex: Regex, content: string): boolean
end

local type astra_internal__regex = function(expression: string): Regex
---@param expression string
global function regex(expression: string): Regex
	return astra_internal__regex(expression)
end
