--!strict

type DateTime = {
  get_year: (self: DateTime) -> number,
  get_month: (self: DateTime) -> number,
  get_day: (self: DateTime) -> number,
  get_weekday: (self: DateTime) -> number,
  get_hour: (self: DateTime) -> number,
  get_minute: (self: DateTime) -> number,
  get_second: (self: DateTime) -> number,
  get_millisecond: (self: DateTime) -> number,
  get_epoch_milliseconds: (self: DateTime) -> number,
  get_timezone_offset: (self: DateTime) -> number,
  set_year: (self: DateTime, year: number) -> (),
  set_month: (self: DateTime, month: number) -> (),
  set_day: (self: DateTime, day: number) -> (),
  set_hour: (self: DateTime, hour: number) -> (),
  set_minute: (self: DateTime, min: number) -> (),
  set_second: (self: DateTime, sec: number) -> (),
  set_millisecond: (self: DateTime, milli: number) -> (),
  set_epoch_milliseconds: (self: DateTime, milli: number) -> (),
  set_time: (self: DateTime, hour: number, minute: number, second: number, millis: number) -> DateTime,
  set_date: (self: DateTime, year: number, month: number, day: number) -> DateTime,
  add_milliseconds: (self: DateTime, millis: number) -> DateTime,
  add_seconds: (self: DateTime, seconds: number) -> DateTime,
  add_minutes: (self: DateTime, minutes: number) -> DateTime,
  add_hours: (self: DateTime, hours: number) -> DateTime,
  add_days: (self: DateTime, days: number) -> DateTime,
  add_weeks: (self: DateTime, weeks: number) -> DateTime,
  add_months: (self: DateTime, months: number) -> DateTime,
  add_years: (self: DateTime, years: number) -> DateTime,
  sub_milliseconds: (self: DateTime, millis: number) -> DateTime,
  sub_seconds: (self: DateTime, seconds: number) -> DateTime,
  sub_minutes: (self: DateTime, minutes: number) -> DateTime,
  sub_hours: (self: DateTime, hours: number) -> DateTime,
  sub_days: (self: DateTime, days: number) -> DateTime,
  sub_weeks: (self: DateTime, weeks: number) -> DateTime,
  sub_months: (self: DateTime, months: number) -> DateTime,
  sub_years: (self: DateTime, years: number) -> DateTime,
  to_utc: (self: DateTime) -> DateTime,
  to_local: (self: DateTime) -> DateTime,
  to_rfc2822: (self: DateTime) -> string,
  to_rfc3339: (self: DateTime) -> string,
  to_format: (self: DateTime, format: string) -> string,
  to_date_string: (self: DateTime) -> string,
  to_time_string: (self: DateTime) -> string,
  to_datetime_string: (self: DateTime) -> string,
  to_iso_string: (self: DateTime) -> string,
  to_locale_date_string: (self: DateTime) -> string,
  to_locale_time_string: (self: DateTime) -> string,
  to_locale_datetime_string: (self: DateTime) -> string,
}

local astra_internal__datetime_new_parse: (input: string) -> DateTime
local astra_internal__datetime_new_from: (
  year: number,
  month: number?,
  day: number?,
  hour: number?,
  min: number?,
  sec: number?,
  milli: number?
) -> DateTime
local astra_internal__datetime_new_now: () -> DateTime
local astra_internal__datetime_sleep: (amount: number) -> ()

local function new_datetime(
  differentiator: string | number?,
  month: number?,
  day: number?,
  hour: number?,
  min: number?,
  sec: number?,
  milli: number?
): DateTime
  if type(differentiator) == "string" then
    return astra_internal__datetime_new_parse(differentiator :: string)
  elseif type(differentiator) == "number" then
    return astra_internal__datetime_new_from(differentiator :: number, month, day, hour, min, sec, milli)
  else
    return astra_internal__datetime_new_now()
  end
end

local function sleep(amount: number): ()
  return astra_internal__datetime_sleep(amount)
end

return { new = new_datetime, sleep = sleep }
