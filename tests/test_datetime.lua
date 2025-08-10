local lust = require 'tests.lust'
local describe, it, expect = lust.describe, lust.it, lust.expect

-- helper function
local function expect_invalid_datetime(args)
    expect(function()
        Astra.datetime.new(unpack(args))
    end).to.fail()
end

local function expect_invalid_setter(method_name, values)
    for _, v in ipairs(values) do
        expect(function()
            dt[method_name](dt, v)
        end).to.fail()
    end
end

describe('NewDatetimeFullArgs', function()
    local dt = Astra.datetime.new(2025, 7, 8, 0, 24, 48, 241)
    it('get_year()', function()
        expect(dt:get_year()).to.equal(2025)
    end)

    it('get_month()', function()
        expect(dt:get_month()).to.equal(7)
    end)

    it('get_day()', function()
        expect(dt:get_day()).to.equal(8)
    end)

    it('get_weekday()', function()
        expect(dt:get_weekday()).to.equal(2)
    end)

    it('get_hour()', function()
        expect(dt:get_hour()).to.equal(0)
    end)

    it('get_minute()', function()
        expect(dt:get_minute()).to.equal(24)
    end)

    it('get_second()', function()
        expect(dt:get_second()).to.equal(48)
    end)

    it('get_millisecond()', function()
        expect(dt:get_millisecond()).to.equal(241)
    end)

    it('invalid-type', function()
        expect(function()
            Astra.datetime.new('2025')
        end).to.fail()
    end)

    it('invalid-month', function()
        for _, m in ipairs({13, -1, 'str'}) do
            expect_invalid_datetime({2025, m, 8, 0, 24, 48, 241})
        end
    end)

    it('invalid-day', function()
        for _, d in ipairs({31, 32, -1, 'str'}) do
            expect_invalid_datetime({2025, 6, d, 0, 24, 48, 241})
        end
    end)

    it('invalid-hour', function()
        for _, h in ipairs({25, -1, 'str'}) do
            expect_invalid_datetime({2025, 7, 8, h, 24, 48, 241})
        end
    end)

    it('invalid-minute', function()
        for _, m in ipairs({61, -1, 'str'}) do
            expect_invalid_datetime({2025, 7, 8, 0, m, 48, 241})
        end
    end)

    it('invalid-second', function()
        for _, s in ipairs({61, -1, 'str'}) do
            expect_invalid_datetime({2025, 7, 8, 0, 24, s, 241})
        end
    end)

    -- it('invalid-millsec', function()
    -- end) -- definition (range unknown)
end)

describe('NewDatetimeDefault', function()
    local dt = Astra.datetime.new(2025)
    it('getter-methods', function()
        expect(dt:get_year()).to.equal(2025)
        expect(dt:get_month()).to.equal(1)
        expect(dt:get_day()).to.equal(1)
        expect(dt:get_weekday()).to.equal(3)
        expect(dt:get_hour()).to.equal(0)
        expect(dt:get_minute()).to.equal(0)
        expect(dt:get_second()).to.equal(0)
        expect(dt:get_millisecond()).to.equal(0)
    end)
end)

describe('NewDatetimeByStr', function()
    local dt = Astra.datetime.new("Tue, 1 Jul 2003 10:52:37 +0200")
    it('getter-methods', function()
        expect(dt:get_year()).to.equal(2003)
        expect(dt:get_month()).to.equal(7)
        expect(dt:get_day()).to.equal(1)
        expect(dt:get_weekday()).to.equal(2)
        expect(dt:get_hour()).to.equal(10)
        expect(dt:get_minute()).to.equal(52)
        expect(dt:get_second()).to.equal(37)
        expect(dt:get_millisecond()).to.equal(0)
    end)

    it('invalid-format', function()
        for _, str in ipairs({"Tue, 1 Jul 2003", "2003", "2003, 7, 8"}) do
            expect(function()
                Astra.datetime.new(str)
            end).to.fail()
        end
    end)
end)

describe('Setters', function()
    local dt = Astra.datetime.new(2024)
    it('set_year()', function()
        dt:set_year(2025)
        expect(dt:get_year()).to.equal(2025)
    end)

    it('set_month()', function()
        dt:set_month(12)
        expect(dt:get_month()).to.equal(12)
    end)

    it('set_day()', function()
        dt:set_day(31)
        expect(dt:get_day()).to.equal(31)
    end)

    it('set_hour()', function()
        dt:set_hour(23)
        expect(dt:get_hour()).to.equal(23)
    end)

    it('set_minute()', function()
        dt:set_minute(59)
        expect(dt:get_minute()).to.equal(59)
    end)

    it('set_second()', function()
        dt:set_second(58)
        expect(dt:get_second()).to.equal(58)
    end)

    it('set_millisecond()', function()
        dt:set_millisecond(123)
        expect(dt:get_millisecond()).to.equal(123)
    end)

    it('invalid-args', function()
        expect_invalid_setter('set_year', {'str', nil})
        expect_invalid_setter('set_month', {13, -1, 'str', nil})
        expect_invalid_setter('set_day', {32, -1, 'str', nil})
        expect_invalid_setter('set_hour', {25, -1, 'str', nil})
        expect_invalid_setter('set_minute', {61, -1, 'str', nil})
        expect_invalid_setter('set_second', {61, -1, 'str', nil})
    end)

    -- invalid-set_millisecond not available yet! (unknown definition)
end)

describe('ToString', function()
    local dt = Astra.datetime.new(2020, 12, 25, 10, 30, 45, 500)
    it('to_date_string()', function()
        expect(dt:to_date_string()).to.equal('Fri Dec 25 2020')
    end)

    it('to_time_string()', function()
        expect(dt:to_time_string()).to.equal('10:30:45 -06:00-0600')
    end)

    it('to_datetime_string()', function()
        expect(dt:to_datetime_string()).to.equal('Fri Dec 25 2020 10:30:45 -06:00-0600')
    end)

    it('to_iso_string()', function()
        expect(dt:to_iso_string()).to.equal('2020-12-25T10:30:45.500-06:00')
    end)

    it('to_locale_date_string()', function()
        expect(dt:to_locale_date_string()).to.equal('12/25/20')
    end)

    it('to_locale_time_string()', function()
        expect(dt:to_locale_time_string()).to.equal('10:30:45')
    end)

    it('to_locale_datetime_string()', function()
        expect(dt:to_locale_datetime_string()).to.equal('Fri Dec 25 10:30:45 2020')
    end)
end)

describe('EpochMillisecond', function()
    local dt = Astra.datetime.new(1970)

    it('get_epoch_milliseconds()', function()
        expect(dt:get_epoch_milliseconds()).to.equal(21600000)
    end)
    
    it('set_epoch_milliseconds()', function()
        dt:set_epoch_milliseconds(dt:get_epoch_milliseconds() + 2678400000) -- one month (ish)
        expect(dt:get_epoch_milliseconds()).to.equal(2700000000)
        expect(dt:to_locale_date_string()).to.equal('02/01/70')
    end)
    
    it('invalid-set_epoch_milliseconds()', function()
        expect(function()
            dt:set_epoch_milliseconds('str')
        end).to.fail()
        expect(function()
            dt:set_epoch_milliseconds(nil)
        end).to.fail()
    end)
end)

