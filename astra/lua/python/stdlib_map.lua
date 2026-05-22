return {
  time = {
    perf_counter = [[function() return require("datetime").new():get_epoch_milliseconds() / 1000 end]],
    time = [[function() return require("datetime").new():get_epoch_milliseconds() / 1000 end]],
    sleep = [[function(secs) require("datetime").sleep(secs * 1000) end]],
  },
  sys = {
    argv = [[setmetatable({}, {__index = function(t, k) return arg[k - 1] end, __len = function() return #arg + 1 end})]],
    stderr = [[io.stderr]],
    exit = [[os.exit]],
  },
}
