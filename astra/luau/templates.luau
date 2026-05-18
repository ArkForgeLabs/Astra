--!nocheck
--!nolint

--- Jinja2 templating engine
type Jinja2Engine = {
  add_template: (templates: Jinja2Engine, name: string, template: string) -> (),
  add_template_file: (templates: Jinja2Engine, name: string, path: string) -> (),
  get_template_names: (template: Jinja2Engine) -> { string },
  --- Excludes template files from being added to the server for rendering
  exclude_templates: (templates: Jinja2Engine, names: { string }) -> (),
  --- Refreshes the template code from the glob given at the start
  reload_templates: (templates: Jinja2Engine) -> (),
  --- Add a function to the templates
  add_function: (templates: Jinja2Engine, name: string, func: (args: { any }) -> any) -> any,
  --- Renders the given template into a string with the available context
  render: (templates: Jinja2Engine, name: string, context: { any }?) -> string,
  --- Adds the templates to the server
  add_to_server: (templates: Jinja2Engine, server: HTTPServer, context: { any }?) -> (),
  --- Adds the templates to the server in debugging manner, where the content refreshes on each request
  add_to_server_debug: (templates: Jinja2Engine, server: HTTPServer, context: { any }?) -> (),
  debug_watch: (_: Jinja2Engine, server: HTTPServer, dir_path: string) -> (),
  context_add: (templates: Jinja2Engine, ...any) -> (),
  context_remove: (templates: Jinja2Engine, ...any) -> (),
  context_get: (templates: Jinja2Engine, ...any) -> (),
}

--- Returns a new templating engine
--- @param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
local function new_engine(dir: string?): Jinja2Engine
  local engine: Jinja2Engine = astra_internal__new_templating_engine(dir)
  local Jinja2EngineWrapper: Jinja2Engine = { engine = engine }
  local templates_re = require("validation").regex("(?:index)?%.(html|lua)$")

  local function normalize_paths(path: string): { string }
    if path:sub(1, 1) ~= "/" then
      path = "/" .. path
    end
    if path == "/" then
      return { "/" }
    end
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

  function Jinja2EngineWrapper:debug_watch(server: HTTPServer, dir_path: string)
    local serde = require("serde")
    local fs = require("fs")

    local files = {}
    --- @param path string the directory to watch
    local function read_recursive(path: string)
      for _, i in ipairs(fs.read_dir(path)) do
        if i:file_type():is_file() then
          pcall(function()
            local file_details = fs.get_metadata(i:path())
            table.insert(files, { i:path(), file_details:last_modified() })
          end)
        elseif i:file_type():is_dir() then
          read_recursive(i:path())
        end
      end
    end

    local did_change = false
    spawn_interval(function()
      local old_files = serde.json.encode(files)
      files = {}
      read_recursive(dir_path)
      did_change = old_files ~= serde.json.encode(files)
    end, 500)

    server:get("/debug.js", function(_: HTTPServerRequest, response: HTTPServerResponse)
      response:set_header("Content-Type", "text/javascript")
      return [[setInterval(async ()=>{const response=await fetch("/debug");if(response.ok &&(await response.text())=="true"){window.location.reload();}},100);]]
    end)
    server:get("/debug", function(): string
      return tostring(did_change)
    end)
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
