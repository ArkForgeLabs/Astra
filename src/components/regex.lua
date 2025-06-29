---@meta

---@class Regex
local Regex = {}

---@param content string
---@return string[][]
function Regex:captures(content) end

---@param content string
---@param replacement string
---@param limit number?
---@return string
function Regex:replace(content, replacement, limit) end

---@param content string
---@return boolean
function Regex:is_match(content) end

---@param expression string
---@return Regex
function Astra.regex(expression) end
