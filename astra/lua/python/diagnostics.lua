--- Simple diagnostic collector for error reporting.
--- Collects errors and warnings instead of aborting on first failure.
--- Usage: local diags = Diagnostics:new()
---        diags:error("message", location)
---        diags:warn("message", location)
---        if diags:has_errors() then ... end
---        diags:print()  -- or diags:to_table()

local Diagnostics = {}

function Diagnostics:new()
  return setmetatable({ entries = {} }, { __index = self })
end

---@param level "error"|"warning"
---@param message string
---@param location? {line?: number, col?: number, source?: string}
function Diagnostics:add(level, message, location)
  self.entries[#self.entries + 1] = {
    level = level,
    message = message,
    location = location or {},
  }
end

function Diagnostics:error(message, location)
  self:add("error", message, location)
end

function Diagnostics:warn(message, location)
  self:add("warning", message, location)
end

function Diagnostics:has_errors()
  for _, entry in ipairs(self.entries) do
    if entry.level == "error" then return true end
  end
  return false
end

function Diagnostics:count()
  return #self.entries
end

function Diagnostics:to_table()
  return self.entries
end

function Diagnostics:format()
  local parts = {}
  for _, entry in ipairs(self.entries) do
    local loc = entry.location
    local prefix = ""
    if loc.source or loc.line then
      prefix = (loc.source or "") .. ":" .. (loc.line or "?") .. ":" .. (loc.col or "?") .. ": "
    end
    parts[#parts + 1] = prefix .. entry.level .. ": " .. entry.message
  end
  return table.concat(parts, "\n")
end

function Diagnostics:print()
  if #self.entries == 0 then return end
  for _, entry in ipairs(self.entries) do
    local loc = entry.location
    local prefix = ""
    if loc.source or loc.line then
      prefix = (loc.source or "") .. ":" .. (loc.line or "?") .. ":" .. (loc.col or "?") .. ": "
    end
    print(prefix .. entry.level .. ": " .. entry.message)
  end
end

return Diagnostics
