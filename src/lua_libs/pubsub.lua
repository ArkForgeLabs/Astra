---@meta

local subscriptions = {}

Astra.pubsub = {}

---
---@param topic string
---@param observer any
---@param callback function
Astra.pubsub.subscribe = function(topic, observer, callback)
	if not subscriptions[topic] then
		subscriptions[topic] = {}
	end

	-- Subscriber table
	table.insert(subscriptions[topic], {
		obs = observer,
		cbk = callback,
	})
end

---
---@param topic string
---@param observer any
---@param callback function
Astra.pubsub.unsubscribe = function(topic, observer, callback)
	for i = #subscriptions[topic], 1, -1 do
		local sub = subscriptions[topic][i]

		if sub.obs == observer and sub.cbk == callback then
			table.remove(subscriptions[topic], i)
		end
	end
end

---
---@param topic string
---@param data any
Astra.pubsub.publish = function(topic, data)
	for i = 1, #subscriptions[topic] do
		subscriptions[topic][i].cbk(subscriptions[topic][i].obs, data)
	end
end
