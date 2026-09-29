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
          ---@type any[]
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

    test.it("rfc3339-format", function()
      local rfc3339 = datetime.new("2020-12-25T10:30:45.500+00:00")
      test.expect(rfc3339:get_year()).to.equal(2020)
      test.expect(rfc3339:get_month()).to.equal(12)
      test.expect(rfc3339:get_day()).to.equal(25)
      test.expect(rfc3339:get_hour()).to.equal(10)
      test.expect(rfc3339:get_minute()).to.equal(30)
      test.expect(rfc3339:get_second()).to.equal(45)
      test.expect(rfc3339:get_millisecond()).to.equal(500)
      test.expect(rfc3339:get_timezone_offset()).to.equal(0)
    end)

    test.it("date-only-format", function()
      local date_only = datetime.new("2025-07-08")
      test.expect(date_only:get_year()).to.equal(2025)
      test.expect(date_only:get_month()).to.equal(7)
      test.expect(date_only:get_day()).to.equal(8)
      test.expect(date_only:get_hour()).to.equal(0)
      test.expect(date_only:get_minute()).to.equal(0)
    end)

    test.it("invalid-format", function()
      for _, str in ipairs({ "Tue, 1 Jul 2003", "2003", "2003, 7, 8", "not a date" }) do
        test
          .expect(function()
            datetime.new(str)
          end).to
          .fail()
      end
    end)
  end)

  test.describe("NewDatetimeByEpoch", function()
    local dt = datetime.from_epoch_millis(0)

    test.it("unix-epoch", function()
      test.expect(dt:get_epoch_milliseconds()).to.equal(0)
      test.expect(dt:get_year()).to.equal(1970)
      test.expect(dt:get_month()).to.equal(1)
      test.expect(dt:get_day()).to.equal(1)
      test.expect(dt:get_hour()).to.equal(0)
      test.expect(dt:get_minute()).to.equal(0)
      test.expect(dt:get_second()).to.equal(0)
      test.expect(dt:get_millisecond()).to.equal(0)
      test.expect(dt:get_timezone_offset()).to.equal(0)
    end)

    test.it("negative-values", function()
      local before_epoch = datetime.from_epoch_millis(-3600000)
      test.expect(before_epoch:get_epoch_milliseconds()).to.equal(-3600000)
      test.expect(before_epoch:to_date_string()).to.equal("1969-12-31")
    end)

    test.it("invalid-from_epoch_millis()", function()
      test
        .expect(function()
          ---@diagnostic disable-next-line: param-type-mismatch
          datetime.from_epoch_millis("str")
        end).to
        .fail()
      test
        .expect(function()
          datetime.from_epoch_millis(9223372036854775807)
        end).to
        .fail()
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

    test.it("chaining", function()
      local chained = datetime.new(2024)
      chained = chained:set_year(2030):set_month(6):set_day(15)
      chained = chained:set_hour(12):set_minute(30):set_second(15):set_millisecond(250)
      test.expect(chained:get_year()).to.equal(2030)
      test.expect(chained:get_month()).to.equal(6)
      test.expect(chained:get_day()).to.equal(15)
      test.expect(chained:get_hour()).to.equal(12)
      test.expect(chained:get_minute()).to.equal(30)
      test.expect(chained:get_second()).to.equal(15)
      test.expect(chained:get_millisecond()).to.equal(250)
    end)

    test.it("returns-copy", function()
      local returned = dt:set_year(2001)
      test.expect(returned:get_year()).to.equal(2001)
      test.expect(dt:get_year()).to.equal(2001)
    end)

    test.it("set_time()", function()
      local dt = datetime.new(2024, 5, 10, 6, 30, 15, 0)
      local returned = dt:set_time(12, 45, 30, 250)
      test.expect(dt:get_hour()).to.equal(12)
      test.expect(dt:get_minute()).to.equal(45)
      test.expect(dt:get_second()).to.equal(30)
      test.expect(dt:get_millisecond()).to.equal(250)
      test.expect(returned == dt).to.be.truthy()
    end)

    test.it("set_date()", function()
      local dt = datetime.new(2024, 5, 10, 6, 30, 15, 0)
      local returned = dt:set_date(2025, 8, 20)
      test.expect(dt:get_year()).to.equal(2025)
      test.expect(dt:get_month()).to.equal(8)
      test.expect(dt:get_day()).to.equal(20)
      test.expect(returned == dt).to.be.truthy()
    end)

    test.it("invalid-args", function()
      expect_invalid_setter(dt, "set_year", { "str", nil })
      expect_invalid_setter(dt, "set_month", { 13, -1, "str", nil })
      expect_invalid_setter(dt, "set_day", { 32, -1, "str", nil })
      expect_invalid_setter(dt, "set_hour", { 25, -1, "str", nil })
      expect_invalid_setter(dt, "set_minute", { 61, -1, "str", nil })
      expect_invalid_setter(dt, "set_second", { 61, -1, "str", nil })
      expect_invalid_setter(dt, "set_millisecond", { 1000, -1, "str", nil })
    end)

    test.it("invalid-set_time()", function()
      local dt = datetime.new(2024, 5, 10, 6, 30, 15, 0)
      test
        .expect(function()
          dt:set_time(24, 0, 0, 0)
        end).to
        .fail()
      test
        .expect(function()
          dt:set_time(12, 60, 0, 0)
        end).to
        .fail()
      test
        .expect(function()
          dt:set_time(12, 0, 61, 0)
        end).to
        .fail()
      test
        .expect(function()
          dt:set_time(12, 0, 0, 1000)
        end).to
        .fail()
    end)

    test.it("invalid-set_date()", function()
      local dt = datetime.new(2024, 5, 10, 6, 30, 15, 0)
      test
        .expect(function()
          dt:set_date(2025, 13, 1)
        end).to
        .fail()
      test
        .expect(function()
          dt:set_date(2025, 2, 30)
        end).to
        .fail()
    end)
  end)

  test.describe("ToString", function()
    local dt = datetime.new("2020-12-25T10:30:45.500+00:00")
    local tostring_cases = {
      date = "2020-12-25",
      time = "10:30:45.500+00:00",
      datetime = "2020-12-25T10:30:45.500+00:00",
      iso = "2020-12-25T10:30:45.500+00:00",
      locale_date = "12/25/20",
      locale_time = "10:30:45",
      locale_datetime = "Fri Dec 25 10:30:45 2020",
    }
    for format, expected in pairs(tostring_cases) do
      test.it("to_" .. format .. "_string()", function()
        test.expect(dt["to_" .. format .. "_string"](dt)).to.equal(expected)
      end)
    end

    test.it("to_rfc2822()", function()
      test.expect(dt:to_rfc2822()).to.equal("Fri, 25 Dec 2020 10:30:45 +0000")
    end)

    test.it("to_format()", function()
      test.expect(dt:to_format("%d/%m/%Y %H:%M")).to.equal("25/12/2020 10:30")
    end)

    test.it("tostring-metamethod", function()
      test.expect(tostring(dt)).to.equal("2020-12-25T10:30:45.500+00:00")
    end)

    test.it("concat-metamethod", function()
      test.expect(dt .. "!").to.equal("2020-12-25T10:30:45.500+00:00!")
    end)
  end)

  test.describe("EpochMillisecond", function()
    test.it("set_epoch_milliseconds()", function()
      local dt = datetime.from_epoch_millis(0)
      dt:set_epoch_milliseconds(dt:get_epoch_milliseconds() + 30 * 24 * 60 * 60 * 1000) -- one month (ish)
      test.expect(dt:get_epoch_milliseconds()).to.equal(2592000000)
      test.expect(dt:to_locale_date_string()).to.equal("01/31/70")
      test.expect(dt:get_timezone_offset()).to.equal(0) -- keeps the current offset
    end)

    test.it("invalid-set_epoch_milliseconds()", function()
      local dt = datetime.from_epoch_millis(0)
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

  test.describe("Arithmetic", function()
    local epoch = datetime.from_epoch_millis(0)

    test.it("add_milliseconds()", function()
      test.expect(epoch:add_milliseconds(1500):get_epoch_milliseconds()).to.equal(1500)
    end)

    test.it("add_seconds()", function()
      test.expect(epoch:add_seconds(90):get_epoch_milliseconds()).to.equal(90000)
    end)

    test.it("add_minutes()", function()
      test.expect(epoch:add_minutes(2):get_epoch_milliseconds()).to.equal(120000)
    end)

    test.it("add_hours()", function()
      test.expect(epoch:add_hours(5):get_epoch_milliseconds()).to.equal(18000000)
    end)

    test.it("add_days()", function()
      test.expect(epoch:add_days(31):get_epoch_milliseconds()).to.equal(31 * 86400000)
    end)

    test.it("add_weeks()", function()
      test.expect(epoch:add_weeks(2):get_epoch_milliseconds()).to.equal(14 * 86400000)
    end)

    test.it("add_months() rolls over the year", function()
      local dt = datetime.new(2020, 12, 31, 10):add_months(1)
      test.expect(dt:get_year()).to.equal(2021)
      test.expect(dt:get_month()).to.equal(1)
      test.expect(dt:get_day()).to.equal(31)
      test.expect(dt:get_hour()).to.equal(10)
    end)

    test.it("add_months() clamps to the last valid day", function()
      local dt = datetime.new(2021, 1, 31, 10):add_months(1)
      test.expect(dt:get_month()).to.equal(2)
      test.expect(dt:get_day()).to.equal(28)
    end)

    test.it("add_years() clamps leap day", function()
      local dt = datetime.new(2024, 2, 29, 10):add_years(1)
      test.expect(dt:get_year()).to.equal(2025)
      test.expect(dt:get_month()).to.equal(2)
      test.expect(dt:get_day()).to.equal(28)
    end)

    test.it("add_years() keeps leap day across leap years", function()
      local dt = datetime.new(2024, 2, 29, 10):add_years(4)
      test.expect(dt:get_year()).to.equal(2028)
      test.expect(dt:get_day()).to.equal(29)
    end)

    test.it("sub_milliseconds()", function()
      test.expect(epoch:sub_milliseconds(1500):get_epoch_milliseconds()).to.equal(-1500)
    end)

    test.it("sub_seconds()", function()
      test.expect(epoch:sub_seconds(90):get_epoch_milliseconds()).to.equal(-90000)
    end)

    test.it("sub_minutes()", function()
      test.expect(epoch:sub_minutes(2):get_epoch_milliseconds()).to.equal(-120000)
    end)

    test.it("sub_hours()", function()
      test.expect(epoch:sub_hours(5):get_epoch_milliseconds()).to.equal(-18000000)
    end)

    test.it("sub_days()", function()
      test.expect(epoch:sub_days(2):get_epoch_milliseconds()).to.equal(-2 * 86400000)
    end)

    test.it("sub_weeks()", function()
      test.expect(epoch:sub_weeks(2):get_epoch_milliseconds()).to.equal(-14 * 86400000)
    end)

    test.it("sub_months() rolls over the year", function()
      local dt = datetime.new(2021, 1, 31, 10):sub_months(1)
      test.expect(dt:get_year()).to.equal(2020)
      test.expect(dt:get_month()).to.equal(12)
      test.expect(dt:get_day()).to.equal(31)
    end)

    test.it("sub_years() clamps leap day", function()
      local dt = datetime.new(2024, 2, 29, 10):sub_years(1)
      test.expect(dt:get_year()).to.equal(2023)
      test.expect(dt:get_day()).to.equal(28)
    end)

    test.it("immutability", function()
      local dt = datetime.new(2020, 6, 15, 12)
      dt:add_days(10)
      test.expect(dt:get_day()).to.equal(15)
      dt:add_months(1)
      test.expect(dt:get_month()).to.equal(6)
    end)

    test.it("diff_milliseconds()", function()
      local a = datetime.from_epoch_millis(5000)
      local b = datetime.from_epoch_millis(2000)
      test.expect(a:diff_milliseconds(b)).to.equal(3000)
      test.expect(b:diff_milliseconds(a)).to.equal(-3000)
    end)

    test.it("subtraction", function()
      local a = datetime.from_epoch_millis(5000)
      local b = datetime.from_epoch_millis(2000)
      test.expect(a - b).to.equal(3000)
      test.expect(b - a).to.equal(-3000)
    end)

    test.it("cross-timezone", function()
      local local_dt = datetime.new(2020, 6, 15, 12)
      local same_instant_utc = datetime.from_epoch_millis(local_dt:get_epoch_milliseconds())
      test.expect(local_dt:diff_milliseconds(same_instant_utc)).to.equal(0)
    end)

    test.it("invalid-arithmetic", function()
      test
        .expect(function()
          epoch:add_months(2147483647)
        end).to
        .fail()
      test
        .expect(function()
          epoch:add_days(9223372036854775807)
        end).to
        .fail()
    end)
  end)

  test.describe("TimezoneConversion", function()
    local local_dt = datetime.new(2020, 12, 25, 10, 30, 45, 500)
    local utc_dt = local_dt:to_utc()

    test.it("to_utc()", function()
      test.expect(utc_dt:get_epoch_milliseconds()).to.equal(local_dt:get_epoch_milliseconds())
      test.expect(utc_dt:get_timezone_offset()).to.equal(0)
      test.expect(utc_dt == local_dt).to.be.truthy()
    end)

    test.it("to_local()", function()
      local back = utc_dt:to_local()
      test.expect(back:get_hour()).to.equal(local_dt:get_hour())
      test.expect(back:get_minute()).to.equal(local_dt:get_minute())
      test.expect(back == local_dt).to.be.truthy()
    end)

    test.it("epoch-roundtrip", function()
      local converted = datetime.from_epoch_millis(local_dt:get_epoch_milliseconds())
      test.expect(converted == local_dt).to.be.truthy()
      test.expect(converted:get_epoch_milliseconds()).to.equal(local_dt:get_epoch_milliseconds())
    end)

    test.it("get_timezone_offset()", function()
      local dt = datetime.new(1970)
      local offset = dt:get_timezone_offset()
      test.expect(offset).to.be.a("number")
      test.expect(dt:get_epoch_milliseconds()).to.equal(-offset * 60000)
    end)
  end)

  test.describe("Comparison", function()
    test.it("metamethods", function()
      local a = datetime.from_epoch_millis(1000)
      local b = datetime.from_epoch_millis(2000)
      test.expect(a == a).to.be.truthy()
      test.expect(a == b).to_not.be.truthy()
      test.expect(a < b).to.be.truthy()
      test.expect(b < a).to_not.be.truthy()
      test.expect(a <= b).to.be.truthy()
      test.expect(a <= a).to.be.truthy()
      test.expect(b > a).to.be.truthy()
      test.expect(b >= a).to.be.truthy()
    end)

    test.it("same datetime fields are equal", function()
      local dt = datetime.new(2025, 1, 15)
      local dt2 = datetime.new(2025, 1, 15)
      test.expect(dt:get_year()).to.equal(dt2:get_year())
      test.expect(dt:get_month()).to.equal(dt2:get_month())
      test.expect(dt:get_day()).to.equal(dt2:get_day())
    end)

    test.it("different datetimes have different values", function()
      local a = datetime.new(2025, 1, 1)
      local b = datetime.new(2025, 12, 31)
      test.expect(a:get_month()).to_not.equal(b:get_month())
      test.expect(a:get_day()).to_not.equal(b:get_day())
    end)

    test.it("weekday is within valid range", function()
      local dt = datetime.new(2025, 1, 15)
      local wd = dt:get_weekday()
      test.expect(wd).to.be.a("number")
      test.expect(wd >= 0).to.be.truthy()
      test.expect(wd <= 7).to.be.truthy()
    end)
  end)

  test.describe("Consistency", function()
    test.it("setters update corresponding getters correctly", function()
      local dt = datetime.new(2025, 1, 1)
      dt:set_year(2030)
      test.expect(dt:get_year()).to.equal(2030)
      dt:set_month(6)
      test.expect(dt:get_month()).to.equal(6)
      dt:set_day(15)
      test.expect(dt:get_day()).to.equal(15)
    end)

    test.it("epoch milliseconds roundtrip is consistent", function()
      local dt = datetime.new(2025, 1, 1)
      local ms = dt:get_epoch_milliseconds()
      test.expect(ms).to.be.a("number")
      test.expect(ms > 0).to.be.truthy()
      dt:set_epoch_milliseconds(ms)
      test.expect(dt:get_epoch_milliseconds()).to.equal(ms)
    end)

    test.it("parsing roundtrip is consistent", function()
      local dt = datetime.new("2020-12-25T10:30:45.500+00:00")
      test.expect(datetime.new(dt:to_rfc3339()) == dt).to.be.truthy()
    end)
  end)

  test.describe("Sleep", function()
    test.it("sleep()", function()
      local start = datetime.new():get_epoch_milliseconds()
      datetime.sleep(50)
      local elapsed = datetime.new():get_epoch_milliseconds() - start
      test.expect(elapsed >= 50).to.be.truthy()
    end)
  end)
end
