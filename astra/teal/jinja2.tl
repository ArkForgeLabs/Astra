require("astra.teal.http")

local type template_function_type = function(args: {any:any}): any
local type template_context = {any:any}

--- Jinja2 templating engine
local interface TemplateEngineNative is userdata
	add_template: function(self: TemplateEngineNative, name: string, template: string)
	add_template_file: function(self: TemplateEngineNative, name: string, path: string)
	get_template_names: function(self: TemplateEngineNative): {string}
	exclude_templates: function(self: TemplateEngineNative, names: {string})
	reload_templates: function(self: TemplateEngineNative)
	add_function: function(self: TemplateEngineNative, name: string, template_function: template_function_type): any
	render: function(self: TemplateEngineNative, name: string, context?: template_context): string
end

global record TemplateEngine
	_engine: TemplateEngineNative

	add_template: function(self: TemplateEngine, name: string, template: string)
	add_template_file: function(self: TemplateEngine, name: string, path: string)
	get_template_names: function(self: TemplateEngine): {string}
	exclude_templates: function(self: TemplateEngine, names: {string})
	reload_templates: function(self: TemplateEngine)
	add_function: function(self: TemplateEngine, name: string, template_function: template_function_type): any
	render: function(self: TemplateEngine, name: string, context?: template_context): string
	add_to_server: function(self: TemplateEngine, server: HTTPServer, context?: template_context)
	add_to_server_debug: function(self: TemplateEngine, server: HTTPServer, context?: template_context)
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

local type astra_internal__new_templating_engine = function(dir: string): TemplateEngineNative
--- Returns a new templating engine
---@param dir? string path to the directory, for example: `"templates/**/[!exclude.html]*.html"`	
local function new_engine(dir: string): TemplateEngine
	local engine = astra_internal__new_templating_engine(dir)
	local TemplateEngineWrapper: TemplateEngine = { _engine = engine }

	TemplateEngineWrapper.add_template = function(self: TemplateEngine, name: string, template: string)
		return self._engine:add_template(name, template)
	end
	TemplateEngineWrapper.add_template_file = function(self: TemplateEngine, name: string, path: string)
		return self._engine:add_template_file(name, path)
	end
	TemplateEngineWrapper.get_template_names = function(self: TemplateEngine): {string}
		return self._engine:get_template_names()
	end
	TemplateEngineWrapper.exclude_templates = function(self: TemplateEngine, names: {string})
		return self._engine:exclude_templates(names)
	end
	TemplateEngineWrapper.reload_templates = function(self: TemplateEngine)
		return self._engine:reload_templates()
	end
	TemplateEngineWrapper.add_function = function(self: TemplateEngine, name: string, template_function: template_function_type): any
		return self._engine:add_function(name, template_function)
	end
	TemplateEngineWrapper.render = function(self: TemplateEngine, name: string, context?: template_context): string
		return self._engine:render(name, context)
	end
	TemplateEngineWrapper.add_to_server = function(self: TemplateEngine, server: HTTPServer, context: template_context)
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
	TemplateEngineWrapper.add_to_server_debug = function(self: TemplateEngine, server: HTTPServer, context: template_context)
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

	return TemplateEngineWrapper
end

return new_engine
