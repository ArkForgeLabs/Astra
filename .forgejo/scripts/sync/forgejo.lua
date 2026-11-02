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
  self.base = config.forgejo_url .. "/api/v1/repos/" .. config.forgejo_repo
  return self
end

function M:encode(value)
  return util.url_encode(value)
end

function M:optional_json(url)
  local response, err = self.client:get_json(url, { auth = "forgejo" })
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
    params = { state = "all", type = "all" },
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:list_pulls()
  return self.client:paginate({
    url = self.base .. "/pulls",
    params = { state = "all" },
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:list_comments()
  return self.client:paginate({
    url = self.base .. "/issues/comments",
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:get_issue(number)
  local response, err = self.client:get_json(self.base .. "/issues/" .. number, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:create_issue(payload)
  local response, err = self.client:post_json(self.base .. "/issues", payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_issue(number, payload)
  local response, err = self.client:patch_json(self.base .. "/issues/" .. number, payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:set_issue_labels(number, labels)
  local response, err = self.client:put_json(
    self.base .. "/issues/" .. number .. "/labels",
    { labels = labels },
    { auth = "forgejo" }
  )
  if not response then
    return nil, err
  end
  return response.json
end

function M:create_comment(number, body)
  local response, err = self.client:post_json(
    self.base .. "/issues/" .. number .. "/comments",
    { body = body },
    { auth = "forgejo" }
  )
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_comment(id, payload)
  local response, err = self.client:patch_json(self.base .. "/issues/comments/" .. id, payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_labels()
  return self.client:paginate({
    url = self.base .. "/labels",
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:create_label(payload)
  local response, err = self.client:post_json(self.base .. "/labels", payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_milestones()
  return self.client:paginate({
    url = self.base .. "/milestones",
    params = { state = "all" },
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:create_milestone(payload)
  local response, err = self.client:post_json(self.base .. "/milestones", payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_tags()
  return self.client:paginate({
    url = self.base .. "/tags",
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:get_tag(tag)
  return self:optional_json(self.base .. "/tags/" .. self:encode(tag))
end

function M:create_tag(tag, sha)
  local response, err = self.client:post_json(
    self.base .. "/tags",
    { tag_name = tag, target = sha },
    { auth = "forgejo" }
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
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:get_release_by_tag(tag)
  return self:optional_json(self.base .. "/releases/tags/" .. self:encode(tag))
end

function M:create_release(payload)
  local response, err = self.client:post_json(self.base .. "/releases", payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:edit_release(id, payload)
  local response, err = self.client:patch_json(self.base .. "/releases/" .. id, payload, { auth = "forgejo" })
  if not response then
    return nil, err
  end
  return response.json
end

function M:list_release_assets(id)
  return self.client:paginate({
    url = self.base .. "/releases/" .. id .. "/assets",
    limit_param = "limit",
    page_size = 50,
    auth = "forgejo",
  })
end

function M:upload_release_asset(id, name, bytes)
  local response, err = self.client:request({
    url = self.base .. "/releases/" .. id .. "/assets?name=" .. self:encode(name),
    method = "POST",
    auth = "forgejo",
    bytes = bytes,
  })
  if not response then
    return nil, err
  end
  return response.json or {}
end

return M
