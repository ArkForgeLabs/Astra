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

local json5 = {}

---Encodes the value into a valid JSON5 string
---@param value any
---@return string
function json5.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json5_encode(value)
end

---Decodes the JSON5 string into a valid lua value
---@param value string
---@return any
function json5.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json5_decode(value)
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

local toml = {}

---Encodes the value into a valid TOML string
---@param value any
---@return string
function toml.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__toml_encode(value)
end

---Decodes the TOML string into a valid lua value
---@param value string
---@return any
function toml.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__toml_decode(value)
end

local ini = {}

---Encodes the value into a valid INI string
---@param value any
---@return string
function ini.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__ini_encode(value)
end

---Decodes the INI string into a valid lua value
---@param value string
---@return any
function ini.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__ini_decode(value)
end

return {
  json = json,
  json5 = json5,
  yaml = yaml,
  toml = toml,
  ini = ini
}
