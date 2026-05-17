--!nocheck
--!nolint

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

local function string()
	return setmetatable({ kind = "string" }, ValidatorMt)
end

local function number(o)
	local v = { kind = "number" }
	if o then
		if o.integer then v.i = true end
		if o.range then v.r = o.range end
	end
	return setmetatable(v, ValidatorMt)
end

local function integer()
	return number({ integer = true })
end

local function boolean()
	return setmetatable({ kind = "boolean" }, ValidatorMt)
end

local function none()
	return setmetatable({ kind = "nil" }, ValidatorMt)
end

local function struct(s)
	return setmetatable({ kind = "struct", m = compile(s) }, ValidatorMt)
end

local function array(t)
	return setmetatable({ kind = "array", t = t }, ValidatorMt)
end

local function optional(t)
	return setmetatable({ kind = "optional", t = t }, ValidatorMt)
end

local function union(a, b)
	return setmetatable({ kind = "union", s = { a, b } }, ValidatorMt)
end

local function literal(v)
	return setmetatable({ kind = "literal", v = v }, ValidatorMt)
end

local function range(o)
	return number({ range = o })
end

local function pattern(p)
	return setmetatable({ kind = "string", p = p }, ValidatorMt)
end

return {
	validation = {
		string = string, number = number, integer = integer,
		boolean = boolean, none = none,
		struct = struct, array = array, optional = optional,
		union = union, literal = literal,
		range = range, pattern = pattern,
	},
	regex = astra_internal__regex,
}
