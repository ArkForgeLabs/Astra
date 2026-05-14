--!strict

local astra_internal__json_encode: (value: { any }) -> string
local astra_internal__json_decode: (value: string) -> { any }
local astra_internal__json5_encode: (value: { any }) -> string
local astra_internal__json5_decode: (value: string) -> { any }
local astra_internal__yaml_encode: (value: { any }) -> string
local astra_internal__yaml_decode: (value: string) -> { any }
local astra_internal__toml_encode: (value: { any }) -> string
local astra_internal__toml_decode: (value: string) -> { any }
local astra_internal__ini_encode: (value: { any }) -> string
local astra_internal__ini_decode: (value: string) -> { any }
local astra_internal__xml_encode: (root: string, value: { any }) -> string
local astra_internal__xml_decode: (value: string) -> { any }
local astra_internal__csv_decode: (value: string, options: CSVOptions?) -> { { any }, { string }? }

type CSVOptions = {
  buffer_capacity: number?,
  delimiter: string?,
  quote: string?,
  escape: string?,
  comment: string?,
  flexible: boolean?,
  quoting: boolean?,
  double_quote: boolean?,
  has_headers: boolean?,
}

local json: {
  encode: (value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(value: { any }): string
    return astra_internal__json_encode(value)
  end,
  decode = function(value: string): { any }
    return astra_internal__json_decode(value)
  end,
}

local json5: {
  encode: (value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(value: { any }): string
    return astra_internal__json5_encode(value)
  end,
  decode = function(value: string): { any }
    return astra_internal__json5_decode(value)
  end,
}

local yaml: {
  encode: (value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(value: { any }): string
    return astra_internal__yaml_encode(value)
  end,
  decode = function(value: string): { any }
    return astra_internal__yaml_decode(value)
  end,
}

local toml: {
  encode: (value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(value: { any }): string
    return astra_internal__toml_encode(value)
  end,
  decode = function(value: string): { any }
    return astra_internal__toml_decode(value)
  end,
}

local ini: {
  encode: (value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(value: { any }): string
    return astra_internal__ini_encode(value)
  end,
  decode = function(value: string): { any }
    return astra_internal__ini_decode(value)
  end,
}

local xml: {
  encode: (root: string, value: { any }) -> string,
  decode: (value: string) -> { any },
} = {
  encode = function(root: string, value: { any }): string
    return astra_internal__xml_encode(root, value)
  end,
  decode = function(value: string): { any }
    return astra_internal__xml_decode(value)
  end,
}

local csv: {
  decode: (value: string, options: CSVOptions?) -> { body: { any }, headers: { string }? },
} = {
  decode = function(value: string, options: CSVOptions?): { body: { any }, headers: { string }? }
    local result = astra_internal__csv_decode(value, options)
    return {
      body = result[1],
      headers = (if result[2] then result[2] else nil) :: { string }?,
    }
  end,
}

return {
  json = json,
  json5 = json5,
  yaml = yaml,
  toml = toml,
  ini = ini,
  xml = xml,
  csv = csv,
}
