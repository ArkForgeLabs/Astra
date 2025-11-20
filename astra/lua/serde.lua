---@meta

local json = {}

---Encodes the value into a valid JSON string
---@param value table
---@return string
function json.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json_encode(value)
end

---Decodes the JSON string into a valid lua value
---@param value string
---@return table
function json.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json_decode(value)
end

local json5 = {}

---Encodes the value into a valid JSON5 string
---@param value table
---@return string
function json5.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json5_encode(value)
end

---Decodes the JSON5 string into a valid lua value
---@param value string
---@return table
function json5.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__json5_decode(value)
end

local yaml = {}

---Encodes the value into a valid YAML string
---@param value table
---@return string
function yaml.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__yaml_encode(value)
end

---Decodes the YAML string into a valid lua value
---@param value string
---@return table
function yaml.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__yaml_decode(value)
end

local toml = {}

---Encodes the value into a valid TOML string
---@param value table
---@return string
function toml.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__toml_encode(value)
end

---Decodes the TOML string into a valid lua value
---@param value string
---@return table
function toml.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__toml_decode(value)
end

local ini = {}

---Encodes the value into a valid INI string
---@param value table
---@return string
function ini.encode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__ini_encode(value)
end

---Decodes the INI string into a valid lua value
---@param value string
---@return table
function ini.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__ini_decode(value)
end

local xml = {}

---Encodes the value into a valid XML string
---@param root string
---@param value table
---@return string
function xml.encode(root, value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__xml_encode(root, value)
end

---Decodes the XML string into a valid lua value
---
---Note that overlapping lists and DOCTYPE are not supported.
---Trim them or use a specialized parsers for those documents. Especially HTML.
---
---Element contents are designated as `$text` and fields have a prefix of `@`
---@param value string
---@return table
function xml.decode(value)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__xml_decode(value)
end

---@class CSVOptions
---Set the capacity (in bytes) of the buffer used in the CSV reader.
---This defaults to a reasonable setting.
---@field buffer_capacity number?
---The field delimiter to use when parsing CSV. Defaults to ','
---@field delimiter string?
---The quote character to use when parsing CSV. The default is '"'.
---@field quote string?
---The escape character to use when parsing CSV. In some variants of CSV,
---quotes are escaped using a special escape character like \ (instead of
---escaping quotes by doubling them). By default, recognizing these
---idiosyncratic escapes is disabled.
---@field escape string?
---The comment character to use when parsing CSV. If the start of
---a record begins with the byte given here, then that line is
---ignored by the CSV parser. This is disabled by default.
---@field comment string?
---Whether the number of fields in records is allowed to change or not.
---When disabled (which is the default), parsing CSV data will return
---an error if a record is found with a number of fields different
---from the number of fields in a previous record. When enabled,
---this error checking is turned off.
---@field flexible boolean?
---Enable or disable quoting. This is enabled by default, but it may
---be disabled. When disabled, quotes are not treated specially.
---@field quoting boolean?
---Enable double quote escapes. This is enabled by default, but it may
---be disabled. When disabled, doubled quotes are not interpreted as escapes.
---@field double_quote boolean?
---hether to treat the first row as a special header row. By default,
---the first row is treated as a special header row, which means the
---header is never returned by any of the record reading methods or
---iterators. When this is disabled, the first row is not treated specially.
---@field has_headers boolean?

local csv = {}

---Decodes the CSV string into a valid lua value
---@param value string
---@param options CSVOptions?
---@return {body: any[], headers: string[]}
function csv.decode(value, options)
  ---@diagnostic disable-next-line: undefined-global
  local result = astra_internal__csv_decode(value, options)
  return {
    body = result[1],
    headers = result[2] or nil
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
