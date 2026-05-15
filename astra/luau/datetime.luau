--!nocheck
--!nolint

type DateTime = {
  get_year: (datetime: DateTime) -> number,
  get_month: (datetime: DateTime) -> number,
  get_day: (datetime: DateTime) -> number,
  get_weekday: (datetime: DateTime) -> number,
  get_hour: (datetime: DateTime) -> number,
  get_minute: (datetime: DateTime) -> number,
  get_second: (datetime: DateTime) -> number,
  get_millisecond: (datetime: DateTime) -> number,
  get_epoch_milliseconds: (datetime: DateTime) -> number,
  get_timezone_offset: (datetime: DateTime) -> number,
  set_year: (datetime: DateTime, year: number) -> (),
  set_month: (datetime: DateTime, month: number) -> (),
  set_day: (datetime: DateTime, day: number) -> (),
  set_hour: (datetime: DateTime, hour: number) -> (),
  set_minute: (datetime: DateTime, min: number) -> (),
  set_second: (datetime: DateTime, sec: number) -> (),
  set_millisecond: (datetime: DateTime, milli: number) -> (),
  set_epoch_milliseconds: (datetime: DateTime, milli: number) -> (),
  set_time: (datetime: DateTime, hour: number, minute: number, second: number, millis: number) -> DateTime,
  set_date: (datetime: DateTime, year: number, month: number, day: number) -> DateTime,
  add_milliseconds: (datetime: DateTime, millis: number) -> DateTime,
  add_seconds: (datetime: DateTime, seconds: number) -> DateTime,
  add_minutes: (datetime: DateTime, minutes: number) -> DateTime,
  add_hours: (datetime: DateTime, hours: number) -> DateTime,
  add_days: (datetime: DateTime, days: number) -> DateTime,
  add_weeks: (datetime: DateTime, weeks: number) -> DateTime,
  add_months: (datetime: DateTime, months: number) -> DateTime,
  add_years: (datetime: DateTime, years: number) -> DateTime,
  sub_milliseconds: (datetime: DateTime, millis: number) -> DateTime,
  sub_seconds: (datetime: DateTime, seconds: number) -> DateTime,
  sub_minutes: (datetime: DateTime, minutes: number) -> DateTime,
  sub_hours: (datetime: DateTime, hours: number) -> DateTime,
  sub_days: (datetime: DateTime, days: number) -> DateTime,
  sub_weeks: (datetime: DateTime, weeks: number) -> DateTime,
  sub_months: (datetime: DateTime, months: number) -> DateTime,
  sub_years: (datetime: DateTime, years: number) -> DateTime,
  to_utc: (datetime: DateTime) -> DateTime,
  to_local: (datetime: DateTime) -> DateTime,
  to_rfc2822: (datetime: DateTime) -> string,
  to_rfc3339: (datetime: DateTime) -> string,
  to_format: (datetime: DateTime, format: string) -> string,
  to_date_string: (datetime: DateTime) -> string,
  to_time_string: (datetime: DateTime) -> string,
  to_datetime_string: (datetime: DateTime) -> string,
  to_iso_string: (datetime: DateTime) -> string,
  to_locale_date_string: (datetime: DateTime) -> string,
  to_locale_time_string: (datetime: DateTime) -> string,
  to_locale_datetime_string: (datetime: DateTime) -> string,
}

--- @param differentiator? string | number This field can be used to determine the type of DateTime. On empty it creates a new local DateTime, on number it starts the sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string to DateTime.
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
    return astra_internal__datetime_new_parse(differentiator)
  elseif type(differentiator) == "number" then
    return astra_internal__datetime_new_from(differentiator, month, day, hour, min, sec, milli)
  else
    return astra_internal__datetime_new_now()
  end
end

--- Stops the execution thread for a given amount of time in milliseconds
local function sleep(amount: number): ()
  return astra_internal__datetime_sleep(amount)
end

return { new = new_datetime, sleep = sleep }
