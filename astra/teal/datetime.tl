global interface DateTime is userdata
	get_year: function(self: DateTime): number
	get_month: function(self: DateTime): number
	get_day: function(self: DateTime): number
	get_weekday: function(self: DateTime): number
	get_hour: function(self: DateTime): number
	get_minute: function(self: DateTime): number
	get_second: function(self: DateTime): number
	get_millisecond: function(self: DateTime): number
	get_epoch_milliseconds: function(self: DateTime): number
	get_timezone_offset: function(self: DateTime): number
	set_year: function(self:DateTime, year: number)
	set_month: function(self:DateTime, month: number)
	set_day: function(self:DateTime, day: number)
	set_hour: function(self:DateTime, hour: number)
	set_minute: function(self:DateTime, min: number)
	set_second: function(self:DateTime, sec: number)
	set_millisecond: function(self:DateTime, milli: number)
	set_epoch_milliseconds: function(self: DateTime, milli: number)
	to_utc: function(self: DateTime): DateTime
	to_local: function(self: DateTime): DateTime
	to_rfc2822: function(self: DateTime): string
	to_rfc3339: function(self: DateTime): string
	to_format: function(self: DateTime, format: string): string
	to_date_string: function(self: DateTime): string
	to_time_string: function(self: DateTime): string
	to_datetime_string: function(self: DateTime): string
	to_iso_string: function(self: DateTime): string
	to_locale_date_string: function(self: DateTime): string
	to_locale_time_string: function(self: DateTime): string
	to_locale_datetime_string: function(self: DateTime): string
	add_milliseconds: function(self: DateTime, millis: number): DateTime
	add_seconds: function(self: DateTime, seconds: number): DateTime
	add_minutes: function(self: DateTime, minutes: number): DateTime
	add_hours: function(self: DateTime, hours: number): DateTime
	add_days: function(self: DateTime, days: number): DateTime
	add_weeks: function(self: DateTime, weeks: number): DateTime
	add_months: function(self: DateTime, months: number): DateTime
	add_years: function(self: DateTime, years: number): DateTime
	sub_milliseconds: function(self: DateTime, millis: number): DateTime
	sub_seconds: function(self: DateTime, seconds: number): DateTime
	sub_minutes: function(self: DateTime, minutes: number): DateTime
	sub_hours: function(self: DateTime, hours: number): DateTime
	sub_days: function(self: DateTime, days: number): DateTime
	sub_weeks: function(self: DateTime, weeks: number): DateTime
	sub_months: function(self: DateTime, months: number): DateTime
	sub_years: function(self: DateTime, years: number): DateTime
	set_time: function(self: DateTime, hour: number, minute: number, second: number, millis: number): DateTime
	set_date: function(self: DateTime, year: number, month: number, day: number): DateTime
	metamethod __tostring: function(DateTime): string
	metamethod __concat: function(DateTime, DateTime): string
	metamethod __eq: function(DateTime, DateTime): boolean
	metamethod __le: function(DateTime, DateTime): boolean
	metamethod __lt: function(DateTime, DateTime): boolean
end

local type astra_internal__datetime_new_parse = function(differentiator?: string | number): DateTime
local type astra_internal__datetime_new_from = function(differentiator?: string | number, month?: number, day?: number, hour?: number, min?: number, sec?: number, milli?: number): DateTime
local type astra_internal__datetime_new_now = function(): DateTime
local function new_datetime(differentiator?: string | number, month?: number, day?: number, hour?: number, min?: number, sec?: number, milli?: number): DateTime
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

local type astra_internal__datetime_sleep = function(amount: integer): nil
local function sleep(amount: integer): nil
  astra_internal__datetime_sleep(amount)
end

return { new = new_datetime, sleep = sleep }
