local M = {}

local util
local markers

function M.init(deps)
  util = deps.util
  markers = deps.markers
end

local function is_pull(issue)
  return issue.pull_request ~= nil
end

local function index_by_number(list)
  local map = {}
  for _, item in ipairs(list or {}) do
    if item.number then
      map[item.number] = item
    end
  end
  return map
end

local function label_map(labels)
  local map = {}
  for _, label in ipairs(labels or {}) do
    if label.name then
      map[label.name] = label
    end
  end
  return map
end

local function milestone_map(milestones)
  local map = {}
  for _, milestone in ipairs(milestones or {}) do
    if milestone.title then
      map[milestone.title] = milestone
    end
  end
  return map
end

local function find_marker(namespace, side, body)
  if side == "forgejo" then
    return markers.find_issue(namespace, body, "github")
  end
  return markers.find_issue(namespace, body, "forgejo")
end

local function marker_for(namespace, target_side, source_number, hash)
  if target_side == "github" then
    return markers.issue(namespace, "forgejo", source_number, hash)
  end
  return markers.issue(namespace, "github", source_number, hash)
end

local function fetch_state(ctx)
  local fj_issues, err = ctx.fj:list_issues()
  if not fj_issues then
    return nil, err
  end
  local gh_issues, err = ctx.gh:list_issues()
  if not gh_issues then
    return nil, err
  end

  local fj = {}
  for _, issue in ipairs(fj_issues) do
    if not is_pull(issue) then
      fj[#fj + 1] = issue
    end
  end
  local gh = {}
  for _, issue in ipairs(gh_issues) do
    if not is_pull(issue) then
      gh[#gh + 1] = issue
    end
  end

  local fj_labels, err = ctx.fj:list_labels()
  if not fj_labels then
    return nil, err
  end
  local gh_labels, err = ctx.gh:list_labels()
  if not gh_labels then
    return nil, err
  end
  local fj_milestones, err = ctx.fj:list_milestones()
  if not fj_milestones then
    return nil, err
  end
  local gh_milestones, err = ctx.gh:list_milestones()
  if not gh_milestones then
    return nil, err
  end

  return {
    fj = fj,
    gh = gh,
    fj_by_number = index_by_number(fj),
    gh_by_number = index_by_number(gh),
    fj_labels = label_map(fj_labels),
    gh_labels = label_map(gh_labels),
    fj_milestones = milestone_map(fj_milestones),
    gh_milestones = milestone_map(gh_milestones),
    pairs = {},
  }
end

local function marker_pair(ctx, state)
  local namespace = ctx.namespace
  local pairs = {}
  local used_fj, used_gh = {}, {}
  local orphan_fj, orphan_gh = {}, {}
  local blocked_fj, blocked_gh = {}, {}

  for _, fj in ipairs(state.fj) do
    local marker = markers.find_issue(namespace, fj.body, "github")
    if marker then
      local gh = state.gh_by_number[marker.issue]
      if not gh then
        orphan_fj[fj.number] = true
        ctx:warn("Forgejo issue #%d points to missing GitHub issue #%d; treating as orphan", fj.number, marker.issue)
      elseif used_gh[gh.number] then
        blocked_fj[fj.number] = true
        ctx:warn("Forgejo issue #%d points to already-paired GitHub issue #%d", fj.number, gh.number)
      else
        local gh_marker = markers.find_issue(namespace, gh.body, "forgejo")
        if gh_marker and gh_marker.issue ~= fj.number then
          blocked_fj[fj.number] = true
          blocked_gh[gh.number] = true
          ctx:error(
            "marker mismatch: Forgejo #%d -> GitHub #%d, GitHub #%d -> Forgejo #%d",
            fj.number,
            gh.number,
            gh.number,
            gh_marker.issue
          )
        else
          pairs[#pairs + 1] = { fj = fj, gh = gh }
          used_fj[fj.number] = true
          used_gh[gh.number] = true
        end
      end
    end
  end

  for _, gh in ipairs(state.gh) do
    if not used_gh[gh.number] then
      local marker = markers.find_issue(namespace, gh.body, "forgejo")
      if marker then
        local fj = state.fj_by_number[marker.issue]
        if not fj then
          orphan_gh[gh.number] = true
          ctx:warn("GitHub issue #%d points to missing Forgejo issue #%d; treating as orphan", gh.number, marker.issue)
        elseif used_fj[fj.number] then
          blocked_gh[gh.number] = true
          ctx:warn("GitHub issue #%d points to already-paired Forgejo issue #%d", gh.number, fj.number)
        else
          local fj_marker = markers.find_issue(namespace, fj.body, "github")
          if fj_marker and fj_marker.issue ~= gh.number then
            blocked_fj[fj.number] = true
            blocked_gh[gh.number] = true
            ctx:error(
              "marker mismatch: GitHub #%d -> Forgejo #%d, Forgejo #%d -> GitHub #%d",
              gh.number,
              fj.number,
              fj.number,
              fj_marker.issue
            )
          else
            pairs[#pairs + 1] = { fj = fj, gh = gh }
            used_fj[fj.number] = true
            used_gh[gh.number] = true
          end
        end
      end
    end
  end

  return pairs, used_fj, used_gh, orphan_fj, orphan_gh, blocked_fj, blocked_gh
end

local function unused_title_matches(state, key, used_fj, orphan_fj, blocked_fj)
  local matches = {}
  for _, fj in ipairs(state.fj) do
    if
      not used_fj[fj.number]
      and not orphan_fj[fj.number]
      and not blocked_fj[fj.number]
      and util.normalize_title(fj.title) == key
    then
      matches[#matches + 1] = fj
    end
  end
  return matches
end

local function title_pair(ctx, state, used_fj, used_gh, orphan_fj, orphan_gh, blocked_fj, blocked_gh)
  local pairs = {}
  for _, gh in ipairs(state.gh) do
    if not used_gh[gh.number] and not orphan_gh[gh.number] and not blocked_gh[gh.number] then
      local key = util.normalize_title(gh.title)
      local candidates = unused_title_matches(state, key, used_fj, orphan_fj, blocked_fj)
      if #candidates == 1 then
        local fj = candidates[1]
        pairs[#pairs + 1] = { fj = fj, gh = gh }
        used_fj[fj.number] = true
        used_gh[gh.number] = true
      elseif #candidates > 1 then
        local same
        for _, fj in ipairs(candidates) do
          if fj.number == gh.number then
            same = fj
            break
          end
        end
        if same then
          pairs[#pairs + 1] = { fj = same, gh = gh }
          used_fj[same.number] = true
          used_gh[gh.number] = true
        else
          blocked_gh[gh.number] = true
          for _, fj in ipairs(candidates) do
            blocked_fj[fj.number] = true
          end
          ctx:warn("ambiguous issue title %q for GitHub #%d; leaving unpaired", gh.title, gh.number)
        end
      end
    end
  end
  return pairs
end

local function ensure_label(ctx, state, source, target_side)
  local target_map = target_side == "github" and state.gh_labels or state.fj_labels
  local api = target_side == "github" and ctx.gh or ctx.fj

  for _, label in ipairs(source.labels or {}) do
    local name = type(label) == "table" and label.name or tostring(label)
    if name and name ~= "" and not target_map[name] then
      local payload = {
        name = name,
        color = ((type(label) == "table" and label.color) or "ededed"):gsub("#", ""),
        description = (type(label) == "table" and label.description) or "",
      }
      if ctx.dry_run then
        ctx:plan("create %s label %q", target_side, name)
        target_map[name] = { name = name }
      else
        local created, err = api:create_label(payload)
        if created then
          target_map[name] = created
          ctx.stats.created = ctx.stats.created + 1
          ctx:info("created %s label %q", target_side, name)
        elseif err and (err:match(" %-> 422:") or err:match(" %-> 409:")) then
          local labels, list_err = api:list_labels()
          if labels then
            if target_side == "github" then
              state.gh_labels = label_map(labels)
              target_map = state.gh_labels
            else
              state.fj_labels = label_map(labels)
              target_map = state.fj_labels
            end
          else
            ctx:error("could not refresh %s labels: %s", target_side, list_err)
          end
        else
          ctx:error("could not create %s label %q: %s", target_side, name, tostring(err))
        end
      end
    end
  end
end

local function ensure_milestone(ctx, state, source, target_side)
  local title = util.milestone_title(source)
  if not title then
    return
  end

  local target_map = target_side == "github" and state.gh_milestones or state.fj_milestones
  if target_map[title] then
    return
  end

  local api = target_side == "github" and ctx.gh or ctx.fj
  local source_milestone = source.milestone
  local payload = {
    title = title,
    state = source_milestone.state or "open",
    description = source_milestone.description or "",
  }
  if source_milestone.due_on then
    payload.due_on = source_milestone.due_on
  end

  if ctx.dry_run then
    ctx:plan("create %s milestone %q", target_side, title)
    target_map[title] = { title = title, id = -1, number = -1 }
    return
  end

  local created, err = api:create_milestone(payload)
  if created then
    target_map[title] = created
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created %s milestone %q", target_side, title)
  elseif err and (err:match(" %-> 422:") or err:match(" %-> 409:")) then
    local milestones, list_err = api:list_milestones()
    if milestones then
      if target_side == "github" then
        state.gh_milestones = milestone_map(milestones)
      else
        state.fj_milestones = milestone_map(milestones)
      end
    else
      ctx:error("could not refresh %s milestones: %s", target_side, list_err)
    end
  else
    ctx:error("could not create %s milestone %q: %s", target_side, title, tostring(err))
  end
end

local function ensure_marker(ctx, side, issue, other_number, hash)
  local existing = find_marker(ctx.namespace, side, issue.body)
  if existing and existing.issue == other_number and existing.hash == hash then
    return
  end

  local marker = marker_for(ctx.namespace, side, other_number, hash)
  local body = markers.set(ctx.namespace, issue.body, marker)

  if ctx.dry_run then
    ctx:plan("update %s issue #%d sync marker", side, issue.number)
    return
  end

  local api = side == "forgejo" and ctx.fj or ctx.gh
  local updated, err = api:edit_issue(issue.number, { body = body })
  if not updated then
    ctx:error("could not update %s issue #%d marker: %s", side, issue.number, tostring(err))
    return
  end
  issue.body = body
end

local function apply_issue(ctx, state, source, target, source_side, target_side)
  local source_body = markers.strip(ctx.namespace, source.body or "")
  local target_body = markers.strip(ctx.namespace, target.body or "")
  local source_labels = util.issue_labels(source)
  local target_labels = util.issue_labels(target)
  local source_milestone = util.milestone_title(source)
  local target_milestone = util.milestone_title(target)
  local hash = util.issue_hash(source, source_body)

  ensure_label(ctx, state, source, target_side)
  ensure_milestone(ctx, state, source, target_side)

  local target_marker = find_marker(ctx.namespace, target_side, target.body)
  local marker_needs_update = target_marker == nil or target_marker.issue ~= source.number or target_marker.hash ~= hash
  local title_changed = util.normalize_title(source.title) ~= util.normalize_title(target.title)
  local body_changed = util.normalize_body(source_body) ~= util.normalize_body(target_body)
  local state_changed = source.state ~= target.state
  local labels_changed = table.concat(source_labels, "\0") ~= table.concat(target_labels, "\0")
  local milestone_changed = (source_milestone or "") ~= (target_milestone or "")

  if
    not title_changed
    and not body_changed
    and not state_changed
    and not labels_changed
    and not milestone_changed
    and not marker_needs_update
  then
    ensure_marker(ctx, source_side, source, target.number, hash)
    return
  end

  local new_target_body =
    markers.set(ctx.namespace, source_body, marker_for(ctx.namespace, target_side, source.number, hash))

  local payload = {}
  if title_changed then
    payload.title = source.title
  end
  if body_changed or marker_needs_update then
    payload.body = new_target_body
  end
  if state_changed then
    payload.state = source.state
  end
  if labels_changed then
    if target_side == "github" then
      payload.labels = source_labels
    end
  end

  local clear_milestone = false
  if milestone_changed then
    if target_side == "github" then
      if source_milestone then
        local milestone = state.gh_milestones[source_milestone]
        if not milestone then
          ctx:error("could not resolve GitHub milestone %q for issue #%d", source_milestone, target.number)
          return
        end
        payload.milestone = milestone.number
      else
        clear_milestone = true
      end
    elseif source_milestone then
      local milestone = state.fj_milestones[source_milestone]
      if not milestone then
        ctx:error("could not resolve Forgejo milestone %q for issue #%d", source_milestone, target.number)
        return
      end
      payload.milestone = milestone.id
    else
      payload.milestone = 0
    end
  end

  if ctx.dry_run then
    ctx:plan("update %s issue #%d from %s #%d", target_side, target.number, source_side, source.number)
  else
    local api = target_side == "github" and ctx.gh or ctx.fj
    local should_edit = target_side == "github" or next(payload) ~= nil
    if should_edit then
      local updated, err
      if target_side == "github" then
        updated, err = api:edit_issue(target.number, payload, clear_milestone)
      else
        updated, err = api:edit_issue(target.number, payload)
      end
      if not updated then
        ctx:error("could not update %s issue #%d: %s", target_side, target.number, tostring(err))
        return
      end
    end
    if labels_changed and target_side == "forgejo" then
      local labels_updated, labels_err = api:set_issue_labels(target.number, source_labels)
      if not labels_updated then
        ctx:error("could not update Forgejo issue #%d labels: %s", target.number, tostring(labels_err))
        return
      end
    end

    target.title = source.title
    target.body = new_target_body
    target.state = source.state
    target.labels = source.labels
    target.milestone = source.milestone
    ctx.stats.updated = ctx.stats.updated + 1
    ctx:info("updated %s issue #%d from %s #%d", target_side, target.number, source_side, source.number)
  end

  ensure_marker(ctx, source_side, source, target.number, hash)
end

local function create_issue(ctx, state, source, source_side, target_side)
  local source_body = markers.strip(ctx.namespace, source.body or "")
  local source_labels = util.issue_labels(source)
  local source_milestone = util.milestone_title(source)
  local hash = util.issue_hash(source, source_body)

  ensure_label(ctx, state, source, target_side)
  ensure_milestone(ctx, state, source, target_side)

  local body = markers.set(ctx.namespace, source_body, marker_for(ctx.namespace, target_side, source.number, hash))

  if target_side == "github" then
    if ctx.dry_run then
      ctx:plan("create GitHub issue from Forgejo #%d (%q)", source.number, source.title)
      return
    end
    local payload = {
      title = source.title,
      body = body,
      labels = source_labels,
    }
    if source_milestone then
      local milestone = state.gh_milestones[source_milestone]
      if not milestone then
        ctx:error("could not resolve GitHub milestone %q for Forgejo #%d", source_milestone, source.number)
        return
      end
      payload.milestone = milestone.number
    end
    local created, err = ctx.gh:create_issue(payload)
    if not created then
      ctx:error("could not create GitHub issue from Forgejo #%d: %s", source.number, tostring(err))
      return
    end
    if source.state == "closed" then
      local closed, close_err = ctx.gh:edit_issue(created.number, { state = "closed" })
      if not closed then
        ctx:error("could not close GitHub issue #%d: %s", created.number, tostring(close_err))
      end
    end
    state.gh[#state.gh + 1] = created
    state.gh_by_number[created.number] = created
    state.pairs[#state.pairs + 1] = { fj = source, gh = created }
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created GitHub issue #%d from Forgejo #%d", created.number, source.number)
    ensure_marker(ctx, "forgejo", source, created.number, hash)
  else
    if ctx.dry_run then
      ctx:plan("create Forgejo issue from GitHub #%d (%q)", source.number, source.title)
      return
    end
    local payload = {
      title = source.title,
      body = body,
      closed = source.state == "closed",
    }
    if source_milestone then
      local milestone = state.fj_milestones[source_milestone]
      if not milestone then
        ctx:error("could not resolve Forgejo milestone %q for GitHub #%d", source_milestone, source.number)
        return
      end
      payload.milestone = milestone.id
    end
    local created, err = ctx.fj:create_issue(payload)
    if not created then
      ctx:error("could not create Forgejo issue from GitHub #%d: %s", source.number, tostring(err))
      return
    end
    if #source_labels > 0 then
      local labels_set, labels_err = ctx.fj:set_issue_labels(created.number, source_labels)
      if not labels_set then
        ctx:error("could not set labels on Forgejo issue #%d: %s", created.number, tostring(labels_err))
      end
    end
    state.fj[#state.fj + 1] = created
    state.fj_by_number[created.number] = created
    state.pairs[#state.pairs + 1] = { fj = created, gh = source }
    ctx.stats.created = ctx.stats.created + 1
    ctx:info("created Forgejo issue #%d from GitHub #%d", created.number, source.number)
    ensure_marker(ctx, "github", source, created.number, hash)
  end
end

local function sync_pair(ctx, state, pair)
  local fj_body = markers.strip(ctx.namespace, pair.fj.body or "")
  local gh_body = markers.strip(ctx.namespace, pair.gh.body or "")
  local fj_hash = util.issue_hash(pair.fj, fj_body)
  local gh_hash = util.issue_hash(pair.gh, gh_body)
  local fj_marker = markers.find_issue(ctx.namespace, pair.fj.body, "github")
  local gh_marker = markers.find_issue(ctx.namespace, pair.gh.body, "forgejo")
  local direction = util.decide_direction(fj_hash, fj_marker and fj_marker.hash, gh_hash, gh_marker and gh_marker.hash)

  if direction == "forgejo" then
    apply_issue(ctx, state, pair.fj, pair.gh, "forgejo", "github")
  elseif direction == "github" then
    apply_issue(ctx, state, pair.gh, pair.fj, "github", "forgejo")
  else
    ensure_marker(ctx, "forgejo", pair.fj, pair.gh.number, fj_hash)
    ensure_marker(ctx, "github", pair.gh, pair.fj.number, gh_hash)
  end
end

function M.sync(ctx, opts)
  opts = opts or {}
  local state, err = fetch_state(ctx)
  if not state then
    ctx:error("could not load issues: %s", tostring(err))
    return nil
  end

  local pairs, used_fj, used_gh, orphan_fj, orphan_gh, blocked_fj, blocked_gh = marker_pair(ctx, state)
  for _, pair in ipairs(title_pair(ctx, state, used_fj, used_gh, orphan_fj, orphan_gh, blocked_fj, blocked_gh)) do
    pairs[#pairs + 1] = pair
  end
  state.pairs = pairs

  for _, pair in ipairs(pairs) do
    if not opts.only_number or pair.fj.number == opts.only_number or pair.gh.number == opts.only_number then
      sync_pair(ctx, state, pair)
    end
  end

  for _, issue in ipairs(state.fj) do
    if
      not used_fj[issue.number]
      and not orphan_fj[issue.number]
      and not blocked_fj[issue.number]
      and (not opts.only_number or issue.number == opts.only_number)
    then
      create_issue(ctx, state, issue, "forgejo", "github")
    end
  end

  for _, issue in ipairs(state.gh) do
    if
      not used_gh[issue.number]
      and not orphan_gh[issue.number]
      and not blocked_gh[issue.number]
      and (not opts.only_number or issue.number == opts.only_number)
    then
      create_issue(ctx, state, issue, "github", "forgejo")
    end
  end

  return state
end

return M
