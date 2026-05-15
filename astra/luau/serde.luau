--!nocheck
--!nolint

local json = {}

--- Encodes the value into a valid JSON string
function json.encode(value: { any }): string
  return astra_internal__json_encode(value)
end

--- Decodes the JSON string into a valid lua value
function json.decode(value: string): { any }
  return astra_internal__json_decode(value)
end

local json5 = {}

--- Encodes the value into a valid JSON5 string
function json5.encode(value: { any }): string
  return astra_internal__json5_encode(value)
end

--- Decodes the JSON5 string into a valid lua value
function json5.decode(value: string): { any }
  return astra_internal__json5_decode(value)
end

local yaml = {}

--- Encodes the value into a valid YAML string
function yaml.encode(value: { any }): string
  return astra_internal__yaml_encode(value)
end

--- Decodes the YAML string into a valid lua value
function yaml.decode(value: string): { any }
  return astra_internal__yaml_decode(value)
end

local toml = {}

--- Encodes the value into a valid TOML string
function toml.encode(value: { any }): string
  return astra_internal__toml_encode(value)
end

--- Decodes the TOML string into a valid lua value
function toml.decode(value: string): { any }
  return astra_internal__toml_decode(value)
end

local ini = {}

--- Encodes the value into a valid INI string
function ini.encode(value: { any }): string
  return astra_internal__ini_encode(value)
end

--- Decodes the INI string into a valid lua value
function ini.decode(value: string): { any }
  return astra_internal__ini_decode(value)
end

local xml = {}

--- Encodes the value into a valid XML string
function xml.encode(root: string, value: { any }): string
  return astra_internal__xml_encode(root, value)
end

--- Decodes the XML string into a valid lua value
---
--- Note that overlapping lists and DOCTYPE are not supported.
--- Trim them or use a specialized parsers for those documents. Especially HTML.
---
--- Element contents are designated as `$text` and fields have a prefix of `@`
function xml.decode(value: string): { any }
  return astra_internal__xml_decode(value)
end

type CSVOptions = {
  --- Set the capacity (in bytes) of the buffer used in the CSV reader.
  buffer_capacity: number?,
  --- The field delimiter to use when parsing CSV. Defaults to ','
  delimiter: string?,
  --- The quote character to use when parsing CSV. The default is '"'.
  quote: string?,
  --- The escape character to use when parsing CSV.
  escape: string?,
  --- The comment character to use when parsing CSV.
  comment: string?,
  --- Whether the number of fields in records is allowed to change or not.
  flexible: boolean?,
  --- Enable or disable quoting.
  quoting: boolean?,
  --- Enable double quote escapes.
  double_quote: boolean?,
  --- Whether to treat the first row as a special header row.
  has_headers: boolean?,
}

local csv = {}

--- Decodes the CSV string into a valid lua value
function csv.decode(value: string, options: CSVOptions?): { body: { any }, headers: { string }? }
  local result = astra_internal__csv_decode(value, options)
  return {
    body = result[1],
    headers = result[2],
  }
end

return {
  json = json,
  json5 = json5,
  yaml = yaml,
  toml = toml,
  ini = ini,
  xml = xml,
  csv = csv,
}
