--!strict

type ObservableFunctionType = (data: any) -> ()

type Observable = {
  value: any,
  observers: { ObservableFunctionType },
  subscribe: (self: Observable, observer: ObservableFunctionType) -> (),
  unsubscribe: (self: Observable, observer: ObservableFunctionType) -> (),
  publish: (self: Observable, data: any) -> (),
}

local function observable(val: any): Observable
  local new_observable: Observable = {
    value = val,
    observers = {},
    subscribe = function(self: Observable, observer: ObservableFunctionType): ()
      table.insert(self.observers, observer)
    end,
    unsubscribe = function(self: Observable, observer: ObservableFunctionType): ()
      for i, obs in ipairs(self.observers) do
        if obs == observer then
          table.remove(self.observers, i)
          break
        end
      end
    end,
    publish = function(self: Observable, data: any): ()
      for _, observer in ipairs(self.observers) do
        observer(data)
      end
    end,
  }

  return new_observable
end

type Subscriber = (data: any, topic: string) -> ()

local topics: { string: { Subscriber } } = {}

local PubSub: {
  subscribe: (topic: string, callback: Subscriber) -> (),
  unsubscribe: (topic: string, callback: Subscriber?) -> (),
  publish: (topic: string, data: any) -> (),
} = {
  subscribe = function(topic: string, callback: Subscriber): ()
    if not topics[topic] then
      topics[topic] = {}
    end
    table.insert(topics[topic], callback)
  end,
  unsubscribe = function(topic: string, callback: Subscriber?): ()
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
  end,
  publish = function(topic: string, data: any): ()
    if not topics[topic] then
      return
    end
    local subs: { Subscriber } = {}
    for _, cb in ipairs(topics[topic]) do
      table.insert(subs, cb)
    end
    for _, callback in ipairs(subs) do
      callback(data, topic)
    end
  end,
}

return {
  observable = observable,
  pubsub = PubSub,
}
