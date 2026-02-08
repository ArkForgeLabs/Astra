---@meta

--- Jinja2 templating engine
---@class TemplateEngine
---@field add_template fun(templates: TemplateEngine, name: string, template: string)
---@field add_template_file fun(templates: TemplateEngine, name: string, path: string)
---@field get_template_names fun(template: TemplateEngine): string[]
---Excludes template files from being added to the server for rendering
---@field exclude_templates fun(templates: TemplateEngine, names: string[])
---@field reload_templates fun(templates: TemplateEngine) Refreshes the template code from the glob given at the start
---@field add_function fun(templates: TemplateEngine, name: string, function: template_function): any Add a function to the templates
---Renders the given template into a string with the available context
---@field render fun(templates: TemplateEngine, name: string, context?: table): string
---@field add_to_server fun(templates: TemplateEngine, server: HTTPServer, context?: table) Adds the templates to the server
---Adds the templates to the server in debugging manner, where the content refreshes on each request
---@field add_to_server_debug fun(templates: TemplateEngine, server: HTTPServer, context?: table)

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias template_function fun(args: table): any

--- Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
---@return TemplateEngine
---@nodiscard
local function new_engine(dir)
  ---@type TemplateEngine
  ---@diagnostic disable-next-line: undefined-global
  local engine = astra_internal__new_templating_engine(dir)
  ---@type TemplateEngine
  ---@diagnostic disable-next-line: missing-fields
  local TemplateEngineWrapper = { engine = engine }
  local templates_re = regex([[(?:index)?\.(html|lua)$]])

  local function normalize_paths(path)
    -- Ensure path starts with "/"
    if path:sub(1, 1) ~= "/" then
      path = "/" .. path
    end

    -- If empty, it's just the root
    if path == "/" then
      return { "/" }
    end

    -- Return both with and without trailing slash
    if path:sub(-1) == "/" then
      return { path, path:sub(1, -2) }
    else
      return { path, path .. "/" }
    end
  end

  function TemplateEngineWrapper:add_to_server(server, context)
    local names = self.engine:get_template_names()
    for _, value in ipairs(names) do
      local path = templates_re:replace(value, "")
      local content = self.engine:render(value, context)

      for _, route in ipairs(normalize_paths(path)) do
        server:get(route, function(_, response)
          response:set_header("Content-Type", "text/html")
          return content
        end)
      end
    end
  end

  function TemplateEngineWrapper:add_to_server_debug(server, context)
    local names = self.engine:get_template_names()
    for _, value in ipairs(names) do
      local path = templates_re:replace(value, "")

      for _, route in ipairs(normalize_paths(path)) do
        server:get(route, function(_, response)
          self.engine:reload_templates()
          response:set_header("Content-Type", "text/html")
          return self.engine:render(value, context)
        end)
      end
    end
  end

  local templating_methods = {
    "add_template",
    "add_template_file",
    "get_template_names",
    "exclude_templates",
    "reload_templates",
    "context_add",
    "context_remove",
    "context_get",
    "add_function",
    "render",
  }

  for _, method in ipairs(templating_methods) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    TemplateEngineWrapper[method] = function(self, ...)
      return self.engine[method](self.engine, ...)
    end
  end

  return TemplateEngineWrapper
end

return { new = new_engine }
