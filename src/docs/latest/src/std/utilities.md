# Utilities

These are some of the smaller utilities and functionality that are usually globally available regardless of the `Astra` namespace:

## Pretty Print

`pprint` function is a wrapper over `print` function that also lets you print tables as well as other values.

## String Split

`string.split` splits a string according to the seperator provided and result into an array of chunks.

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
local my_re = regex([[(?:index)?\.(html|lua|tera)$]])

-- Capture all of the hits as list of string lists (string[][])
pprint(my_re:captures([[
path/to/file.html
examples/templates/index.html
src/components/base.tera
]]))

-- Check for matches available
pprint(my_re:is_match("static/index.lua"))

-- Or replace matches
local content = "examples/templates/index.html"
local to_replace_with = ""
local number_of_replaces = 1 -- can omit it and not add it at all as argument
local new_string = my_re:replace(content, to_replace_with, number_of_replaces)
pprint(new_string)
```

## Graceful Shutdowns

In Astra, you can run a piece of code when the runtime receives SIGTERM or SIGINT signals. This can be helpful for cases of cleanups or closing database connections. To add this code, you simply need to assign a function to the `ASTRA_SHUTDOWN_CODE` global variable. Make sure to have it as a global variable and not a local.

```lua
ASTRA_SHUTDOWN_CODE = function ()
    pprint("EXITING!!!")
end
```
