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
    test.it("get_year()", function()
      test.expect(dt:get_year()).to.equal(2025)
    end)

    test.it("get_month()", function()
      test.expect(dt:get_month()).to.equal(7)
    end)

    test.it("get_day()", function()
      test.expect(dt:get_day()).to.equal(8)
    end)

    test.it("get_weekday()", function()
      test.expect(dt:get_weekday()).to.equal(2)
    end)

    test.it("get_hour()", function()
      test.expect(dt:get_hour()).to.equal(0)
    end)

    test.it("get_minute()", function()
      test.expect(dt:get_minute()).to.equal(24)
    end)

    test.it("get_second()", function()
      test.expect(dt:get_second()).to.equal(48)
    end)

    test.it("get_millisecond()", function()
      test.expect(dt:get_millisecond()).to.equal(241)
    end)

    test.it("invalid-type", function()
      test
        .expect(function()
          datetime.new("2025")
        end).to
        .fail()
    end)

    test.it("invalid-month", function()
      for _, m in ipairs({ 13, -1, "str" }) do
        expect_invalid_datetime({ 2025, m, 8, 0, 24, 48, 241 })
      end
    end)

    test.it("invalid-day", function()
      for _, d in ipairs({ 31, 32, -1, "str" }) do
        expect_invalid_datetime({ 2025, 6, d, 0, 24, 48, 241 })
      end
    end)

    test.it("invalid-hour", function()
      for _, h in ipairs({ 25, -1, "str" }) do
        expect_invalid_datetime({ 2025, 7, 8, h, 24, 48, 241 })
      end
    end)

    test.it("invalid-minute", function()
      for _, m in ipairs({ 61, -1, "str" }) do
        expect_invalid_datetime({ 2025, 7, 8, 0, m, 48, 241 })
      end
    end)

    test.it("invalid-second", function()
      for _, s in ipairs({ 61, -1, "str" }) do
        expect_invalid_datetime({ 2025, 7, 8, 0, 24, s, 241 })
      end
    end)

    -- test.it('invalid-millsec', function()
    -- end) -- defintest.ition (range unknown)
  end)

  test.describe("NewDatetimeDefault", function()
    local dt = datetime.new(2025)
    test.it("getter-methods", function()
      test.expect(dt:get_year()).to.equal(2025)
      test.expect(dt:get_month()).to.equal(1)
      test.expect(dt:get_day()).to.equal(1)
      test.expect(dt:get_weekday()).to.equal(3)
      test.expect(dt:get_hour()).to.equal(0)
      test.expect(dt:get_minute()).to.equal(0)
      test.expect(dt:get_second()).to.equal(0)
      test.expect(dt:get_millisecond()).to.equal(0)
    end)
  end)

  test.describe("NewDatetimeByStr", function()
    local dt = datetime.new("Tue, 1 Jul 2003 10:52:37 +0200")
    test.it("getter-methods", function()
      test.expect(dt:get_year()).to.equal(2003)
      test.expect(dt:get_month()).to.equal(7)
      test.expect(dt:get_day()).to.equal(1)
      test.expect(dt:get_weekday()).to.equal(2)
      test.expect(dt:get_hour()).to.equal(10)
      test.expect(dt:get_minute()).to.equal(52)
      test.expect(dt:get_second()).to.equal(37)
      test.expect(dt:get_millisecond()).to.equal(0)
    end)

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
    test.it("set_year()", function()
      dt:set_year(2025)
      test.expect(dt:get_year()).to.equal(2025)
    end)

    test.it("set_month()", function()
      dt:set_month(12)
      test.expect(dt:get_month()).to.equal(12)
    end)

    test.it("set_day()", function()
      dt:set_day(31)
      test.expect(dt:get_day()).to.equal(31)
    end)

    test.it("set_hour()", function()
      dt:set_hour(23)
      test.expect(dt:get_hour()).to.equal(23)
    end)

    test.it("set_minute()", function()
      dt:set_minute(59)
      test.expect(dt:get_minute()).to.equal(59)
    end)

    test.it("set_second()", function()
      dt:set_second(58)
      test.expect(dt:get_second()).to.equal(58)
    end)

    test.it("set_millisecond()", function()
      dt:set_millisecond(123)
      test.expect(dt:get_millisecond()).to.equal(123)
    end)

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
    test.it("to_date_string()", function()
      test.expect(dt:to_date_string()).to.equal("2020-12-25")
    end)

    test.it("to_time_string()", function()
      test.expect(dt:to_time_string()).to.equal("07:30:45.500+00:00")
    end)

    test.it("to_datetime_string()", function()
      test.expect(dt:to_datetime_string()).to.equal("2020-12-25T07:30:45.500+00:00")
    end)

    test.it("to_iso_string()", function()
      test.expect(dt:to_iso_string()).to.equal("2020-12-25T07:30:45.500+00:00")
    end)

    test.it("to_locale_date_string()", function()
      test.expect(dt:to_locale_date_string()).to.equal("12/25/20")
    end)

    test.it("to_locale_time_string()", function()
      test.expect(dt:to_locale_time_string()).to.equal("07:30:45")
    end)

    test.it("to_locale_datetime_string()", function()
      test.expect(dt:to_locale_datetime_string()).to.equal("Fri Dec 25 07:30:45 2020")
    end)
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
