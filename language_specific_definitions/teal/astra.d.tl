local type astra_internal__pretty_print = function(value: any)
---Pretty prints any table or value
global function pprint(value: any)
	astra_internal__pretty_print(value)
end

---Represents an async task
global record TaskHandler
    abord: function()
    await: function()
end

local type astra_internal__spawn_task = function(callback: function()): TaskHandler
---Starts a new async task
global function spawn_task(callback: function()): TaskHandler
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_task(callback)
end

local type astra_internal__spawn_timeout = function(callback: function(), timeout: number): TaskHandler
---Starts a new async task with a delay in milliseconds
global function spawn_timeout(callback: function(), timeout: number): TaskHandler
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_timeout(callback, timeout)
end

local type astra_internal__spawn_interval = function(callback: function(), timeout: number): TaskHandler
---Starts a new async task that runs infinitely in a loop but with a delay in milliseconds
global function spawn_interval(callback: function(), timeout: number): TaskHandler
	---@diagnostic disable-next-line: undefined-global
	return astra_internal__spawn_interval(callback, timeout)
end