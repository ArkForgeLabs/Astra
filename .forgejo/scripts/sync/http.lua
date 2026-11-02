local M = {}
M.__index = M

local util

function M.init(deps)
  util = deps.util
end

function M.new(config)
  return setmetatable({ config = config }, M)
end

local function json_encode(value)
  return astra_internal__json_encode(value)
end

local function json_decode(value)
  return astra_internal__json_decode(value)
end

local function sleep(ms)
  if ms and ms > 0 then
    astra_internal__datetime_sleep(ms)
  end
end

function M:request(opts)
  local headers = {}
  for key, value in pairs(opts.headers or {}) do
    headers[key] = value
  end

  headers["User-Agent"] = headers["User-Agent"] or self.config.user_agent
  headers["Accept"] = opts.accept or headers["Accept"] or "application/json"

  if opts.auth == "github" then
    headers["Accept"] = opts.accept or "application/vnd.github+json"
    headers["X-GitHub-Api-Version"] = "2022-11-28"
    if self.config.github_token then
      headers["Authorization"] = "token " .. self.config.github_token
    end
  elseif opts.auth == "forgejo" then
    if self.config.forgejo_token then
      headers["Authorization"] = "token " .. self.config.forgejo_token
    end
  end

  local max_retries = opts.retries or self.config.retries or 3
  local attempt = 0

  while true do
    attempt = attempt + 1
    local details = {
      url = opts.url,
      method = opts.method or "GET",
      headers = headers,
    }

    if opts.bytes ~= nil then
      details.body = opts.bytes
      headers["Content-Type"] = headers["Content-Type"] or "application/octet-stream"
    elseif opts.json ~= nil then
      details.body = json_encode(opts.json)
      headers["Content-Type"] = headers["Content-Type"] or "application/json"
    elseif opts.raw_json ~= nil then
      details.body = opts.raw_json
      headers["Content-Type"] = headers["Content-Type"] or "application/json"
    elseif opts.body ~= nil then
      details.body = opts.body
    end

    local ok, result = pcall(function()
      return astra_internal__http_request(details):execute()
    end)

    if not ok then
      if attempt <= max_retries then
        local delay = self:retry_delay(attempt, nil)
        util.warn("request failed (%s %s): %s; retrying in %dms", details.method, opts.url, tostring(result), delay)
        sleep(delay)
      else
        return nil, string.format("request failed (%s %s): %s", details.method, opts.url, tostring(result))
      end
    else
      local status = result:status_code()
      if self:is_success(status, opts.allow_status) then
        return self:build_response(result, opts)
      end

      local body_text = ""
      local body_ok, body = pcall(function()
        return result:body():text()
      end)
      if body_ok then
        body_text = body
      end

      if self:should_retry(status, result) and attempt <= max_retries then
        local delay = self:retry_delay(attempt, result)
        util.warn("%s %s -> %d: %s; retrying in %dms", details.method, opts.url, status, body_text:sub(1, 300), delay)
        sleep(delay)
      else
        return nil, string.format("%s %s -> %d: %s", details.method, opts.url, status, body_text:sub(1, 1000))
      end
    end
  end
end

function M:is_success(status, allowed)
  if allowed then
    for _, value in ipairs(allowed) do
      if status == value then
        return true
      end
    end
  end
  return status >= 200 and status < 300
end

function M:should_retry(status, response)
  if status == 429 then
    return true
  end
  if status >= 500 and status <= 599 then
    return true
  end
  if status == 403 then
    local headers = response:headers() or {}
    local remaining = headers["x-ratelimit-remaining"]
    if remaining and tonumber(remaining) == 0 then
      return true
    end
  end
  return false
end

function M:retry_delay(attempt, response)
  local headers = response and response:headers() or {}
  local retry_after = headers["retry-after"]
  if retry_after then
    local seconds = tonumber(retry_after)
    if seconds then
      return math.min(seconds * 1000, 60000)
    end
  end

  local reset = headers["x-ratelimit-reset"]
  if reset then
    local reset_at = tonumber(reset)
    if reset_at then
      local delay = (reset_at - os.time()) * 1000
      if delay > 0 then
        return math.min(delay, 60000)
      end
    end
  end

  return math.min(1000 * (2 ^ (attempt - 1)), 30000)
end

function M:build_response(response, opts)
  local result = {
    status = response:status_code(),
    headers = response:headers() or {},
  }

  if opts.raw then
    result.bytes = response:body():bytes()
    return result
  end

  local text = response:body():text()
  result.text = text
  if opts.parse_json ~= false and text ~= "" then
    local ok, decoded = pcall(function()
      return json_decode(text)
    end)
    if ok then
      result.json = decoded
    end
  end
  return result
end

function M:paginate(opts)
  local items = {}
  local page = 1
  local page_size = opts.page_size or 100
  local max_pages = opts.max_pages or 200
  local limit_param = opts.limit_param or "per_page"

  while page <= max_pages do
    local params = {}
    for key, value in pairs(opts.params or {}) do
      params[key] = value
    end
    params[limit_param] = page_size
    params.page = page

    local url = util.build_query(opts.url, params)
    local response, err = self:request({
      url = url,
      method = "GET",
      auth = opts.auth,
      accept = opts.accept,
      parse_json = true,
    })
    if not response then
      return nil, err
    end
    if type(response.json) ~= "table" then
      return nil, "expected a JSON array from " .. url
    end

    for _, item in ipairs(response.json) do
      items[#items + 1] = item
    end

    if #response.json < page_size then
      break
    end
    page = page + 1
  end

  return items
end

function M:get_json(url, opts)
  opts = opts or {}
  return self:request({
    url = url,
    method = "GET",
    auth = opts.auth,
    accept = opts.accept,
    parse_json = true,
  })
end

function M:get_bytes(url, opts)
  opts = opts or {}
  return self:request({
    url = url,
    method = "GET",
    auth = opts.auth,
    accept = opts.accept or "application/octet-stream",
    raw = true,
    parse_json = false,
  })
end

function M:post_json(url, payload, opts)
  opts = opts or {}
  return self:request({
    url = url,
    method = "POST",
    auth = opts.auth,
    accept = opts.accept,
    json = payload,
  })
end

function M:patch_json(url, payload, opts)
  opts = opts or {}
  return self:request({
    url = url,
    method = "PATCH",
    auth = opts.auth,
    accept = opts.accept,
    json = payload,
  })
end

function M:put_json(url, payload, opts)
  opts = opts or {}
  return self:request({
    url = url,
    method = "PUT",
    auth = opts.auth,
    accept = opts.accept,
    json = payload,
  })
end

return M
