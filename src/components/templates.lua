---@meta

---@class TemplateEngine
local TemplateEngine = {}

---@param name string
---@param template string
function TemplateEngine:add_template(name, template) end

---@param name string
---@param path string
function TemplateEngine:add_template_file(name, path) end

---@return string[]
function TemplateEngine:get_template_names() end

---Excludes template files from being added to the server for rendering
---@param names string[]
function TemplateEngine:exclude_templates(names) end

---Refreshes the template code from the glob given at the start
function TemplateEngine:reload_templates() end

---@param name string
---@param fun template_function
---@return any
function TemplateEngine:add_function(name, fun) end

---Renders the given template into a string with the available context
---@param name string
---@param context? table
---@return string
function TemplateEngine:render(name, context) end

---@param server HTTPServer
---@param context? table
function TemplateEngine:add_to_server(server, context) end

---Adds the templates to the server in debugging manner, where the content refreshes on each request
---@param server HTTPServer
---@param context? table
function TemplateEngine:add_to_server_debug(server, context) end

---@alias template_function fun(args: table): any

---Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
---@return TemplateEngine
---@nodiscard
function Astra.new_templating_engine(dir) end
