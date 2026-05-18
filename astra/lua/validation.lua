---@meta

local check = {}
local ValidatorMt = {
  __index = {
    validate = function(self, v)
      local ok, err = pcall(check[self.kind], self, v)
      if ok then
        return true, nil
      end
      return false, err
    end,
  },
}

local function is_leaf_error(msg)
  return msg:match("^expected ")
    or msg:match("^out of ")
    or msg:match("^value ")
    or msg:match("^unexpected ")
    or msg:match("^string ")
end

local function inRange(v, r)
  if r.min and ((r.minExclusive and v <= r.min) or v < r.min) then
    return false
  end
  if r.max and ((r.maxExclusive and v >= r.max) or v > r.max) then
    return false
  end
  return true
end

local function compile(s)
  local m = {}
  for k, v in pairs(s) do
    m[k] = type(v) == "table" and rawget(v, "kind") and v or v
  end
  return m
end

function check.string(self, v)
  if type(v) ~= "string" then
    error("expected string, got " .. type(v), 0)
  end
  if self.p and not string.match(v, self.p) then
    error("string does not match pattern", 0)
  end
end

function check.number(self, v)
  if type(v) ~= "number" then
    error("expected number, got " .. type(v), 0)
  end
  if self.i and v % 1 ~= 0 then
    error("expected integer, got " .. tostring(v), 0)
  end
  if self.r and not inRange(v, self.r) then
    error("out of range", 0)
  end
end

function check.boolean(self, v)
  if type(v) ~= "boolean" then
    error("expected boolean, got " .. type(v), 0)
  end
end

check["nil"] = function(self, v)
  if v ~= nil then
    error("expected nil, got " .. type(v), 0)
  end
end

function check.struct(self, t)
  if type(t) ~= "table" then
    error("expected table, got " .. type(t), 0)
  end
  for k, f in pairs(self.m) do
    local ok, err = f:validate(t[k])
    if not ok then
      if is_leaf_error(err) then
        error(tostring(k) .. ": " .. err, 0)
      else
        error(tostring(k) .. "." .. err, 0)
      end
    end
  end
  for k in pairs(t) do
    if not self.m[k] then
      error("unexpected key: " .. tostring(k), 0)
    end
  end
end

function check.array(self, a)
  if type(a) ~= "table" then
    error("expected array, got " .. type(a), 0)
  end
  for i, v in ipairs(a) do
    local ok, err = self.t:validate(v)
    if not ok then
      if is_leaf_error(err) then
        error("[" .. tostring(i) .. "]: " .. err, 0)
      else
        error("[" .. tostring(i) .. "]." .. err, 0)
      end
    end
  end
end

function check.optional(self, v)
  if v == nil then
    return
  end
  local ok, err = self.t:validate(v)
  if not ok then
    error(err, 0)
  end
end

function check.union(self, v)
  for _, t in ipairs(self.s) do
    local ok = t:validate(v)
    if ok then
      return
    end
  end
  error("value did not match any union member", 0)
end

function check.literal(self, v)
  if v ~= self.v then
    error("expected " .. tostring(self.v) .. ", got " .. tostring(v), 0)
  end
end

---@param opts? { default?: string }
---@return string
function string_type(opts)
  local v = { kind = "string" }
  if opts and opts.default ~= nil then
    v.default = opts.default
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable(v, ValidatorMt)
end

---@param opts? { integer?: boolean, range?: { min?: number, max?: number, minExclusive?: boolean, maxExclusive?: boolean }, default?: number }
---@return number
function number(opts)
  local v = { kind = "number" }
  if opts then
    if opts.integer then
      v.i = true
    end
    if opts.range then
      v.r = opts.range
    end
    if opts.default ~= nil then
      v.default = opts.default
    end
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable(v, ValidatorMt)
end

---@return number
function integer()
  return number({ integer = true })
end

---@param opts? { default?: boolean }
---@return boolean
function boolean_type(opts)
  local v = { kind = "boolean" }
  if opts and opts.default ~= nil then
    v.default = opts.default
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable(v, ValidatorMt)
end

---@return nil
function none()
  return setmetatable({ kind = "nil" }, ValidatorMt)
end

---@generic T
---@param schema T
---@return T
function struct(schema)
  return setmetatable({ kind = "struct", m = compile(schema) }, ValidatorMt)
end

---@generic T
---@param item T
---@return T[]
function array(item)
  return setmetatable({ kind = "array", t = item }, ValidatorMt)
end

---@generic T
---@param inner T
---@return T|nil
function optional(inner)
  ---@diagnostic disable-next-line: undefined-field
  return setmetatable({ kind = "optional", t = inner, default = inner.default }, ValidatorMt)
end

---@generic T, U
---@param a T
---@param b U
---@return T|U
function union(a, b)
  return setmetatable({ kind = "union", s = { a, b } }, ValidatorMt)
end

---@generic T
---@param value T
---@return T
function literal(value)
  return setmetatable({ kind = "literal", v = value }, ValidatorMt)
end

---@param opts { min?: number, max?: number, minExclusive?: boolean, maxExclusive?: boolean }
---@return number
function range(opts)
  return number({ range = opts })
end

---@param pat string
---@return string
function pattern(pat)
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable({ kind = "string", p = pat }, ValidatorMt)
end

---@param v any
---@param value any
---@return boolean, string?
function validate(v, value)
  return v:validate(value)
end

---@generic T
---@param schema T
---@return T
function build(schema)
  ---@diagnostic disable-next-line: undefined-field
  local m = schema.m
  ---@diagnostic disable-next-line: undefined-field
  return setmetatable({ schema = schema }, {
    __call = function(_, data)
      if type(data) ~= "table" then
        error("expected table, got " .. type(data), 0)
      end
      local merged = {}
      for k, v in pairs(data) do
        merged[k] = v
      end
      if m then
        for k, f in pairs(m) do
          if merged[k] == nil and f.default ~= nil then
            merged[k] = f.default
          end
        end
      end
      ---@diagnostic disable-next-line: undefined-field
      local ok, err = schema:validate(merged)
      if not ok then
        error(err, 0)
      end
      return merged
    end,
    __index = {
      type = function(self)
        ---@diagnostic disable-next-line: return-type-mismatch
        return self.schema
      end,
      ---@diagnostic disable-next-line: undefined-field
      validate = function(self, value)
        return self.schema:validate(value)
      end,
    },
  })
end

---@class Regex
---@field captures fun(regex: Regex, content: string): string[][]
---@field replace fun(regex: Regex, content: string, replacement: string, limit: number?): string
---@field is_match fun(regex: Regex, content: string): boolean

---@param expression string
---@return Regex
function regex(expression)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__regex(expression)
end

return {
  types = {
    string = string_type,
    number = number,
    integer = integer,
    boolean = boolean_type,
    none = none,
    struct = struct,
    array = array,
    optional = optional,
    union = union,
    literal = literal,
    range = range,
    pattern = pattern,
    validate = validate,
    build = build,
  },
  regex = regex,
}
