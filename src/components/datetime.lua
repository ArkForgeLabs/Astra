---@meta

Astra.datetime = {}

---@return DateTime
function Astra.datetime.new_now() end

---@type fun(year: number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
function Astra.datetime.new_from(year, month, day, hour, min, sec, milli) end

---@return DateTime
function Astra.datetime.new_utc_now() end

---@type fun(year: number, month: number?, day: number?, hour: number?, min: number?, sec: number?, milli: number?): DateTime
function Astra.datetime.new_utc_from(year, month, day, hour, min, sec, milli) end

---@class DateTime
local DateTime = {}

---@return number
function DateTime:get_year() end

---@return number
function DateTime:get_month() end

---@return number
function DateTime:get_day() end

---@return number
function DateTime:get_weekday() end

---@return number
function DateTime:get_hour() end

---@return number
function DateTime:get_minute() end

---@return number
function DateTime:get_second() end

---@return number
function DateTime:get_millisecond() end

---@return number
function DateTime:get_epoch_milliseconds() end

---@return number
function DateTime:get_timezone_offset() end

---@param year number
function DateTime:set_year(year) end

---@param month number
function DateTime:set_month(month) end

---@param day number
function DateTime:set_day(day) end

---@param hour number
function DateTime:set_hour(hour) end

---@param min number
function DateTime:set_minute(min) end

---@param sec number
function DateTime:set_second(sec) end

---@param milli number
function DateTime:set_millisecond(milli) end

---@param milli number
function DateTime:set_epoch_milliseconds(milli) end

---@return string?
function DateTime:to_date_string() end

---@return string?
function DateTime:to_time_string() end

---@return string?
function DateTime:to_datetime_string() end

---@return string?
function DateTime:to_iso_string() end

---@return string?
function DateTime:to_locale_date_string() end

---@return string?
function DateTime:to_locale_time_string() end

---@return string?
function DateTime:to_locale_datetime_string() end
