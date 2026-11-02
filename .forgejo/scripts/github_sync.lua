local argv = arg or {}
local script_path = argv[0] or ".forgejo/scripts/github_sync.lua"
local script_dir = script_path:match("^(.*)/") or "."
package.path = package.path .. ";" .. script_dir .. "/?.lua"

local assets = require("sync.assets")
local comments = require("sync.comments")
local forgejo = require("sync.forgejo")
local github = require("sync.github")
local http = require("sync.http")
local issues = require("sync.issues")
local markers = require("sync.markers")
local releases = require("sync.releases")
local sync = require("sync.init")
local util = require("sync.util")

http.init({ util = util })
forgejo.init({ util = util })
github.init({ util = util })
assets.init({ util = util })
issues.init({ util = util, markers = markers })
comments.init({ util = util, markers = markers })
releases.init({ util = util, assets = assets })
sync.setup({
  util = util,
  markers = markers,
  http = http,
  forgejo = forgejo,
  github = github,
  assets = assets,
  issues = issues,
  comments = comments,
  releases = releases,
})

local ok = sync.run(argv)
if not ok then
  os.exit(1)
end
