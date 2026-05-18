--!nocheck
--!nolint

local html = {}

-- List of void (self-closing) HTML tags
local void_tags = {
  area = true,
  base = true,
  br = true,
  col = true,
  embed = true,
  hr = true,
  img = true,
  input = true,
  link = true,
  meta = true,
  param = true,
  source = true,
  track = true,
  wbr = true,
}

-- Helper function to escape HTML special characters
local function escape(text)
  return (
    string.gsub(text, "[<>&\"']", {
      ["<"] = "&lt;",
      [">"] = "&gt;",
      ["&"] = "&amp;",
      ['"'] = "&quot;",
      ["'"] = "&#39;",
    })
  )
end

-- Helper function to generate attributes string
local function generate_attributes(attrs)
  if not attrs then
    return ""
  end
  local attr_list = {}
  for k, v in pairs(attrs) do
    if type(v) == "table" then
      local class_list = {}
      for _, class_value in ipairs(v) do
        if type(class_value) == "string" then
          table.insert(class_list, class_value)
        end
      end
      for class_key, class_value in pairs(v) do
        if type(class_value) == "boolean" and class_value then
          table.insert(class_list, class_key)
        end
      end
      table.insert(attr_list, k .. '="' .. escape(table.concat(class_list, " ")) .. '"')
    elseif type(v) == "boolean" then
      if v then
        table.insert(attr_list, k)
      end
    elseif type(v) == "string" or type(v) == "number" then
      table.insert(attr_list, k .. '="' .. escape(tostring(v)) .. '"')
    end
  end
  return table.concat(attr_list, " ")
end

-- Helper function to generate HTML for a single element
local function generate_element(tag, attrs, content)
  local attrs_str = generate_attributes(attrs)
  if attrs_str ~= "" then
    attrs_str = " " .. attrs_str
  end
  if void_tags[tag] then
    return "<" .. tag .. attrs_str .. " />"
  else
    return "<" .. tag .. attrs_str .. ">" .. (content or "") .. "</" .. tag .. ">"
  end
end

-- Metatable to dynamically create tag functions
local mt = {
  __index = function(tbl, tag)
    return function(attrs, content)
      if type(attrs) == "string" and type(content) == "nil" then
        -- attrs is actually the content
        content = attrs
        attrs = nil
      elseif type(attrs) == "function" and type(content) == "nil" then
        -- attrs is actually the content function
        content = attrs
        attrs = nil
      end
      if type(content) == "function" then
        content = content()
      end
      if type(content) == "table" then
        content = table.concat(content)
      end
      return generate_element(tag, attrs, content)
    end
  end,
}

-- Set the metatable for html_generator
setmetatable(html, mt)

-- Shortcut functions for common HTML tags
function html.text(...)
  return escape(...)
end

function html.raw(...)
  return ...
end

return html
