local math_mod = {}

math_mod.pi = math.pi
math_mod.e = math.exp(1)
math_mod.inf = math.huge
math_mod.nan = 0/0

local simple_aliases = {
  "sqrt", "sin", "cos", "tan", "asin", "acos", "atan",
  "sinh", "cosh", "tanh", "ceil", "floor", "abs",
  "fabs", "fmod", "modf", "exp", "log2", "log10",
}
for _, name in ipairs(simple_aliases) do
  math_mod[name] = math[name]
end

math_mod.atan2 = function(y, x) return math.atan(y / x) end
math_mod.trunc = function(x) return x // 1 end
math_mod.log = function(x, base)
  if base then return math.log(x) / math.log(base) else return math.log(x) end
end
math_mod.pow = function(x, y) return x ^ y end
math_mod.degrees = function(x) return x * 180 / math.pi end
math_mod.radians = function(x) return x * math.pi / 180 end
math_mod.hypot = math.hypot or (function(x, y) return math.sqrt(x * x + y * y) end)
math_mod.isclose = function(a, b, rel_tol, abs_tol)
  rel_tol = rel_tol or 1e-9
  abs_tol = abs_tol or 0.0
  return math.abs(a - b) <= rel_tol * math.max(math.abs(a), math.abs(b)) + abs_tol
end
math_mod.gcd = function(a, b)
  while b ~= 0 do a, b = b, a % b end
  return math.abs(a)
end
math_mod.ldexp = function(m, e) return m * (2 ^ e) end
math_mod.frexp = function(x)
  if x == 0 then return 0, 0 end
  local e = 0
  local s = x < 0 and -1 or 1
  x = math.abs(x)
  while x < 1 do x = x * 2 e = e - 1 end
  while x >= 2 do x = x / 2 e = e + 1 end
  return s * x, e
end
math_mod.factorial = function(x)
  if x < 2 then return 1 end
  local r = 1
  for i = 2, x do r = r * i end
  return r
end
math_mod.isfinite = function(x)
  return x ~= math.huge and x ~= -math.huge and x == x
end
math_mod.isinf = function(x)
  return x == math.huge or x == -math.huge
end
math_mod.isnan = function(x) return x ~= x end
math_mod.copysign = function(x, y)
  return math.abs(x) * (y < 0 and -1 or 1)
end

local function _gamma(x)
  local g = 7
  local c = {0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7}
  if x < 0.5 then
    return math.pi / (math.sin(math.pi * x) * _gamma(1 - x))
  end
  x = x - 1
  local a = c[1]
  local t = x + g + 0.5
  for i = 2, #c do
    a = a + c[i] / (x + i - 1)
  end
  return math.sqrt(2 * math.pi) * t ^ (x + 0.5) * math.exp(-t) * a
end
math_mod.gamma = _gamma
math_mod.lgamma = function(x) return math.log(_gamma(x)) end

return math_mod