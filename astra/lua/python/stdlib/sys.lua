local sys = {}

sys.argv = setmetatable({}, {
  __index = function(t, k)
    return arg[k - 1]
  end,
  __len = function()
    return #arg + 1
  end,
})
sys.stderr = io.stderr
sys.exit = os.exit

return sys
