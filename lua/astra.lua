---@diagnostic disable: duplicate-set-field

require "./libs/utils.lua"
require "./libs/json.lua"

_G.Astra = {}

Astra.get_request = function(path, callback)
    table.insert(_G.Astra, { path = path, method = "get", func = callback })
end

Astra.post_request = function(path, callback)
    table.insert(_G.Astra, { path = path, method = "post", func = callback })
end

Astra.put_request = function(path, callback)
    table.insert(_G.Astra, { path = path, method = "put", func = callback })
end

Astra.delete_request = function(path, callback)
    table.insert(_G.Astra, { path = path, method = "delete", func = callback })
end
