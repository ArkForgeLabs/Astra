---@meta

---An observable object that wraps around the provided data
---@param val any
---@return table
Astra.observable = function(val)
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
	---@param data any
	function new_observable:publish(data)
		for k, _ in pairs(self.observers) do
			k(data)
		end
	end

	return new_observable
end
