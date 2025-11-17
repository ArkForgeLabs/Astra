---@meta

local json = {}

---Encodes the value into a valid JSON string
---@param value any
---@return string
function json.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json_encode(value)
end

---Decodes the JSON string into a valid lua value
---@param value string
---@return any
function json.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json_decode(value)
end

local yaml = {}

---Encodes the value into a valid YAML string
---@param value any
---@return string
function yaml.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__yaml_encode(value)
end

---Decodes the YAML string into a valid lua value
---@param value string
---@return any
function yaml.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__yaml_decode(value)
end

return {
  json = json,
  yaml = yaml
}
