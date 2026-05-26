local ast = require("python.ast")
local fs = require("fs")
local generator = require("python.generator")
local optimizer = require("python.optimizer")
local parser = require("python.parser")
local stdlib = require("python.stdlib")
local tokenizer = require("python.tokenizer")
local util = require("python.util")
local walker = require("python.optimizer.ast_walker")

local import = {}
local processed_modules
local module_cache = {}

local cache_key = function(py_path)
  local meta = fs.get_metadata(py_path)
  return py_path .. ":" .. (meta and tostring(meta:last_modified()) or "0")
end

local function add_to_path(dir)
  local sep = fs.get_separator()
  local pattern1 = dir .. sep .. "?.lua"
  local pattern2 = dir .. sep .. "?" .. sep .. "init.lua"
  if not package.path:find(pattern1, 1, true) then
    package.path = pattern1 .. ";" .. pattern2 .. ";" .. package.path
  end
end

local function is_builtin(name)
  local top = util.get_top_level(name)
  if not top then return false end
  local lua_modules = {
    math = true, string = true, table = true, io = true, os = true,
    debug = true, coroutine = true, utf8 = true,
  }
  return stdlib.map[top] ~= nil or lua_modules[top]
end

local function resolve_module(name, search_dirs)
  local parts = {}
  for part in name:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  if #parts == 0 then return nil end

  for _, dir in ipairs(search_dirs) do
    local subpath = table.concat(parts, "/")

    local py_path = dir .. "/" .. subpath .. ".py"
    if fs.exists(py_path) then
      return py_path, py_path:gsub("%.py$", ".lua")
    end

    py_path = dir .. "/" .. subpath .. "/__init__.py"
    if fs.exists(py_path) then
      return py_path, dir .. "/" .. subpath .. "/init.lua"
    end
  end

  return nil
end

local function collect_import_names(prog)
  local names = {}
  walker.walk_all_bodies(prog, {
    visit_node = function(stmt)
      if stmt.type == ast.IMPORT then
        for _, n in ipairs(stmt.names) do
          if n.name ~= "*" then
            names[n.name] = true
          end
        end
      elseif stmt.type == ast.IMPORT_FROM then
        names[stmt.module] = true
      end
    end,
  })
  return names
end

local function resolve_package_chain(name, search_dirs)
  local parts = {}
  for part in name:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end

  local results = {}
  for i = 1, #parts do
    local prefix = table.concat(parts, ".", 1, i)
    if not processed_modules[prefix] and not is_builtin(prefix) then
      local py_path, lua_path = resolve_module(prefix, search_dirs)
      if py_path then
        results[#results + 1] = {
          name = prefix,
          py_path = py_path,
          lua_path = lua_path,
        }
        processed_modules[prefix] = true
      end
    end
  end
  return results
end

local function collect_module_exports(prog)
  local exports = {}
  for _, stmt in ipairs(prog.body) do
    if stmt.type == ast.FUNCTION_DEF or stmt.type == ast.ASYNC_FUNCTION_DEF then
      exports[stmt.name] = true
    elseif stmt.type == ast.CLASS_DEF then
      exports[stmt.name] = true
    elseif stmt.type == ast.ASSIGN then
      for _, target in ipairs(stmt.targets) do
        if target.type == ast.NAME then
          exports[target.id] = true
        end
      end
    elseif stmt.type == ast.IMPORT then
      for _, n in ipairs(stmt.names) do
        if n.name ~= "*" then
          local alias = n.as_name or util.get_top_level(n.name)
          if alias then exports[alias] = true end
        end
      end
    elseif stmt.type == ast.IMPORT_FROM then
      for _, n in ipairs(stmt.names) do
        if n.name ~= "*" then
          exports[n.as_name or n.name] = true
        end
      end
    end
  end
  local sorted = {}
  for name in pairs(exports) do
    sorted[#sorted + 1] = name
  end
  table.sort(sorted)
  return sorted
end

---@param source string
---@param opts? table
---@return string, ast.Program
function import.transpile_source(source, opts)
  opts = opts or {}
  local tokens = tokenizer.tokenize(source)
  local prog = parser.parse(tokens)
  local analysis = optimizer.analyze(prog, opts)
  return generator.generate(prog, analysis), prog
end

local function transpile_module(py_path, lua_path, opts)
  local ck = cache_key(py_path)
  if module_cache[ck] then
    local cached = module_cache[ck]
    local lua_code = cached.lua_code
    local prog = cached.prog
    local import_names = collect_import_names(prog)
    for name in pairs(import_names) do
      if not is_builtin(name) then
        local chain = resolve_package_chain(name, { util.dirname(py_path) })
        for _, item in ipairs(chain) do
          transpile_module(item.py_path, item.lua_path, opts)
        end
      end
    end
    return
  end

  local source = fs.read_file(py_path)
  local lua_code, prog = import.transpile_source(source, opts)

  local exports = collect_module_exports(prog)
  if #exports > 0 then
    local parts = {}
    for _, name in ipairs(exports) do
      parts[#parts + 1] = name .. " = " .. name
    end
    lua_code = lua_code .. "\nreturn { " .. table.concat(parts, ", ") .. " }\n"
  end

  local out_dir = util.dirname(lua_path)
  if not fs.exists(out_dir) then
    fs.create_dir_all(out_dir)
  end

  fs.write_file(lua_path, lua_code)

  module_cache[ck] = { lua_code = lua_code, prog = prog }

  local import_names = collect_import_names(prog)
  for name in pairs(import_names) do
    if not is_builtin(name) then
      local chain = resolve_package_chain(name, { util.dirname(py_path) })
      for _, item in ipairs(chain) do
        transpile_module(item.py_path, item.lua_path, opts)
      end
    end
  end
end

---@param prog ast.Program
---@param cwd string
---@param opts? table
function import.resolve(prog, cwd, opts)
  opts = opts or {}
  processed_modules = {}
  local search_dirs = {}
  if opts.path then
    for _, p in ipairs(opts.path) do
      search_dirs[#search_dirs + 1] = p
      add_to_path(p)
    end
  end
  search_dirs[#search_dirs + 1] = cwd
  add_to_path(cwd)

  local import_names = collect_import_names(prog)
  for name in pairs(import_names) do
    if not is_builtin(name) then
      local chain = resolve_package_chain(name, search_dirs)
      for _, item in ipairs(chain) do
        transpile_module(item.py_path, item.lua_path, opts)
      end
    end
  end
end

return import
