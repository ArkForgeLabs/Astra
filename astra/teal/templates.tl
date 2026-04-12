require("http")

local type jinja2_function_type = function(args: {any:any}): any
local type jinja2_context = {any:any}

--- Jinja2 templating engine
local interface Jinja2EngineNative is userdata
	add_template: function(self: Jinja2EngineNative, name: string, template: string)
	add_template_file: function(self: Jinja2EngineNative, name: string, path: string)
	get_template_names: function(self: Jinja2EngineNative): {string}
	exclude_templates: function(self: Jinja2EngineNative, names: {string})
	reload_templates: function(self: Jinja2EngineNative)
	add_function: function(self: Jinja2EngineNative, name: string, template_function: jinja2_function_type): any
	render: function(self: Jinja2EngineNative, name: string, context?: jinja2_context): string
end

global record Jinja2Engine
	_engine: Jinja2EngineNative

	add_template: function(self: Jinja2Engine, name: string, template: string)
	add_template_file: function(self: Jinja2Engine, name: string, path: string)
	get_template_names: function(self: Jinja2Engine): {string}
	exclude_templates: function(self: Jinja2Engine, names: {string})
	reload_templates: function(self: Jinja2Engine)
	add_function: function(self: Jinja2Engine, name: string, template_function: jinja2_function_type): any
	render: function(self: Jinja2Engine, name: string, context?: jinja2_context): string
	add_to_server: function(self: Jinja2Engine, server: HTTPServer, context?: jinja2_context)
	add_to_server_debug: function(self: Jinja2Engine, server: HTTPServer, context?: jinja2_context)
end

local templates_re = regex([[(?:index)?\.(html|lua)$]])

local function normalize_paths(path: string): {string}
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

local type astra_internal__new_templating_engine = function(dir: string): Jinja2EngineNative
--- Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`
local function new_engine(dir: string): Jinja2Engine
	local engine = astra_internal__new_templating_engine(dir)
	local Jinja2EngineWrapper: Jinja2Engine = { _engine = engine }

	Jinja2EngineWrapper.add_template = function(self: Jinja2Engine, name: string, template: string)
		return self._engine:add_template(name, template)
	end
	Jinja2EngineWrapper.add_template_file = function(self: Jinja2Engine, name: string, path: string)
		return self._engine:add_template_file(name, path)
	end
	Jinja2EngineWrapper.get_template_names = function(self: Jinja2Engine): {string}
		return self._engine:get_template_names()
	end
	Jinja2EngineWrapper.exclude_templates = function(self: Jinja2Engine, names: {string})
		return self._engine:exclude_templates(names)
	end
	Jinja2EngineWrapper.reload_templates = function(self: Jinja2Engine)
		return self._engine:reload_templates()
	end
	Jinja2EngineWrapper.add_function = function(self: Jinja2Engine, name: string, template_function: jinja2_function_type): any
		return self._engine:add_function(name, template_function)
	end
	Jinja2EngineWrapper.render = function(self: Jinja2Engine, name: string, context?: jinja2_context): string
		return self._engine:render(name, context)
	end
	Jinja2EngineWrapper.add_to_server = function(self: Jinja2Engine, server: HTTPServer, context: jinja2_context)
		local names = self:get_template_names()
		for _, value in ipairs(names) do
			local path = templates_re:replace(value, "")
			local content = self._engine:render(value, context)

			for _, route in ipairs(normalize_paths(path)) do
				server:get(route, function(_, response: HTTPServerResponse): string
					response:set_header("Content-Type", "text/html")
					return content
				end)
			end
		end
	end
	Jinja2EngineWrapper.add_to_server_debug = function(self: Jinja2Engine, server: HTTPServer, context: jinja2_context)
		local names = self:get_template_names()
		for _, value in ipairs(names) do
			local path = templates_re:replace(value, "")

			for _, route in ipairs(normalize_paths(path)) do
				server:get(route, function(_, response: HTTPServerResponse): string
					self:reload_templates()
					response:set_header("Content-Type", "text/html")
					return self:render(value, context)
				end)
			end
		end
	end

	Jinja2EngineWrapper.debug_watch = function(self: Jinja2Engine, server: HTTPServer, dir_path: string)
    local serde = require("serde")
    local fs = require("fs")

    local files = {}
    local function read_recursive(path: string): nil
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

      if old_files ~= serde.json.encode(files) then
        did_change = true
      else
        did_change = false
      end
    end, 500)
    server:get("/debug.js", function(_request?: HTTPServerRequest, response?: HTTPServerResponse)
      response:set_header("Content-Type", "text/javascript")
      return [[setInterval(async ()=>{const response=await fetch("/debug");if(response.ok &&(await response.text())=="true"){window.location.reload();}},100);]]
    end)
    server:get("/debug", function()
      return tostring(did_change)
    end)
  end

	return Jinja2EngineWrapper
end

local type astra_internal__new_markdown_ast = function(input: string): table
local function markdown_to_ast(input: string): table
	return astra_internal__new_markdown_ast(input)
end

local type astra_internal__new_markdown_html = function(input: string): string
local function markdown_to_html(input: string): string
	return astra_internal__new_markdown_html(input)
end

return {
  jinja2 = { new = new_engine },
  markdown = {
    to_ast = markdown_ast,
    to_html = markdown_html,
  },
}
