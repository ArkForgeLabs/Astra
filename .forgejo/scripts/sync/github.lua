local M = {}
M.__index = M

local util

function M.init(deps)
  util = deps.util
end

function M.new(client, config)
  local self = setmetatable({
    client = client,
    config = config,
  }, M)
  self.base = config.github_api_url .. "/repos/" .. config.github_repo
  return self
end

function M:encode(value)
  return util.url_encode(value)
end

function M:optional_json(url)
  local response, err = self.client:get_json(url, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    if err and err:match(" %-> 404:") then
      return nil
    end
    return nil, err
  end
  return response.json
end

function M:list_issues()
  return self.client:paginate({
    url = self.base .. "/issues",
    params = { state = "all" },
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:list_pulls()
  return self.client:paginate({
    url = self.base .. "/pulls",
    params = { state = "all" },
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:list_comments()
  return self.client:paginate({
    url = self.base .. "/issues/comments",
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:get_issue(number)
  local response, err = self.client:get_json(self.base .. "/issues/" .. number, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:create_issue(payload)
  local response, err = self.client:post_json(self.base .. "/issues", payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_issue(number, payload, clear_milestone)
  local url = self.base .. "/issues/" .. number
  if clear_milestone then
    local encoded = astra_internal__json_encode(payload)
    if encoded:match("^%s*%[%s*%]%s*$") then
      encoded = "{}"
    end
    if encoded:match("^%s*{}%s*$") then
      encoded = '{"milestone":null}'
    else
      encoded = encoded:gsub("}%s*$", ',"milestone":null}')
    end
    local response, err = self.client:request({
      url = url,
      method = "PATCH",
      auth = "github",
      accept = "application/vnd.github+json",
      raw_json = encoded,
    })
    if not response then
      return nil, err
    end
    return response.json
  end

  local response, err = self.client:patch_json(url, payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:create_comment(number, body)
  local response, err = self.client:post_json(
    self.base .. "/issues/" .. number .. "/comments",
    { body = body },
    { auth = "github", accept = "application/vnd.github+json" }
  )
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_comment(id, payload)
  local response, err = self.client:patch_json(
    self.base .. "/issues/comments/" .. id,
    payload,
    { auth = "github", accept = "application/vnd.github+json" }
  )
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_labels()
  return self.client:paginate({
    url = self.base .. "/labels",
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:create_label(payload)
  local response, err = self.client:post_json(self.base .. "/labels", payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_milestones()
  return self.client:paginate({
    url = self.base .. "/milestones",
    params = { state = "all" },
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:create_milestone(payload)
  local response, err = self.client:post_json(self.base .. "/milestones", payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_tags()
  return self.client:paginate({
    url = self.base .. "/tags",
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:get_tag(tag)
  return self:optional_json(self.base .. "/tags/" .. self:encode(tag))
end

function M:create_tag(tag, sha)
  local response, err = self.client:post_json(
    self.base .. "/git/refs",
    { ref = "refs/tags/" .. tag, sha = sha },
    { auth = "github", accept = "application/vnd.github+json" }
  )
  if not response then
    return nil, err
  end
  return response.json
end

function M:get_commit(sha)
  return self:optional_json(self.base .. "/git/commits/" .. self:encode(sha))
end

function M:list_releases()
  return self.client:paginate({
    url = self.base .. "/releases",
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:get_release_by_tag(tag)
  return self:optional_json(self.base .. "/releases/tags/" .. self:encode(tag))
end

function M:create_release(payload)
  local response, err = self.client:post_json(self.base .. "/releases", payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_release(id, payload)
  local response, err = self.client:patch_json(self.base .. "/releases/" .. id, payload, {
    auth = "github",
    accept = "application/vnd.github+json",
  })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_release_assets(id)
  return self.client:paginate({
    url = self.base .. "/releases/" .. id .. "/assets",
    limit_param = "per_page",
    page_size = 100,
    auth = "github",
    accept = "application/vnd.github+json",
  })
end

function M:download_release_asset(id)
  local response, err = self.client:get_bytes(
    self.base .. "/releases/assets/" .. id,
    { auth = "github", accept = "application/octet-stream" }
  )
  if not response then
    return nil, err
  end
  return response.bytes
end

return M
