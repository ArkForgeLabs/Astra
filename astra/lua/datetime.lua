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

---@class DateTime
local DateTimeWrapper = {}
DateTimeWrapper.__index = DateTimeWrapper

-- ! THIS CAN BE REUSED AS A LIB
local function create_proxy(wrapper_methods)
	local mt = {}

	mt.__index = function(self, key)
		-- Wrapper methods override everything
		if wrapper_methods[key] ~= nil then
			return wrapper_methods[key]
		end

		-- Then any per-instance value
		local val = rawget(self, key)
		if val ~= nil then
			return val
		end

		-- Fallback to underlying userdata/table
		local underlying = rawget(self, "_obj")
		local v = underlying[key]
		if type(v) == "function" then
			return function(_, ...)
				return v(underlying, ...)
			end
		else
			return v
		end
	end

	mt.__newindex = function(self, key, value)
		-- If wrapper defines it or instance has it—set on proxy
		if wrapper_methods[key] ~= nil or rawget(self, key) ~= nil then
			rawset(self, key, value)
		else
			local underlying = rawget(self, "_obj")
			local setter = underlying["set_" .. key]
			if type(setter) == "function" then
				setter(underlying, value)
			else
				underlying[key] = value
			end
		end
	end

	mt.__tostring = function(self)
		local u = rawget(self, "_obj")
		return (u.to_string and u:to_string()) or tostring(u)
	end

	mt.__concat = function(a, b)
		return tostring(a) .. tostring(b)
	end

	return mt
end

-- General wrapper factory
local function wrap(obj, wrapper_methods)
	assert(type(obj) == "userdata" or type(obj) == "table", "Can only wrap userdata or tables")
	local proxy = { _obj = obj }
	setmetatable(proxy, create_proxy(wrapper_methods or {}))
	return proxy
end

---@type fun(differentiator: string | number | nil, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@param differentiator string | number | nil This field can be used to determine the type of DateTime. On empty it creates a new local DateTime, on number it starts te sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string to DateTime.
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

Astra.datetime = {}

---@type fun(differentiator: string | number | nil, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
---@param differentiator string | number | nil This field can be used to determine the type of DateTime. On empty it creates a new local DateTime, on number it starts te sequence for letting you define the DateTime by parameters, and on string it allows you to parse a string to DateTime.
---@return DateTime
--- Creates a wrapper for a DateTime-like object
function Astra.datetime.new(differentiator, month, day, hour, min, sec, milli)
	-- Create real DateTime using Astra.datetime
	local real_dt = new_datetime(differentiator, month, day, hour, min, sec, milli)
	return wrap(real_dt, DateTimeWrapper)
end
