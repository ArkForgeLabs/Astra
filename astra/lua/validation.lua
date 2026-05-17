---@meta

local check = {}
local ValidatorMt = { __index = {
	validate = function(self, v)
		local ok, err = check[self.kind](self, v)
		if ok then return true, nil end
		return false, err
	end,
}}

local function inRange(v, r)
	if r.min and ((r.minExclusive and v <= r.min) or v < r.min) then return false end
	if r.max and ((r.maxExclusive and v >= r.max) or v > r.max) then return false end
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
	if type(v) ~= "string" then return false, "expected string, got " .. type(v) end
	if self.p and not string.match(v, self.p) then return false, "string does not match pattern" end
	return true
end

function check.number(self, v)
	if type(v) ~= "number" then return false, "expected number, got " .. type(v) end
	if self.i and v % 1 ~= 0 then return false, "expected integer, got " .. tostring(v) end
	if self.r and not inRange(v, self.r) then return false, "out of range" end
	return true
end

function check.boolean(self, v)
	if type(v) ~= "boolean" then return false, "expected boolean, got " .. type(v) end
	return true
end

check["nil"] = function(self, v)
	if v ~= nil then return false, "expected nil, got " .. type(v) end
	return true
end

function check.struct(self, t)
	if type(t) ~= "table" then return false, "expected table, got " .. type(t) end
	for k, f in pairs(self.m) do
		local ok, err = f:validate(t[k])
		if not ok then return false, tostring(k) .. ": " .. (err or "validation failed") end
	end
	for k in pairs(t) do
		if not self.m[k] then return false, "unexpected key: " .. tostring(k) end
	end
	return true
end

function check.array(self, a)
	if type(a) ~= "table" then return false, "expected array, got " .. type(a) end
	for i, v in ipairs(a) do
		local ok, err = self.t:validate(v)
		if not ok then return false, "[" .. tostring(i) .. "]: " .. (err or "validation failed") end
	end
	return true
end

function check.optional(self, v)
	if v == nil then return true end
	return self.t:validate(v)
end

function check.union(self, v)
	for _, t in ipairs(self.s) do
		local ok = t:validate(v)
		if ok then return true end
	end
	return false, "value did not match any union member"
end

function check.literal(self, v)
	if v ~= self.v then return false, "expected " .. tostring(self.v) .. ", got " .. tostring(v) end
	return true
end

---@return string
function string_type()
	return setmetatable({ kind = "string" }, ValidatorMt)
end

---@param opts? { integer?: boolean, range?: { min?: number, max?: number, minExclusive?: boolean, maxExclusive?: boolean } }
---@return number
function number(opts)
	local v = { kind = "number" }
	if opts then
		if opts.integer then v.i = true end
		if opts.range then v.r = opts.range end
	end
	return setmetatable(v, ValidatorMt)
end

---@return number
function integer()
	return number({ integer = true })
end

---@return boolean
function boolean_type()
	return setmetatable({ kind = "boolean" }, ValidatorMt)
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
	return setmetatable({ kind = "optional", t = inner }, ValidatorMt)
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
	return setmetatable({ kind = "string", p = pat }, ValidatorMt)
end

return {
	validation = {
		string = string_type, number = number, integer = integer,
		boolean = boolean_type, none = none,
		struct = struct, array = array, optional = optional,
		union = union, literal = literal,
		range = range, pattern = pattern,
	},
	regex = astra_internal__regex,
}
