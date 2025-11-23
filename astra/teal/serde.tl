local json = {}

local type astra_internal__json_encode = function(value: table): string
---Encodes the value into a valid JSON string
function json.encode(value: table): string
	return astra_internal__json_encode(value)
end

local type astra_internal__json_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function json.decode(value: string): table
	return astra_internal__json_decode(value)
end

local json5 = {}

local type astra_internal__json5_encode = function(value: table): string
---Encodes the value into a valid JSON string
function json5.encode(value: table): string
	return astra_internal__json5_encode(value)
end

local type astra_internal__json5_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function json5.decode(value: string): table
	return astra_internal__json5_decode(value)
end

local yaml = {}

local type astra_internal__yaml_encode = function(value: table): string
---Encodes the value into a valid JSON string
function yaml.encode(value: table): string
	return astra_internal__yaml_encode(value)
end

local type astra_internal__yaml_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function yaml.decode(value: string): table
	return astra_internal__yaml_decode(value)
end

local toml = {}

local type astra_internal__toml_encode = function(value: table): string
---Encodes the value into a valid JSON string
function toml.encode(value: table): string
	return astra_internal__toml_encode(value)
end

local type astra_internal__toml_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function toml.decode(value: string): table
	return astra_internal__toml_decode(value)
end

local ini = {}

local type astra_internal__ini_encode = function(value: table): string
---Encodes the value into a valid JSON string
function ini.encode(value: table): string
	return astra_internal__ini_encode(value)
end

local type astra_internal__ini_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function ini.decode(value: string): table
	return astra_internal__ini_decode(value)
end

local xml = {}

local type astra_internal__xml_encode = function(root: string, value: table): string
---Encodes the value into a valid JSON string
function xml.encode(root: string, value: table): string
	return astra_internal__xml_encode(root, value)
end

local type astra_internal__xml_decode = function(value: string): table
---Decodes the JSON string into a valid lua value
function xml.decode(value: string): table
	return astra_internal__xml_decode(value)
end

global record CSVOptions
	buffer_capacity: number | nil
	delimiter: string | nil
	quote: string | nil
	escape: string | nil
	comment: string | nil
	flexible: boolean | nil
	quoting: boolean | nil
	double_quote: boolean | nil
	has_headers: boolean | nil
end
global record CSV
	headers: {string}
	body: {any}
end

local csv = {}

local type astra_internal__csv_decode = function(value: any, options: CSVOptions): {{any}}
function csv.decode(value: string, options: CSVOptions): CSV
  local result = astra_internal__csv_decode(value, options)
  return {
    body = result[1],
    headers = result[2] as {string} or nil
  }
end

return {
	json = json,
	json5 = json5,
	yaml = yaml,
	toml = toml,
	ini = ini,
	xml = xml,
	csv = csv
}
