--!strict

type Test = {
  level: number,
  passes: number,
  errors: number,
  befores: { { (string) -> () } },
  afters: { { (string) -> () } },
  nocolor: (self: Test) -> Test,
  describe: (self: Test, name: string, fn: () -> ()) -> (),
  it: (self: Test, name: string, fn: () -> ()) -> (),
  test: (self: Test, name: string, fn: () -> ()) -> (),
  before: (self: Test, fn: (string) -> ()) -> (),
  after: (self: Test, fn: (string) -> ()) -> (),
  expect: (self: Test, v: any) -> any,
  spy: (self: Test, target: any, name: any, run: any) -> any,
  paths: any,
}

local lust: Test = {
  level = 0,
  passes = 0,
  errors = 0,
  befores = {},
  afters = {},
}

local red = string.char(27) .. "[31m"
local green = string.char(27) .. "[32m"
local normal = string.char(27) .. "[0m"
local function indent(level: number?): string
  return string.rep("\t", level or lust.level)
end

function lust:nocolor(): Test
  red, green, normal = "", "", ""
  return lust
end

function lust:describe(name: string, fn: () -> ())
  print(indent() .. name)
  self.level = self.level + 1
  fn()
  self.befores[self.level] = {}
  self.afters[self.level] = {}
  self.level = self.level - 1
end

function lust:it(name: string, fn: () -> ())
  for level = 1, self.level do
    if self.befores[level] then
      for i = 1, #self.befores[level] do
        self.befores[level][i](name)
      end
    end
  end

  local success, err = pcall(fn)
  if success then
    self.passes = self.passes + 1
  else
    self.errors = self.errors + 1
  end
  local color = if success then green else red
  local label = if success then "PASS" else "FAIL"
  print(indent() .. color .. label .. normal .. " " .. name)
  if err then
    print(indent(self.level + 1) .. red .. tostring(err) .. normal)
  end

  for level = 1, self.level do
    if self.afters[level] then
      for i = 1, #self.afters[level] do
        self.afters[level][i](name)
      end
    end
  end
end

function lust:before(fn: (string) -> ())
  self.befores[self.level] = self.befores[self.level] or {}
  table.insert(self.befores[self.level], fn)
end

function lust:after(fn: (string) -> ())
  self.afters[self.level] = self.afters[self.level] or {}
  table.insert(self.afters[self.level], fn)
end

local function isa(v: any, x: any): (boolean, string?, string?)
  if type(x) == "string" then
    return type(v) == x,
      "expected " .. tostring(v) .. " to be a " .. x,
      "expected " .. tostring(v) .. " to not be a " .. x
  elseif type(x) == "table" then
    if type(v) ~= "table" then
      return false,
        "expected " .. tostring(v) .. " to be a " .. tostring(x),
        "expected " .. tostring(v) .. " to not be a " .. tostring(x)
    end

    local seen = {}
    local meta = v
    while meta and not seen[meta] do
      if meta == x then
        return true, nil, nil
      end
      seen[meta] = true
      meta = if getmetatable(meta) then getmetatable(meta).__index else nil
    end

    return false,
      "expected " .. tostring(v) .. " to be a " .. tostring(x),
      "expected " .. tostring(v) .. " to not be a " .. tostring(x)
  end

  error("invalid type " .. tostring(x))
end

local function has(t: { any }, x: any): boolean
  for _, v in pairs(t) do
    if v == x then
      return true
    end
  end
  return false
end

local function eq(t1: any, t2: any, eps: number?): boolean
  if type(t1) ~= type(t2) then
    return false
  end
  if type(t1) == "number" then
    return math.abs(t1 - t2) <= (eps or 0)
  end
  if type(t1) ~= "table" then
    return t1 == t2
  end
  for k, _ in pairs(t1) do
    if not eq(t1[k], t2[k], eps) then
      return false
    end
  end
  for k, _ in pairs(t2) do
    if not eq(t2[k], t1[k], eps) then
      return false
    end
  end
  return true
end

local function stringify(t: any): string
  if type(t) == "string" then
    return "'" .. tostring(t) .. "'"
  end
  if type(t) ~= "table" or (getmetatable(t) and getmetatable(t).__tostring) then
    return tostring(t)
  end
  local strings = {}
  for i, v in ipairs(t) do
    strings[#strings + 1] = stringify(v)
  end
  for k, v in pairs(t) do
    if type(k) ~= "number" or k > #t or k < 1 then
      strings[#strings + 1] = ("[%s] = %s"):format(stringify(k), stringify(v))
    end
  end
  return "{ " .. table.concat(strings, ", ") .. " }"
end

local paths = {
  [""] = { "to", "to_not" },
  to = { "have", "equal", "be", "exist", "fail", "match" },
  to_not = {
    "have",
    "equal",
    "be",
    "exist",
    "fail",
    "match",
    chain = function(a: any)
      a.negate = not a.negate
    end,
  },
  a = { test = isa },
  an = { test = isa },
  be = {
    "a",
    "an",
    "truthy",
    test = function(v: any, x: any): (boolean, string?, string?)
      return v == x,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to be the same",
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to not be the same"
    end,
  },
  exist = {
    test = function(v: any): (boolean, string?, string?)
      return v ~= nil, "expected " .. tostring(v) .. " to exist", "expected " .. tostring(v) .. " to not exist"
    end,
  },
  truthy = {
    test = function(v: any): (boolean, string?, string?)
      return if v then true else false,
        "expected " .. tostring(v) .. " to be truthy",
        "expected " .. tostring(v) .. " to not be truthy"
    end,
  },
  equal = {
    test = function(v: any, x: any, eps: number?): (boolean, string?, string?)
      local comparison = ""
      local equal = eq(v, x, eps)

      if not equal and (type(v) == "table" or type(x) == "table") then
        comparison = comparison .. "\n" .. indent(lust.level + 1) .. "LHS: " .. stringify(v)
        comparison = comparison .. "\n" .. indent(lust.level + 1) .. "RHS: " .. stringify(x)
      end

      return equal,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to be equal" .. comparison,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to not be equal"
    end,
  },
  have = {
    test = function(v: any, x: any): (boolean, string?, string?)
      if type(v) ~= "table" then
        error("expected " .. tostring(v) .. " to be a table")
      end

      return has(v, x),
        "expected " .. tostring(v) .. " to contain " .. tostring(x),
        "expected " .. tostring(v) .. " to not contain " .. tostring(x)
    end,
  },
  fail = {
    "with",
    test = function(v: any): (boolean, string?, string?)
      local ok = pcall(v)
      return not ok, "expected " .. tostring(v) .. " to fail", "expected " .. tostring(v) .. " to not fail"
    end,
  },
  with = {
    test = function(v: any, pattern: string): (boolean, string?, string?)
      local ok, message = pcall(v)
      if not ok and message then
        return not ok and message:match(pattern) ~= nil,
          "expected " .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
          "expected " .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
      end
      return false, "expected function to fail", "expected function to not fail"
    end,
  },
  match = {
    test = function(v: any, p: string): (boolean, string?, string?)
      local str = if type(v) == "string" then v else tostring(v)
      local result = string.find(str, p)
      return result ~= nil,
        "expected " .. str .. " to match pattern [[" .. p .. "]]",
        "expected " .. str .. " to not match pattern [[" .. p .. "]]"
    end,
  },
}

function lust:expect(v: any): any
  local assertion: any = {}
  assertion.val = v
  assertion.action = ""
  assertion.negate = false

  setmetatable(assertion, {
    __index = function(t: any, k: any)
      if has(paths[rawget(t, "action")], k) then
        rawset(t, "action", k)
        local chain = paths[rawget(t, "action")].chain
        if chain then
          chain(t)
        end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t: any, ...: any)
      if paths[t.action].test then
        local res, err, nerr = paths[t.action].test(t.val, ...)
        if assertion.negate then
          res = not res
          err = nerr or err
        end
        if not res then
          error(err or "unknown failure", 2)
        end
      end
    end,
  })

  return assertion
end

function lust:spy(target: any, name: any, run: any): any
  local spy: any = {}
  local subject: any

  local function capture(...: any): any
    table.insert(spy, { ... })
    return subject(...)
  end

  if type(target) == "table" then
    subject = target[name]
    target[name] = capture
  else
    run = name
    subject = if target then target else function() end
  end

  setmetatable(spy, {
    __call = function(_: any, ...: any): any
      return capture(...)
    end,
  })

  if run then
    run()
  end

  return spy
end

lust.test = lust.it
lust.paths = paths

return lust
