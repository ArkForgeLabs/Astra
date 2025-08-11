# DateTime

Astra provides date & time functionality as an extension to the standard library. It is loosely inspired by the [JavaScript Date](https://www.w3schools.com/jsref/jsref_obj_date.asp) implementation.

```lua
-- Returns a DateTime object which corresponds to the current date, time & local offset from UTC.
local dt = Astra.datetime.new()

-- Returns a DateTime object which corresponds to the provided date and/or time arguments & local offset from UTC.
-- You can provide the following arguments:
--     year: number
--     month: number?
--     day: number?
--     hour: number?
--     min: number?
--     sec: number?
--     milli: number?
--
-- Providing the year is mandatory.
-- The other values, if not provided, will default to the following in respective order: 1, 1, 0, 0, 0, 0
local dt = Astra.datetime.new(2001, 7, 8, 0, 24, 48, 241)

-- Or parse a string
local dt = Astra.datetime.new("Tue, 1 Jul 2003 10:52:37 +0200")
```

Available methods:

- `get_year()`
- `get_month()`
- `get_day()`
- `get_weekday()`
- `get_hour()`
- `get_minute()`
- `get_second()`
- `get_millisecond()`
- `get_epoch_milliseconds()`
- `get_timezone_offset()`
- `set_year(year: number)`
- `set_month(month: number)`
- `set_hour(hour: number)`
- `set_minute(min: number)`
- `set_second(sec: number)`
- `set_millisecond(milli: number)`
- `set_epoch_milliseconds(milli: number)`
- `to_date_string()`
- `to_time_string()`
- `to_datetime_string()`
- `to_iso_string()`
- `to_locale_date_string()`
- `to_locale_time_string()`
- `to_locale_datetime_string()`
