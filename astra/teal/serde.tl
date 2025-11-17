local json = {}

local type astra_internal__json_encode = function(value: any): string
---Encodes the value into a valid JSON string
function json.encode(value: any): string
	return astra_internal__json_encode(value)
end

local type astra_internal__json_decode = function(value: string): any
---Decodes the JSON string into a valid lua value
function json.decode(value: string): any
	return astra_internal__json_decode(value)
end

local json5 = {}

local type astra_internal__json5_encode = function(value: any): string
---Encodes the value into a valid JSON string
function json5.encode(value: any): string
	return astra_internal__json5_encode(value)
end

local type astra_internal__json5_decode = function(value: string): any
---Decodes the JSON string into a valid lua value
function json5.decode(value: string): any
	return astra_internal__json5_decode(value)
end

local yaml = {}

local type astra_internal__yaml_encode = function(value: any): string
---Encodes the value into a valid JSON string
function yaml.encode(value: any): string
	return astra_internal__yaml_encode(value)
end

local type astra_internal__yaml_decode = function(value: string): any
---Decodes the JSON string into a valid lua value
function yaml.decode(value: string): any
	return astra_internal__yaml_decode(value)
end

local toml = {}

local type astra_internal__toml_encode = function(value: any): string
---Encodes the value into a valid JSON string
function toml.encode(value: any): string
	return astra_internal__toml_encode(value)
end

local type astra_internal__toml_decode = function(value: string): any
---Decodes the JSON string into a valid lua value
function toml.decode(value: string): any
	return astra_internal__toml_decode(value)
end

local ini = {}

local type astra_internal__ini_encode = function(value: any): string
---Encodes the value into a valid JSON string
function ini.encode(value: any): string
	return astra_internal__ini_encode(value)
end

local type astra_internal__ini_decode = function(value: string): any
---Decodes the JSON string into a valid lua value
function ini.decode(value: string): any
	return astra_internal__ini_decode(value)
end

return {
	json = json,
	json5 = json5,
	yaml = yaml,
	toml = toml,
	ini = ini
}
