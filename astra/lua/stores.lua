---@meta

--MARK: Observable

---An observable object that wraps around the provided data
---@param val any
---@return table
local observable = function(val)
	local new_observable = {
		---The original value to be observed
		value = val,
		observers = {},
	}

	---Subscribe to an observable object with a callback function
	---@param observer function
	function new_observable:subscribe(observer)
		if not self.observers[observer] then
			self.observers[observer] = true
		end
	end

	---Unsubscribe a callback function from an observable object
	---@param observer function
	function new_observable:unsubscribe(observer)
		self.observers[observer] = nil
	end

	---Publish the provided data to all subcribers
	---@param data function | any
	function new_observable:publish(data)
		for k, _ in pairs(self.observers) do
			k(data)
		end
	end

	return new_observable
end

--MARK: PubSub

local subscriptions = {}
local subcounter = {}

local pubsub = {}

---
---@param topic string
---@param observable any
---@param callback function
pubsub.subscribe = function(topic, observable, callback)
	if not subscriptions[topic] then
		subscriptions[topic] = {}
		subcounter[topic] = {}
	end

	if not subscriptions[topic][observable] then
		subscriptions[topic][observable] = {}

		subcounter[topic][observable] = {
			num_subs = 0,
		}
	end

	if not subscriptions[topic][observable][callback] then
		subscriptions[topic][observable][callback] = true
		subcounter[topic][observable].num_subs = subcounter[topic][observable].num_subs + 1
	end
end

---
---@param topic string
---@param observable any
---@param callback function
pubsub.unsubscribe = function(topic, observable, callback)
	subscriptions[topic][observable][callback] = nil
	subcounter[topic][observable].num_subs = subcounter[topic][observable].num_subs - 1

	if subcounter[topic][observable].num_subs < 1 then
		subscriptions[topic][observable] = nil
		subcounter[topic][observable] = nil
	end
end

---
---@param topic string
---@param data function | any
pubsub.publish = function(topic, data)
	for observable, kv in pairs(subscriptions[topic]) do
		for k, _ in pairs(kv) do
			k(observable, data)
		end
	end
end

return {
	observable = observable,
	pubsub = pubsub
}
