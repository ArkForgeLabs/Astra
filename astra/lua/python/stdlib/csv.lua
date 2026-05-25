local serde = require("serde")
local fs = require("fs")

local csv_mod = {}

local function needs_quoting(s)
  return s:find("[,]") or s:find('"') or s:find("\n")
end

local function quote_field(s)
  return '"' .. s:gsub('"', '""') .. '"'
end

local function encode_row(row)
  local parts = {}
  for _, field in ipairs(row) do
    local s = tostring(field)
    if needs_quoting(s) then
      s = quote_field(s)
    end
    parts[#parts + 1] = s
  end
  return table.concat(parts, ",")
end

function csv_mod.reader(input, dialect)
  local decoded = serde.csv.decode(input, dialect)
  local rows = decoded and decoded.body or {}
  local i = 0
  return function()
    i = i + 1
    if i <= #rows then
      return rows[i]
    end
    return nil
  end
end

function csv_mod.writer(rows, filepath)
  local buf = {}
  for _, row in ipairs(rows) do
    buf[#buf + 1] = encode_row(row)
  end
  local output = table.concat(buf, "\n")
  if filepath then
    fs.write_file(filepath, output)
  end
  return output
end

function csv_mod.DictReader(input, dialect)
  local decoded = serde.csv.decode(input, dialect)
  local headers = decoded and decoded.headers or {}
  local rows = decoded and decoded.body or {}
  local i = 0
  return function()
    i = i + 1
    if i <= #rows then
      local row = rows[i]
      local dict = {}
      for j, header in ipairs(headers) do
        dict[header] = row[j]
      end
      return dict
    end
    return nil
  end
end

function csv_mod.DictWriter(rows, filepath)
  if #rows == 0 then return "" end
  local headers = {}
  for k in pairs(rows[1]) do
    headers[#headers + 1] = k
  end
  table.sort(headers)
  local buf = {table.concat(headers, ",")}
  for _, row in ipairs(rows) do
    local parts = {}
    for _, h in ipairs(headers) do
      local s = tostring(row[h] or "")
      if needs_quoting(s) then
        s = quote_field(s)
      end
      parts[#parts + 1] = s
    end
    buf[#buf + 1] = table.concat(parts, ",")
  end
  local output = table.concat(buf, "\n")
  if filepath then
    fs.write_file(filepath, output)
  end
  return output
end

return csv_mod
