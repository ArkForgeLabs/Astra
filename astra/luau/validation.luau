--!nocheck
--!nolint

type TypeMap = {
  number: string,
  string: string,
  boolean: string,
  table: string,
  ["function"]: string,
  ["nil"]: string,
  array: string,
}

local TypeMap: TypeMap = {
  number = "number",
  string = "string",
  boolean = "boolean",
  table = "table",
  ["function"] = "function",
  ["nil"] = "nil",
  array = "table",
}

type Regex = {
  captures: (regex: Regex, content: string) -> { { string } },
  replace: (regex: Regex, content: string, replacement: string, limit: number?) -> string,
  is_match: (regex: Regex, content: string) -> boolean,
}

--- Schema validation function with support for nested tables and arrays of tables
local function validate_table(input_table: { any }, schema: { string: any }): (boolean, string?)
  local function check_type(value: any, expected_type: string): boolean
    return type(value) == TypeMap[expected_type]
  end

  local function check_range(value: any, min: number?, max: number?): boolean
    if type(value) == "number" then
      if min ~= nil and value < min then
        return false
      end
      if max ~= nil and value > max then
        return false
      end
      return true
    end
    if type(value) == "string" and type(min) == "number" and type(max) == "number" then
      local length = #value
      if min ~= nil and length < min then
        return false
      end
      if max ~= nil and length > max then
        return false
      end
      return true
    end
    return true
  end

  local function process_schema_constraints(
    constraints: any,
    _key: string
  ): {
    type_: string?,
    required: boolean,
    min: number?,
    max: number?,
    schema: { string: any }?,
    array_item_type: string?,
  }
    local field_info = {
      type_ = nil,
      required = true,
      min = nil,
      max = nil,
      schema = nil,
      array_item_type = nil,
    }

    if type(constraints) == "string" then
      field_info.type_ = constraints
    elseif type(constraints) == "table" then
      if #constraints > 0 then
        local first_elem = constraints[1]

        if first_elem == "array" then
          field_info.type_ = "array"
          if #constraints == 2 then
            if type(constraints[2]) == "string" then
              field_info.array_item_type = constraints[2]
            elseif type(constraints[2]) == "table" then
              field_info.schema = constraints[2]
            end
          end
        else
          field_info.type_ = first_elem
          if #constraints == 2 then
            if type(constraints[2]) == "boolean" then
              field_info.required = constraints[2]
            elseif type(constraints[2]) == "table" then
              field_info.schema = constraints[2]
            end
          end
          if constraints.min then
            field_info.min = constraints.min
          end
          if constraints.max then
            field_info.max = constraints.max
          end
          if constraints.required == false then
            field_info.required = false
          end
        end
      else
        if constraints.type then
          field_info.type_ = constraints.type
        else
          field_info.type_ = "table"
          field_info.schema = constraints
          if constraints.required == false then
            field_info.required = false
          end
        end

        if constraints.min then
          field_info.min = constraints.min
        end
        if constraints.max then
          field_info.max = constraints.max
        end
        if constraints.required == false then
          field_info.required = false
        end
      end
    end

    return field_info
  end

  local function validate_nested_table(value: { any }, nested_schema: { string: any }, path: string): (boolean, string?)
    local is_valid, err = validate_table(value, nested_schema)
    if not is_valid then
      return false, '"' .. path .. '"' .. (err or "")
    end
    return true, nil
  end

  local function validate_array_of_tables(value: any, array_schema: { string: any }, path: string): (boolean, string?)
    if type(value) ~= "table" then
      return false, path .. ": Expected an array of tables, got " .. type(value)
    end
    for i, item in ipairs(value) do
      local is_valid, err = validate_nested_table(item, array_schema, path .. "[" .. i .. "]")
      if not is_valid then
        return false, err or ""
      end
    end
    return true, nil
  end

  local function validate_array_of_primitives(value: any, array_item_type: string, path: string): (boolean, string?)
    if type(value) ~= "table" then
      return false, path .. ": Expected an array, got " .. type(value)
    end
    for i, item in ipairs(value) do
      if not check_type(item, array_item_type) then
        return false, path .. "[" .. i .. "]: Expected " .. array_item_type .. ", got " .. type(item)
      end
    end
    return true, nil
  end

  for key, constraints in pairs(schema) do
    local field_info = process_schema_constraints(constraints, key)
    local value = input_table[key]
    local expected_type = field_info.type_
    local min = field_info.min
    local max = field_info.max
    local nested_schema = field_info.schema
    local path = key
    local required = field_info.required

    if required and value == nil then
      return false, "\n" .. 'Missing required key: "' .. path .. '"'
    end

    if value ~= nil and expected_type ~= nil and not check_type(value, expected_type) then
      return false,
        "\n" .. "Incorrect type for key: " .. path .. ". Expected " .. expected_type .. ", got " .. type(value)
    end

    if nested_schema and type(value) == "table" and expected_type == "table" then
      local is_valid, err = validate_nested_table(value, nested_schema, path)
      if not is_valid then
        return false, "\n" .. "Error in nested table for key: " .. (err or "")
      end
    end

    if expected_type == "array" and type(value) == "table" then
      if nested_schema then
        local is_valid, err = validate_array_of_tables(value, nested_schema, path)
        if not is_valid then
          return false, "\n" .. "Error in array of tables for key: " .. (err or "")
        end
      elseif field_info.array_item_type then
        local is_valid, err = validate_array_of_primitives(value, field_info.array_item_type, path)
        if not is_valid then
          return false, "\n" .. "Error in array of primitives for key: " .. (err or "")
        end
      end
    end

    if value ~= nil and not check_range(value, min, max) then
      return false, "\n" .. "Value for key " .. path .. " is out of range."
    end
  end

  for key in pairs(input_table) do
    if not schema[key] then
      return false, "\n" .. "Unexpected key found: " .. key
    end
  end

  return true, nil
end

function regex(expression: string): Regex
  return astra_internal__regex(expression)
end

return { validate_table = validate_table, regex = regex }
