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

return {
	json = json
}
