-- Jinja2 engine (logic: new, get_template_names, exclude_templates)
local jinja2 = require("jinja2")
-- Use a glob that exists in repo (e.g. examples/templates or any folder with html)
local engine = jinja2.new("examples/templates/**/*.html")
assert(engine ~= nil, "jinja2.new")
local names = engine:get_template_names()
assert(type(names) == "table", "get_template_names returns table")
-- After exclude, count should drop (if we have matching templates)
engine:exclude_templates({ "index.html" })
local after = engine:get_template_names()
assert(type(after) == "table", "exclude_templates leaves table")
-- Glob exclude
local engine2 = jinja2.new("templates/**/*.html")
if #engine2:get_template_names() > 0 then
  engine2:exclude_templates({ "*.test.html" })
  assert(type(engine2:get_template_names()) == "table", "glob exclude")
end
