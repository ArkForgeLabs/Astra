local m = {}

Astra.http.middleware = m

--- `on Entry:`
--- Description
--- 
--- `on Leave:`
--- Description
---
--- `Depends on:`
--- List of middlewares which must be chained before me
local function middleware_template(next_handler)
    --[[
    next_handler is a function which represents a middleware or a handler
    
    each middleware must accept 3 arguments and pass those to the next_handler
    ]]
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    ---@param ctx { key_inserted_by_middleware_I_depend_on: string }
    return function(request, response, ctx)
        -- Pre-handler logic
        if "something wrong" then
            return "Waaait a minute."
        end
        local result = next_handler(request, response, ctx)
        -- Post-handler logic
        if "you came up with a use case" then
            local things = "Do some on-Leave logic"
        end
        return result
    end
end


--- `on Entry:`
--- Creates a new `ctx` table and passes it as a third argument into the `next_handler`
--- 
--- `on Leave:`
function m.context(next_handler)
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    return function(request, response)
        local ctx = {}
        return next_handler(request, response, ctx)
    end
end

--- `on Entry:`
--- Logs request method and uri into standard io via `print`
--- 
--- `on Leave:`
function m.logger(next_handler)
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    ---@param ctx table
    return function(request, response, ctx)
        print("Request:", request:method(), request:uri())
        return next_handler(request, response, ctx)
    end
end


--- `on Entry:`
---
--- `on Leave:`
--- sets `"Content-Type": "text/html"` response header
function m.html(next_handler)
    ---@param request HTTPServerRequest
    ---@param response HTTPServerResponse
    return function(request, response, ctx)
        response:set_header("Content-Type", "text/html")
        return next_handler(request, response, ctx)
    end
end

--- Chains middlewares together in order
---@param chain table A list of middlewares
---@return function middleware Composed middleware
---
--- Functionally
--- ```lua
--- chain {context, html, logger} (handler)
--- ```
--- equals to
--- ```lua
--- context(html(logger(handler)))
--- ```
--- 
--- and
--- ```lua
--- chain {context, html, logger}
--- ```
--- equals to
--- ```lua
--- function(next_handler) 
---     return function(request, response, ctx)
---         context(html(logger(next_handler(request, response, ctx)))) 
---     end
--- end
--- ```
function m.chain(chain)
    return function(handler)
        assert(type(handler) == "function",
            "Handler must be a function, got " .. type(handler))
        assert(#chain >= 2, "Chain must have at least 2 middlewares")
        for i = #chain, 1, -1 do
            local middleware = chain[i]
            assert(type(middleware) == "function",
                "Middleware must be a function, got " .. type(middleware))
            handler = middleware(handler)
        end
        return handler
    end
end