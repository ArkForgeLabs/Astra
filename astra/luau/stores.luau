--!nocheck
--!nolint

type Observable = {
  value: any,
  observers: { (data: any) -> () },
  subscribe: (self: Observable, observer: (data: any) -> ()) -> (),
  unsubscribe: (self: Observable, observer: (data: any) -> ()) -> (),
  publish: (self: Observable, data: any) -> (),
}

--- @param val any
local function observable(val: any): Observable
  local new_observable: Observable = {
    value = val,
    observers = {},
    subscribe = function(self: Observable, observer: (data: any) -> ())
      table.insert(self.observers, observer)
    end,
    unsubscribe = function(self: Observable, observer: (data: any) -> ())
      for i, obs in ipairs(self.observers) do
        if obs == observer then
          table.remove(self.observers, i)
          break
        end
      end
    end,
    publish = function(self: Observable, data: any)
      for _, observer in ipairs(self.observers) do
        observer(data)
      end
    end,
  }

  return new_observable
end

local topics: { string: { (data: any, topic: string) -> () } } = {}

local PubSub = {}

--- Subscribe a callback to a topic.
function PubSub.subscribe(topic: string, callback: (data: any, topic: string) -> ())
  if not topics[topic] then
    topics[topic] = {}
  end
  table.insert(topics[topic], callback)
end

--- Unsubscribe a callback from a topic.
--- @param callback? function # Optional: if not provided, removes the last subscriber
function PubSub.unsubscribe(topic: string, callback: ((data: any, topic: string) -> ())?)
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
    table.remove(topics[topic])
  end
end

--- Publish data to a topic.
function PubSub.publish(topic: string, data: any)
  if not topics[topic] then
    return
  end
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
