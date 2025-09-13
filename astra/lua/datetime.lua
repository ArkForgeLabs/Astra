---@meta

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
---@field set_year fun(datetime:DateTime, year: number)
---@field set_month fun(datetime:DateTime, month: number)
---@field set_day fun(datetime:DateTime, day: number)
---@field set_hour fun(datetime:DateTime, hour: number)
---@field set_minute fun(datetime:DateTime, min: number)
---@field set_second fun(datetime:DateTime, sec: number)
---@field set_millisecond fun(datetime:DateTime, milli: number)
---@field set_epoch_milliseconds fun(datetime: DateTime, milli: number)
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

---@type fun(differentiator?: string | number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@param differentiator? string | number This field can be used to determine the type of DateTime. On empty it creates a new local DateTime, on number it starts te sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string to DateTime.
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

local datetime = {}

---@type fun(differentiator?: string | number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@param differentiator? string | number This field can be used to determine the type of DateTime. On empty it creates a new local DateTime, on number it starts te sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string to DateTime.
---@return DateTime
--- Creates a wrapper for a DateTime-like object
function datetime.new(differentiator, month, day, hour, min, sec, milli)
	-- Create real DateTime using datetime
	return new_datetime(differentiator, month, day, hour, min, sec, milli)
end

return datetime
