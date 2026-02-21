---@meta

--- Jinja2 templating engine
---@class Jinja2Engine
---@field add_template fun(templates: Jinja2Engine, name: string, template: string)
---@field add_template_file fun(templates: Jinja2Engine, name: string, path: string)
---@field get_template_names fun(template: Jinja2Engine): string[]
---Excludes template files from being added to the server for rendering
---@field exclude_templates fun(templates: Jinja2Engine, names: string[])
---@field reload_templates fun(templates: Jinja2Engine) Refreshes the template code from the glob given at the start
---@field add_function fun(templates: Jinja2Engine, name: string, function: template_function): any Add a function to the templates
---Renders the given template into a string with the available context
---@field render fun(templates: Jinja2Engine, name: string, context?: table): string
---@field add_to_server fun(templates: Jinja2Engine, server: HTTPServer, context?: table) Adds the templates to the server
---Adds the templates to the server in debugging manner, where the content refreshes on each request
---@field add_to_server_debug fun(templates: Jinja2Engine, server: HTTPServer, context?: table)

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias template_function fun(args: table): any

--- Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
---@return Jinja2Engine
---@nodiscard
local function new_engine(dir)
  ---@type Jinja2Engine
  ---@diagnostic disable-next-line: undefined-global
  local engine = astra_internal__new_templating_engine(dir)
  ---@type Jinja2Engine
  ---@diagnostic disable-next-line: missing-fields
  local Jinja2EngineWrapper = { engine = engine }
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

  function Jinja2EngineWrapper:add_to_server(server, context)
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

  function Jinja2EngineWrapper:add_to_server_debug(server, context)
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
    Jinja2EngineWrapper[method] = function(self, ...)
      return self.engine[method](self.engine, ...)
    end
  end

  return Jinja2EngineWrapper
end

---@param input string
---@return string
local function markdown_ast(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__new_markdown_ast(input)
end

---@param input string
---@return table
local function markdown_html(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__new_markdown_html(input)
end

return {
  jinja2 = { new = new_engine },
  markdown = {
    to_ast = markdown_ast,
    to_html = markdown_html,
  },
}
