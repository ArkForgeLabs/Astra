--!nocheck
--!nolint

type Range = { min: number?, max: number?, minExclusive: boolean?, maxExclusive: boolean? }

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

function string(o: { default: string? }?): string
  local v = { kind = "string" }
  if o and o.default ~= nil then
    v.default = o.default
  end
  return setmetatable(v, ValidatorMt) :: string
end

function number(o: { integer: boolean?, range: Range?, default: number? }?): number
  local v = { kind = "number" }
  if o then
    if o.integer then
      v.i = true
    end
    if o.range then
      v.r = o.range
    end
    if o.default ~= nil then
      v.default = o.default
    end
  end
  return setmetatable(v, ValidatorMt) :: number
end

function integer(): number
  return number({ integer = true })
end

function boolean(o: { default: boolean? }?): boolean
  local v = { kind = "boolean" }
  if o and o.default ~= nil then
    v.default = o.default
  end
  return setmetatable(v, ValidatorMt) :: boolean
end

function none(): nil
  return setmetatable({ kind = "nil" }, ValidatorMt) :: nil
end

function struct<T>(s: T): T
  return setmetatable({ kind = "struct", m = compile(s) }, ValidatorMt) :: T
end

function array<T>(item: T): { T }
  return setmetatable({ kind = "array", t = item }, ValidatorMt) :: { T }
end

function optional<T>(inner: T): T?
  return setmetatable({ kind = "optional", t = inner, default = inner.default }, ValidatorMt) :: T?
end

function union<T, U>(a: T, b: U): T | U
  return setmetatable({ kind = "union", s = { a, b } }, ValidatorMt) :: T | U
end

function literal<T>(value: T): T
  return setmetatable({ kind = "literal", v = value }, ValidatorMt) :: T
end

function range(o: Range): number
  return number({ range = o })
end

function pattern(p: string): string
  return setmetatable({ kind = "string", p = p }, ValidatorMt) :: string
end

function validate(v: any, value: any): (boolean, string?)
  return v:validate(value)
end

function build<T>(s: T)
  local m = s.m
  return setmetatable({ schema = s }, {
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
      local ok, err = s:validate(merged)
      if not ok then
        error(err, 0)
      end
      return merged
    end,
    __index = {
      type = function(self): T
        return self.schema :: T
      end,
      validate = function(self, value: any): (boolean, string?)
        return self.schema:validate(value)
      end,
    },
  })
end

type Regex = {
  captures: (regex: Regex, content: string) -> { { string } },
  replace: (regex: Regex, content: string, replacement: string, limit: number?) -> string,
  is_match: (regex: Regex, content: string) -> boolean,
}

function regex(expression: string): Regex
  return astra_internal__regex(expression)
end

return {
  validation = {
    string = string,
    number = number,
    integer = integer,
    boolean = boolean,
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
