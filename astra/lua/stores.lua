---@meta

--MARK: Observable
---@alias observable_function_type fun(data: any)

---@class Observable
---@field value any
---@field observers observable_function_type[]
---@field subscribe fun(self: Observable, observer: observable_function_type)
---@field unsubscribe fun(self: Observable, observer: observable_function_type)
---@field publish fun(self: Observable, data: any)

---@param val any
---@return Observable
local function observable(val)
  ---@type Observable
  local new_observable = {
    value = val,
    observers = {},
    subscribe = function(self, observer)
      table.insert(self.observers, observer)
    end,
    unsubscribe = function(self, observer)
      for i, obs in ipairs(self.observers) do
        if obs == observer then
          table.remove(self.observers, i)
          break
        end
      end
    end,
    publish = function(self, data)
      for _, observer in ipairs(self.observers) do
        observer(data)
      end
    end,
  }

  return new_observable
end

--MARK: PubSub

---@class PubSub
local PubSub = {}

---@alias Subscriber fun(data: any, topic: string)

---@type table<string, Subscriber[]>
local topics = {}

--- Subscribe a callback to a topic.
---@param topic string
---@param callback Subscriber
function PubSub.subscribe(topic, callback)
  if not topics[topic] then
    topics[topic] = {}
  end
  table.insert(topics[topic], callback)
end

--- Unsubscribe a callback from a topic.
---@param topic string
---@param callback? Subscriber # Optional: if not provided, removes the last subscriber
function PubSub.unsubscribe(topic, callback)
  if not topics[topic] then
    return
  end
  if callback then
    for i, cb in ipairs(topics[topic]) do
      if cb == callback then
        table.remove(topics[topic], i)
        break
      end
    end
  else
    -- If no callback is provided, remove the last subscriber
    table.remove(topics[topic])
  end
end

--- Publish data to a topic.
---@param topic string
---@param data any
function PubSub.publish(topic, data)
  if not topics[topic] then
    return
  end
  -- Iterate over a copy of the subscribers to avoid issues if a callback modifies the list
  local subs = {}
  for _, cb in ipairs(topics[topic]) do
    table.insert(subs, cb)
  end
  for _, callback in ipairs(subs) do
    callback(data, topic)
  end
end

return {
  observable = observable,
  pubsub = PubSub,
}
