# Observer Pattern

Astra provides you with an observable object which can have functions subcribe and unsubscribe to it, to which you can publish a desired data payload.

```lua
-- You can can construct an observable object as shown below:
-- Replace `0` with whatever data you'd like
local counter = Astra.observable(0)

-- Let's create a function which will subscribe to `counter`
local function simply_notify()
	print("The count has been updated!")
end

-- You can use counter.value to access the data wrapped inside a counter
local function detailed_notify()
	print("The count now is " .. counter.value)
end

counter:subscribe(simply_notify)
counter:subscribe(detailed_notify)
```

When a function that can modify the underlying data of the observable object subscribes to it and is ran with the default (luajit) backend, the execution order of the subscribers can't be predicted, which is fine for most functions, but dangerous/undesirable when you want to change the underlying data. We want to avoid this unpredictability **always**. We can mutate our observable object safely by passing a function which wraps around our observable object that'll execute any logic we program as an argument to the publish function, or we can mutate it in the preceding line, then pass any data we need to the `publish()` method.

```lua
local function add_to_counter(data)
	counter.value = counter.value + data
end

-- We pass a function that 
counter:publish(add_to_counter(5))

-- Just some spacing
print("")

counter:publish(add_to_counter(4))
```

This code will result in the following output:

```
The count has been updated!
The count now is 5

The count has been updated!
The count now is 9
```

We can also make these "closure functions" return a value that can be passed as data which a subscriber function can describe what to do with. Let's go back and change our `detailed_notify()` and `add_to_counter()` functions.

```lua
local function detailed_notify(data)
	print("The count now is " .. counter.value)

	if type(data) == "number" then
		print("The count was increased by " .. data)
	end
end
```

```lua
local function add_to_counter(num)
	counter.value = counter.value + num

	return num
end
```

This gives us the following output:

```
The count has been updated!
The count now is 5
The count was increased by 5

The count has been updated!
The count now is 9
The count was increased by 4
```

When you're done with a subscriber and don't want it to be called anymore, you can simply unsubscribe it. Let's unsubscribe to the `simple_notify()` function after our first `publish()` call.

```lua
...

-- You can publish any type of data to the counter, and all subscribers will be notified about it
counter:publish(add_to_counter(5))

-- Just some spacing
print("")

counter:unsubscribe(simply_notify)
counter:publish(add_to_counter(4))
```

After running the script, you will see that the print statement from the unsubscribed function is gone.

```
The count has been updated!
The count now is 5
The count was increased by 5

The count now is 9
The count was increased by 4
```

In total, our example script should look like this:

```lua
-- You can can construct an observable object as shown below:
-- Replace `0` with whatever data you'd like
local counter = Astra.observable(0)

local function simply_notify()
	print("The count has been updated!")
end

local function detailed_notify(data)
	print("The count now is " .. counter.value)

	if type(data) == "number" then
		print("The count was increased by " .. data)
	end
end

counter:subscribe(simply_notify)
counter:subscribe(detailed_notify)

local function add_to_counter(num)
	counter.value = counter.value + num

	return num
end

-- You can publish any type of data to the counter, and all subscribers will be notified about it
counter:publish(add_to_counter(5))

-- Just some spacing
print("")

counter:unsubscribe(simply_notify)
counter:publish(add_to_counter(4))
```
