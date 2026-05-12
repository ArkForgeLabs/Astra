---@class html
---@field a fun(...)
---@field abbr fun(...)
---@field acronym fun(...)
---@field address fun(...)
---@field applet fun(...)
---@field area fun(...)
---@field article fun(...)
---@field aside fun(...)
---@field audio fun(...)
---@field b fun(...)
---@field base fun(...)
---@field basefont fun(...)
---@field bdi fun(...)
---@field bdo fun(...)
---@field big fun(...)
---@field blockquote fun(...)
---@field body fun(...)
---@field br fun(...)
---@field button fun(...)
---@field canvas fun(...)
---@field caption fun(...)
---@field center fun(...)
---@field cite fun(...)
---@field code fun(...)
---@field col fun(...)
---@field colgroup fun(...)
---@field data fun(...)
---@field datalist fun(...)
---@field dd fun(...)
---@field del fun(...)
---@field details fun(...)
---@field dfn fun(...)
---@field dialog fun(...)
---@field dir fun(...)
---@field div fun(...)
---@field dl fun(...)
---@field dt fun(...)
---@field em fun(...)
---@field embed fun(...)
---@field fieldset fun(...)
---@field figcaption fun(...)
---@field figure fun(...)
---@field font fun(...)
---@field footer fun(...)
---@field form fun(...)
---@field frame fun(...)
---@field frameset fun(...)
---@field h1 fun(...)
---@field h2 fun(...)
---@field h3 fun(...)
---@field h4 fun(...)
---@field h5 fun(...)
---@field h6 fun(...)
---@field head fun(...)
---@field header fun(...)
---@field hgroup fun(...)
---@field hr fun(...)
---@field html fun(...)
---@field i fun(...)
---@field iframe fun(...)
---@field img fun(...)
---@field input fun(...)
---@field ins fun(...)
---@field kbd fun(...)
---@field label fun(...)
---@field legend fun(...)
---@field li fun(...)
---@field link fun(...)
---@field main fun(...)
---@field map fun(...)
---@field mark fun(...)
---@field menu fun(...)
---@field meta fun(...)
---@field meter fun(...)
---@field nav fun(...)
---@field noframes fun(...)
---@field noscript fun(...)
---@field object fun(...)
---@field ol fun(...)
---@field optgroup fun(...)
---@field option fun(...)
---@field output fun(...)
---@field p fun(...)
---@field param fun(...)
---@field picture fun(...)
---@field pre fun(...)
---@field progress fun(...)
---@field q fun(...)
---@field rp fun(...)
---@field rt fun(...)
---@field ruby fun(...)
---@field s fun(...)
---@field samp fun(...)
---@field script fun(...)
---@field section fun(...)
---@field select fun(...)
---@field small fun(...)
---@field source fun(...)
---@field span fun(...)
---@field strike fun(...)
---@field strong fun(...)
---@field style fun(...)
---@field sub fun(...)
---@field summary fun(...)
---@field sup fun(...)
---@field table fun(...)
---@field tbody fun(...)
---@field td fun(...)
---@field template fun(...)
---@field textarea fun(...)
---@field tfoot fun(...)
---@field th fun(...)
---@field thead fun(...)
---@field time fun(...)
---@field title fun(...)
---@field tr fun(...)
---@field track fun(...)
---@field tt fun(...)
---@field u fun(...)
---@field ul fun(...)
---@field var fun(...)
---@field video fun(...)
---@field wbr fun(...)
---@field xmp fun(...)
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
  ---@diagnostic disable-next-line: unknown-diag-code
  ---@diagnostic disable-next-line: unnecessary-if
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
