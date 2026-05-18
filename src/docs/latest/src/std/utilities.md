# Utilities

These are some of the smaller utilities and functionality that are usually globally available regardless of the `Astra` namespace:

## Dotenv

It is always a good idea to never include sensitive API keys within your server code. For these reasons we usually recommend using a `.env` file. Astra automatically loads them if they are present in the same folder into the environment, accessible through the `os.getenv`. You can also load your own file using the global `dotenv_load` function.

This is the load order of these files (They can overwrite the ones loaded previously):

- `.env`
- `.env.production`
- `.env.prod`
- `.env.development`
- `.env.dev`
- `.env.test`
- `.env.local`

## Regex

Astra has support for a very performant regex engine. The regex code is advised to be compiled once and reused multiple times to save up even more on performence. Example:

```lua
-- Create a new regex
local my_re = regex([[(?:index)?\.(html|jinja)$]])

-- Capture all of the hits as list of string lists (string[][])
print(my_re:captures([[
path/to/file.html
examples/templates/index.html
src/components/base.jinja
]]))

-- Check for matches available
print(my_re:is_match("static/index.jinja"))

-- Or replace matches
local content = "examples/templates/index.html"
local to_replace_with = ""
local number_of_replaces = 1 -- can omit it and not add it at all as argument
local new_string = my_re:replace(content, to_replace_with, number_of_replaces)
print(new_string)
```

## Graceful Shutdowns

In Astra, you can run a piece of code when the runtime receives SIGTERM or SIGINT signals. This can be helpful for cases of cleanups or closing database connections. To add this code, you simply need to assign a function to the `ASTRA_SHUTDOWN_CODE` global variable. Make sure to have it as a global variable and not a local.

```lua
ASTRA_SHUTDOWN_CODE = function ()
    print("EXITING!!!")
end
```

## Async Tasks

The `spawn_task` function spawns a new Async Task internally within Astra. An async task is a non-blocking block of code that runs until completion without affecting the rest of the software's control flow. Internally Astra runs these tasks as [Tokio](https://tokio.rs/tokio/tutorial/spawning#tasks) tasks which are asynchronous green threads. There are no return values as they are not awaited until completion nor joined. The tasks accept a callback function that will be run.

These are useful for when you do not wish to wait for something to be completed, such as making an HTTP request to an API that may or may not fail but you do not want to make sure of either. For example, telemetry or marketing APIs where it can have delays because of volume.

An example of async task:

```lua
local utils = require("utils")

utils.spawn_task(function ()
    print("RUNNING ON ASYNC GREENTHREAD")
end)

print("RUNNING ON MAIN SYNC THREAD")
```

The tasks return a `TaskHandler` as well which has a single method: `abort`. This will kill the running task, even if it isn't finished.

Additionally two more task types are also available:

```lua
-- Runs in a loop with a delay
local task_id = utils.spawn_interval(function ()
    print("I AM LOOPING");
end, 2000)

-- Runs once after the given delay in milliseconds
utils.spawn_timeout(function ()
    print("I AM RUNNING ONLY ONCE.")
    print("Time to abort the interval above")
    -- cancel the interval task
    task_id:abort()
end, 5000)
```

> **Note:**
> The interval code runs immediately and then the delay happens before the loop starts again. In contrast the timeout's delay happen first before the code runs.
