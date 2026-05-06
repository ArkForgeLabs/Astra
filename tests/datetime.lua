local datetime = require("datetime")
require("test")

---@param test Test
return function(test)
  -- helper functions
  local function expect_invalid_datetime(args)
    test
      .expect(function()
        datetime.new(unpack(args))
      end).to
      .fail()
  end

  local function expect_invalid_setter(dt, method_name, values)
    for _, v in ipairs(values) do
      test
        .expect(function()
          dt[method_name](dt, v)
        end).to
        .fail()
    end
  end

  -- test cases
  test.describe("NewDatetimeFullArgs", function()
    local dt = datetime.new(2025, 7, 8, 0, 24, 48, 241)
    local getter_expected = {
      year = 2025,
      month = 7,
      day = 8,
      weekday = 2,
      hour = 0,
      minute = 24,
      second = 48,
      millisecond = 241,
    }
    for field, expected in pairs(getter_expected) do
      test.it("get_" .. field .. "()", function()
        test.expect(dt["get_" .. field](dt)).to.equal(expected)
      end)
    end

    test.it("invalid-type", function()
      test
        .expect(function()
          datetime.new("2025")
        end).to
        .fail()
    end)

    local base = { 2025, 7, 8, 0, 24, 48, 241 }
    local validation_cases = {
      { name = "month", pos = 2, values = { 13, -1, "str" } },
      { name = "hour", pos = 4, values = { 25, -1, "str" } },
      { name = "minute", pos = 5, values = { 61, -1, "str" } },
      { name = "second", pos = 6, values = { 61, -1, "str" } },
    }
    for _, c in ipairs(validation_cases) do
      test.it("invalid-" .. c.name, function()
        for _, v in ipairs(c.values) do
          local args = { unpack(base) }
          args[c.pos] = v
          expect_invalid_datetime(args)
        end
      end)
    end

    test.it("invalid-day", function()
      for _, d in ipairs({ 31, 32, -1, "str" }) do
        expect_invalid_datetime({ 2025, 6, d, 0, 24, 48, 241 })
      end
    end)
  end)

  test.describe("NewDatetimeDefault", function()
    local dt = datetime.new(2025)
    local expected = { year = 2025, month = 1, day = 1, weekday = 3, hour = 0, minute = 0, second = 0, millisecond = 0 }
    for field, val in pairs(expected) do
      test.it("get_" .. field .. "()", function()
        test.expect(dt["get_" .. field](dt)).to.equal(val)
      end)
    end
  end)

  test.describe("NewDatetimeByStr", function()
    local dt = datetime.new("Tue, 1 Jul 2003 10:52:37 +0200")
    local expected =
      { year = 2003, month = 7, day = 1, weekday = 2, hour = 10, minute = 52, second = 37, millisecond = 0 }
    for field, val in pairs(expected) do
      test.it("get_" .. field .. "()", function()
        test.expect(dt["get_" .. field](dt)).to.equal(val)
      end)
    end

    test.it("invalid-format", function()
      for _, str in ipairs({ "Tue, 1 Jul 2003", "2003", "2003, 7, 8" }) do
        test
          .expect(function()
            datetime.new(str)
          end).to
          .fail()
      end
    end)
  end)

  test.describe("Setters", function()
    local dt = datetime.new(2024)
    local setter_cases = {
      year = 2025,
      month = 12,
      day = 31,
      hour = 23,
      minute = 59,
      second = 58,
      millisecond = 123,
    }
    for field, value in pairs(setter_cases) do
      test.it("set_" .. field .. "()", function()
        dt["set_" .. field](dt, value)
        test.expect(dt["get_" .. field](dt)).to.equal(value)
      end)
    end

    test.it("invalid-args", function()
      expect_invalid_setter(dt, "set_year", { "str", nil })
      expect_invalid_setter(dt, "set_month", { 13, -1, "str", nil })
      expect_invalid_setter(dt, "set_day", { 32, -1, "str", nil })
      expect_invalid_setter(dt, "set_hour", { 25, -1, "str", nil })
      expect_invalid_setter(dt, "set_minute", { 61, -1, "str", nil })
      expect_invalid_setter(dt, "set_second", { 61, -1, "str", nil })
    end)

    -- invalid-set_millisecond not available yet! (unknown defintest.ition)
  end)

  test.describe("ToString", function()
    local dt = datetime.new(2020, 12, 25, 10, 30, 45, 500):to_utc()
    local tostring_cases = {
      date = "2020-12-25",
      time = "07:30:45.500+00:00",
      datetime = "2020-12-25T07:30:45.500+00:00",
      iso = "2020-12-25T07:30:45.500+00:00",
      locale_date = "12/25/20",
      locale_time = "07:30:45",
      locale_datetime = "Fri Dec 25 07:30:45 2020",
    }
    for format, expected in pairs(tostring_cases) do
      test.it("to_" .. format .. "_string()", function()
        test.expect(dt["to_" .. format .. "_string"](dt)).to.equal(expected)
      end)
    end
  end)

  test.describe("EpochMillisecond", function()
    local dt = datetime.new(1970)

    test.it("get_epoch_milliseconds()", function()
      test.expect(dt:get_epoch_milliseconds()).to.equal(-7200000)
    end)

    test.it("set_epoch_milliseconds()", function()
      dt:set_epoch_milliseconds(dt:get_epoch_milliseconds() + 30 * 24 * 60 * 60 * 1000) -- one month (ish)
      test.expect(dt:get_epoch_milliseconds()).to.equal(2584800000)
      test.expect(dt:to_locale_date_string()).to.equal("01/31/70")
    end)

    test.it("invalid-set_epoch_milliseconds()", function()
      test
        .expect(function()
          ---@diagnostic disable-next-line: param-type-mismatch
          dt:set_epoch_milliseconds("str")
        end).to
        .fail()
      test
        .expect(function()
          ---@diagnostic disable-next-line: param-type-mismatch
          dt:set_epoch_milliseconds(nil)
        end).to
        .fail()
    end)
  end)
end
