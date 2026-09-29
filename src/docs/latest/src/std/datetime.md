# DateTime

Astra provides date & time functionality as an extension to the standard library. It is loosely inspired by the [JavaScript Date](https://www.w3schools.com/jsref/jsref_obj_date.asp) implementation.

## Creating a DateTime

```lua
local datetime = require("datetime")

-- Returns a DateTime object corresponding to the current date, time & local offset from UTC.
local dt = datetime.new()

-- Returns a DateTime object corresponding to the provided date and/or time arguments in the
-- local timezone. You can provide the following arguments:
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
local dt = datetime.new(2001, 7, 8, 0, 24, 48, 241)

-- Or parse a string. RFC 2822, RFC 3339 and date-only (`YYYY-MM-DD`) strings are supported.
-- Strings carrying an explicit offset (e.g. `+0200`) keep it; date-only strings are
-- interpreted as midnight in the local timezone.
local dt = datetime.new("Tue, 1 Jul 2003 10:52:37 +0200")
local dt = datetime.new("2001-07-08T00:24:48.241+00:00")
local dt = datetime.new("2001-07-08")

-- Or create one from milliseconds since the Unix epoch. Since the epoch is UTC-anchored,
-- the resulting DateTime is fixed at +00:00.
local dt = datetime.from_epoch_millis(1720400688241)
```

>[!NOTE]
>DateTime objects are local by default. To work in UTC, convert them with `to_utc()`.

## Mutation

`set_*` methods mutate the DateTime in place **and** return an updated copy, so chaining them requires reassignment:

```lua
local dt = datetime.new(2020, 12, 25)
dt = dt:set_year(2030):set_month(6):set_day(15) -- dt is now 2030-06-15
```

`add_*`, `sub_*`, `to_utc()`, `to_local()` and the formatting methods do not mutate — they return new DateTime (or string) values.

## Available methods

- `get_year()`
- `get_month()` — 1 to 12 (note: unlike JavaScript, months are not zero-based)
- `get_day()`
- `get_weekday()` — 0 (Sunday) to 6 (Saturday), matching JavaScript's `getDay()`
- `get_hour()`
- `get_minute()`
- `get_second()`
- `get_millisecond()`
- `get_epoch_milliseconds()` — milliseconds since the Unix epoch
- `get_timezone_offset()` — offset from UTC in minutes (`local - UTC`; the opposite sign of JavaScript's `getTimezoneOffset()`)
- `set_year(year: number)`
- `set_month(month: number)`
- `set_day(day: number)`
- `set_hour(hour: number)`
- `set_minute(min: number)`
- `set_second(sec: number)`
- `set_millisecond(milli: number)`
- `set_epoch_milliseconds(milli: number)`
- `set_time(hour: number, minute: number, second: number, millis: number)`
- `set_date(year: number, month: number, day: number)`
- `add_milliseconds(millis: number)`
- `add_seconds(seconds: number)`
- `add_minutes(minutes: number)`
- `add_hours(hours: number)`
- `add_days(days: number)` — calendar-aware, respects daylight saving transitions
- `add_weeks(weeks: number)` — calendar-aware
- `add_months(months: number)` — rolls over years; clamps to the last valid day (e.g. Jan 31 + 1 month = Feb 28)
- `add_years(years: number)` — clamps leap days (e.g. Feb 29 + 1 year = Feb 28)
- `sub_milliseconds(millis: number)`
- `sub_seconds(seconds: number)`
- `sub_minutes(minutes: number)`
- `sub_hours(hours: number)`
- `sub_days(days: number)`
- `sub_weeks(weeks: number)`
- `sub_months(months: number)`
- `sub_years(years: number)`
- `diff_milliseconds(other: DateTime)` — difference between the two instants in milliseconds (`self - other`)
- `to_utc()` — returns a new DateTime fixed at +00:00
- `to_local()` — returns a new DateTime in the local timezone
- `to_date_string()`
- `to_time_string()`
- `to_datetime_string()`
- `to_iso_string()`
- `to_rfc2822()`
- `to_rfc3339()`
- `to_format(format: string)` — accepts [chrono's strftime-style specifiers](https://docs.rs/chrono/latest/chrono/format/strftime/index.html)
- `to_locale_date_string()`
- `to_locale_time_string()`
- `to_locale_datetime_string()`

## Comparing DateTimes

DateTimes compare by their true instant, regardless of the timezone they are expressed in. The `==`, `<`, `<=` operators work out of the box, and subtracting two DateTimes yields the difference in milliseconds:

```lua
local datetime = require("datetime")

local dt = datetime.new("2020-12-25T10:30:45.500+00:00")
local dt2 = datetime.new(2020, 12, 25, 11, 30, 45, 500) -- local time

print(dt == dt2)   -- true when the instants match
print(dt < dt2)    -- instants are compared
print(dt2 - dt)    -- difference in milliseconds
```

## Pausing execution

The datetime module also provides a `sleep` function to pause the current execution thread:

```lua
local datetime = require("datetime")

datetime.sleep(1000) -- sleep for 1 second
```
