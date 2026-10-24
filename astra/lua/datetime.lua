---@meta

-- Setters mutate the DateTime in place and return an updated copy of it, so
-- chaining them requires reassignment: dt = dt:set_year(2030):set_month(6)
---@class DateTime
---@field get_year fun(datetime: DateTime): number
---@field get_month fun(datetime: DateTime): number
---@field get_day fun(datetime: DateTime): number
---@field get_weekday fun(datetime: DateTime): number
---@field get_hour fun(datetime: DateTime): number
---@field get_minute fun(datetime: DateTime): number
---@field get_second fun(datetime: DateTime): number
---@field get_millisecond fun(datetime: DateTime): number
---@field get_epoch_milliseconds fun(datetime: DateTime): number
---@field get_timezone_offset fun(datetime: DateTime): number
---@field set_year fun(datetime:DateTime, year: number): DateTime
---@field set_month fun(datetime:DateTime, month: number): DateTime
---@field set_day fun(datetime:DateTime, day: number): DateTime
---@field set_hour fun(datetime:DateTime, hour: number): DateTime
---@field set_minute fun(datetime:DateTime, min: number): DateTime
---@field set_second fun(datetime:DateTime, sec: number): DateTime
---@field set_millisecond fun(datetime:DateTime, milli: number): DateTime
---@field set_epoch_milliseconds fun(datetime: DateTime, milli: number): DateTime
---@field set_time fun(datetime: DateTime, hour: number, minute: number, second: number, millis: number): DateTime
---@field set_date fun(datetime: DateTime, year: number, month: number, day: number): DateTime
---@field add_milliseconds fun(datetime: DateTime, millis: number): DateTime
---@field add_seconds fun(datetime: DateTime, seconds: number): DateTime
---@field add_minutes fun(datetime: DateTime, minutes: number): DateTime
---@field add_hours fun(datetime: DateTime, hours: number): DateTime
---@field add_days fun(datetime: DateTime, days: number): DateTime
---@field add_weeks fun(datetime: DateTime, weeks: number): DateTime
---@field add_months fun(datetime: DateTime, months: number): DateTime
---@field add_years fun(datetime: DateTime, years: number): DateTime
---@field sub_milliseconds fun(datetime: DateTime, millis: number): DateTime
---@field sub_seconds fun(datetime: DateTime, seconds: number): DateTime
---@field sub_minutes fun(datetime: DateTime, minutes: number): DateTime
---@field sub_hours fun(datetime: DateTime, hours: number): DateTime
---@field sub_days fun(datetime: DateTime, days: number): DateTime
---@field sub_weeks fun(datetime: DateTime, weeks: number): DateTime
---@field sub_months fun(datetime: DateTime, months: number): DateTime
---@field sub_years fun(datetime: DateTime, years: number): DateTime
---@field to_utc fun(datetime: DateTime): DateTime
---@field to_local fun(datetime: DateTime): DateTime
---@field to_rfc2822 fun(datetime: DateTime): string
---@field to_rfc3339 fun(datetime: DateTime): string
---@field to_format fun(datetime: DateTime, format: string): string
---@field to_date_string fun(datetime: DateTime): string
---@field to_time_string fun(datetime: DateTime): string
---@field to_datetime_string fun(datetime: DateTime): string
---@field to_iso_string fun(datetime: DateTime): string
---@field to_locale_date_string fun(datetime: DateTime): string
---@field to_locale_time_string fun(datetime: DateTime): string
---@field to_locale_datetime_string fun(datetime: DateTime): string
---@field diff_milliseconds fun(datetime: DateTime, other: DateTime): number

---@type fun(differentiator?: string | number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@param differentiator? string | number This field can be used to determine the type of DateTime. On empty it creates a new local DateTime for the current moment, on number it starts the sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string (RFC 2822, RFC 3339, or `YYYY-MM-DD`) into a DateTime.
---@return DateTime
local function new_datetime(differentiator, month, day, hour, min, sec, milli)
  if type(differentiator) == "string" then
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__datetime_new_parse(differentiator)
  elseif type(differentiator) == "number" then
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__datetime_new_from(differentiator, month, day, hour, min, sec, milli)
  else
    ---@diagnostic disable-next-line: undefined-global
    return astra_internal__datetime_new_now()
  end
end

---Creates a DateTime from milliseconds since the Unix epoch, anchored to UTC (+00:00)
---@param millis number Milliseconds since the Unix epoch. Negative values are allowed.
---@return DateTime
local function from_epoch_millis(millis)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__datetime_new_from_epoch(millis)
end

---Stops the execution thread for a given amount of time in milliseconds
---@param amount integer
local function sleep(amount)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__datetime_sleep(amount)
end

return { new = new_datetime, sleep = sleep, from_epoch_millis = from_epoch_millis }
