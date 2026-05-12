local crypto = require("crypto")
local fs = require("fs")
local http = require("http")

local config = require("config")

local server = http.server.new()
server.port = 20001

---@param str string
---@param prefix string
---@return string
local function remove_prefix(str, prefix)
  if str:sub(1, #prefix) == prefix then
    return str:sub(#prefix + 1)
  else
    return str
  end
end

server:post("/", function(request, response)
  local headers = request:headers()
  local bearer_token = remove_prefix((headers["x-authorization"]):lower(), "bearer ")
  local project = headers["x-project"]
  local project_conf = config[project]
  local cd_secret = project_conf.secret
  local multipart = request:multipart()

  local file_name = headers["x-filename"]

  if bearer_token == nil or cd_secret == nil or multipart == nil then
    print("Couldn't find tokens")
    response:set_status_code(http.status_codes.UNAUTHORIZED)
    return
  end

  if crypto.hash("sha3_256", bearer_token) ~= cd_secret then
    print("Wrong secret " .. tostring(cd_secret) .. " vs " .. crypto.hash("sha3_256", bearer_token))
    response:set_status_code(http.status_codes.UNAUTHORIZED)
    return
  end

  -- Directory path for each repository
  local save_path = string.format("%s/%s", project_conf.project_path, file_name)

  local command = project_conf.match[multipart:file_name()]
    or project_conf.match[headers["x-filename"]]
    or project_conf.match[1]
    or "echo Received!"

  multipart:save_file(save_path)

  fs.change_dir(project_conf.project_path)
  os.execute(command)
end, { body_limit = 64 * 1024 * 1024 })

print("🚀 Listening to " .. server.hostname .. ":" .. server.port)

server:run()
