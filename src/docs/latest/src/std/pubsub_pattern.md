# Publisher/Subscriber Pattern

The Pub/Sub pattern in Astra is similar to the [observer pattern](./observer_pattern.md) in terms of core functionality, but it differs in terms of publisher & subscriber management. A pubsub store is a global store. It can have multiple functions subcribed to an observable object, and multiple of these observable objects organized into topics, which are simply string keywords.

You must remember that the rules of operating on pubsub stores is the same as that for the observer pattern, but pubsub stores are much more powerful and flexible.

```lua
local stores = require("astra.lua.stores")

-- Let's create a few tables as examples for observable objects
local user1 = {
 name = "John Doe",
 email = "johndoe@example.com",
}

local user2 = {
 name = "Jane Doe",
 email = "janedoe@example.com",
}

-- We're going to subscribe functions to both user objects
-- The first parameter is the topic, for which we will use "user:update"
-- Then we pass in the observable object we want to subscribe to
-- Finally we pass in the function that'll subscribe to the aforementioned observable
stores.pubsub.subscribe("user:update", user1, function(user)
 print("User1 updated:", user.name, user.email)
end)

stores.pubsub.subscribe("user:update", user2, function(user)
 print("User2 updated:", user.name, user.email)
end)

-- Publish updates to the "user_update" topic
user1.name = "John Doe Jr."
stores.pubsub.publish("user:update", user1)

-- While unsubscribing a function, if the function isn't stored as a variable, you must match it exactly
-- The parameters required while unsubscribing are exactly the same as while subscribing.
stores.pubsub.unsubscribe("user:update", user1, function(user)
 print("User1 updated:", user.name, user.email)
end)

user2.email = "jane.doe@company.com"
stores.pubsub.publish("user:update", user2)
```

You should get an output like this:

```txt
User1 updated:  John Doe Jr.    johndoe@example.com
User2 updated:  Jane Doe        janedoe@example.com
User2 updated:  Jane Doe        jane.doe@company.com
```

Now that you're familiar with how the pubsub system works, keep in mind that if you wish to add other observables under different topics, it's all going to work exactly the same, but with an added sense of dimension.
