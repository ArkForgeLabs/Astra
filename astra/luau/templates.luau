--!nocheck
--!nolint

--- Jinja2 templating engine
type Jinja2Engine = {
  add_template: (templates: Jinja2Engine, name: string, template: string) -> (),
  add_template_file: (templates: Jinja2Engine, name: string, path: string) -> (),
  get_template_names: (template: Jinja2Engine) -> { string },
  --- Fetches all the names, including the excluded templates
  get_template_names_all: (template: Jinja2Engine) -> { string },
  get_template_paths: (template: Jinja2Engine) -> { string },
  --- Fetches all the paths, including the excluded templates
  get_template_paths_all: (template: Jinja2Engine) -> { string },
  --- Excludes template files from being added to the server for rendering
  exclude_templates: (templates: Jinja2Engine, names: { string }) -> (),
  --- Refreshes the template code from the glob given at the start
  reload_templates: (templates: Jinja2Engine) -> (),
  --- Add a function to the templates
  add_function: (templates: Jinja2Engine, name: string, func: (args: { [any]: any }) -> any) -> any,
  --- Renders the given template into a string with the available context
  render: (templates: Jinja2Engine, name: string, context: { any }?) -> string,
  --- Adds the templates to the server
  add_to_server: (templates: Jinja2Engine, server: HTTPServer, context: { any }?) -> (),
  --- Adds the templates to the server in debugging manner, where the content refreshes on each request
  add_to_server_debug: (templates: Jinja2Engine, server: HTTPServer, context: { any }?) -> (),
  context_add: (templates: Jinja2Engine, ...any) -> (),
  context_remove: (templates: Jinja2Engine, ...any) -> (),
  context_get: (templates: Jinja2Engine, ...any) -> (),
}

local function debug_watch(template_names: { string }, server: HTTPServer)
  local serde = require("@astra/serde")
  local utils = require("@astra/utils")
  local fs = require("@astra/fs")

  local files = {}
  for _, value in ipairs(template_names) do
    local success, is_file = pcall(function()
      return fs.get_metadata(value):type():is_file()
    end)
    if success and is_file then
      table.insert(files, { value, 0 })
    else
      print(is_file)
    end
  end

  local function last_modified_times(paths: { string }): { string }
    local result = {}
    for _, file in ipairs(paths) do
      pcall(function()
        local file_details = fs.get_metadata(file[1])
        table.insert(result, { file[1], file_details:last_modified() })
      end)
    end
    return result
  end

  local did_change = false
  utils.spawn_interval(function()
    local old_files = serde.json.encode(files)
    files = last_modified_times(files)
    if old_files ~= serde.json.encode(files) then
      did_change = true
    else
      did_change = false
    end
  end, 500)

  server:get("/debug.js", function(_, response)
    response:set_header("Content-Type", "text/javascript")
    return [[setInterval(async ()=>{const response=await fetch("/debug");if(response.ok &&(await response.text())=="true"){window.location.reload();}},100);]]
  end)

  server:get("/debug", function()
    return tostring(did_change)
  end)
end

--- Returns a new templating engine
--- @param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
local function new_engine(dir: string?): Jinja2Engine
  local engine: Jinja2Engine = astra_internal__new_templating_engine(dir)
  local Jinja2EngineWrapper: Jinja2Engine = { engine = engine }
  local templates_re = require("@astra/validation").regex([[(?:index)?\.(html|lua)$]])

  local function normalize_paths(path: string): { string }
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

  function Jinja2EngineWrapper:add_to_server(server: HTTPServer, context: { any }?)
    local names = self.engine:get_template_names()
    for _, value in ipairs(names) do
      local path = templates_re:replace(value, "")
      local content = self.engine:render(value, context)

      for _, route in ipairs(normalize_paths(path)) do
        server:get(route, function(_: HTTPServerRequest, response: HTTPServerResponse)
          response:set_header("Content-Type", "text/html")
          return content
        end)
      end
    end
  end

  function Jinja2EngineWrapper:add_to_server_debug(server: HTTPServer, context: { any }?)
    local names = self.engine:get_template_names()
    debug_watch(self.engine:get_template_paths_all(), server)

    for _, value in ipairs(names) do
      local path = templates_re:replace(value, "")
      for _, route in ipairs(normalize_paths(path)) do
        server:get(route, function(_: HTTPServerRequest, response: HTTPServerResponse)
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
    Jinja2EngineWrapper[method] = function(self: Jinja2Engine, ...: any)
      return self.engine[method](self.engine, ...)
    end
  end

  return Jinja2EngineWrapper
end

--- @param input string
local function markdown_ast(input: string): { any }
  return astra_internal__new_markdown_ast(input)
end

--- @param input string
local function markdown_html(input: string): { any }
  return astra_internal__new_markdown_html(input)
end

return {
  jinja2 = { new = new_engine },
  markdown = {
    to_ast = markdown_ast,
    to_html = markdown_html,
  },
}
