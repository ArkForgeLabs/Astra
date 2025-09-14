--MARK: Observable

local type observable_function_type = function(any)
global record Observable
	value: any
	observers: {observable_function_type}
	---Subscribe to an observable object with a callback function
	subscribe: function(self: Observable, observer: observable_function_type)
	---Unsubscribe a callback function from an observable object
	unsubscribe: function(self: Observable, observer: observable_function_type)
	---Publish the provided data to all subcribers
	publish: function(self: Observable, data: observable_function_type | any)
end

---An observable object that wraps around the provided data
local observable = function(val: any): Observable
	local new_observable: Observable = {
		---The original value to be observed
		value = val,
		observers: {observable_function_type} = {},
	}
	function new_observable:subscribe(observer: observable_function_type)
		table.insert(self.observers, observer)
	end
	function new_observable:unsubscribe(observer: observable_function_type)
		for i, obs in ipairs(self.observers) do
			if obs == observer then
				table.remove(self.observers, i)
				break
			end
		end
	end
	function new_observable:publish(data: observable_function_type | any)
		for _, k in ipairs(self.observers) do
			k(data)
		end
	end

	return new_observable
end

--MARK: PubSub

local PubSub = {}

-- Type definitions
global type Subscriber = function(data: any, topic: string)
global type TopicMap = { string: { Subscriber } }

-- Global table to hold topics and subscribers
local topics: TopicMap = {}

--- Subscribe a callback to a topic.
---@param topic string
---@param callback Subscriber
function PubSub.subscribe(topic: string, callback: Subscriber)
    if not topics[topic] then
        topics[topic] = {}
    end
    table.insert(topics[topic], callback)
end

--- Unsubscribe a callback from a topic.
---@param topic string
---@param callback Subscriber
function PubSub.unsubscribe(topic: string)
    if not topics[topic] then
        return
    end
    for i, _ in ipairs(topics[topic]) do
		table.remove(topics[topic], i)
		break
    end
end

--- Publish data to a topic.
---@param topic string
---@param data any
function PubSub.publish(topic: string, data: any)
    if not topics[topic] then
        return
    end
    spawn_task(function()
		for _, callback in ipairs(topics[topic]) do
			spawn_task(function() callback(data, topic) end)
		end
	end)
end

return {
	observable = observable,
	pubsub = PubSub
}
