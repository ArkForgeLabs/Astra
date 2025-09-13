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
	metamethod __tostring: function(DateTime): string
	metamethod __concat: function(any, any): string
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

--- Creates a wrapper for a DateTime-like object
local function datetime(differentiator?: string | number, month?: number, day?: number, hour?: number, min?: number, sec?: number, milli?: number): DateTime
	return new_datetime(differentiator, month, day, hour, min, sec, milli)
end

return { new = datetime }
