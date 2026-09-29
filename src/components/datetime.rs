use chrono::{Days, LocalResult, Months, prelude::*};
use mlua::{FromLua, MetaMethod, UserData};

#[derive(Debug, Clone, FromLua)]
pub struct AstraDateTime {
    dt: DateTime<FixedOffset>,
}
impl AstraDateTime {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        lua.globals().set(
            "astra_internal__datetime_sleep",
            lua.create_async_function(|_, amount: u64| async move {
                tokio::time::sleep(std::time::Duration::from_millis(amount)).await;
                Ok(())
            })?,
        )?;

        lua.globals().set(
            "astra_internal__datetime_new_now",
            lua.create_function(|_, ()| {
                Ok(Self {
                    dt: Local::now().fixed_offset(),
                })
            })?,
        )?;

        lua.globals().set(
            "astra_internal__datetime_new_parse",
            lua.create_function(|_, date_str: String| Self::parse_datetime(&date_str))?,
        )?;

        lua.globals().set(
            "astra_internal__datetime_new_from",
            lua.create_function(
                #[allow(clippy::type_complexity)]
                |_,
                 (year, month, day, hour, min, sec, milli): (
                    i32,
                    Option<u32>,
                    Option<u32>,
                    Option<u32>,
                    Option<u32>,
                    Option<u32>,
                    Option<u32>,
                )| {
                    let naive_datetime =
                        NaiveDate::from_ymd_opt(year, month.unwrap_or(1), day.unwrap_or(1))
                            .and_then(|naive_date| {
                                naive_date.and_hms_milli_opt(
                                    hour.unwrap_or_default(),
                                    min.unwrap_or_default(),
                                    sec.unwrap_or_default(),
                                    milli.unwrap_or_default(),
                                )
                            })
                            .ok_or_else(|| mlua::Error::runtime("Invalid date or time!"))?;
                    Self::from_local_naive(naive_datetime)
                },
            )?,
        )?;

        lua.globals().set(
            "astra_internal__datetime_new_from_epoch",
            lua.create_function(|_, millis: i64| {
                DateTime::from_timestamp_millis(millis)
                    .map(|dt| Self {
                        dt: dt.fixed_offset(),
                    })
                    .ok_or_else(|| mlua::Error::runtime("Invalid millisecond value!"))
            })?,
        )?;

        Ok(())
    }

    /// Parses a date string by first classifying its category, then attempting
    /// only the matching parser and erroring early with its specific message.
    fn parse_datetime(date_str: &str) -> mlua::Result<Self> {
        let bytes = date_str.as_bytes();
        if bytes.len() >= 5 && bytes[4] == b'-' {
            if bytes.len() == 10 {
                let naive_date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                    .map_err(|err| Self::parse_error("date-only", date_str, err))?;
                let naive_datetime = naive_date
                    .and_hms_milli_opt(0, 0, 0, 0)
                    .ok_or_else(|| mlua::Error::runtime("Error while resolving local time!"))?;
                Self::from_local_naive(naive_datetime)
            } else {
                DateTime::parse_from_rfc3339(date_str)
                    .map(|dt| Self { dt })
                    .map_err(|err| Self::parse_error("RFC 3339", date_str, err))
            }
        } else {
            DateTime::parse_from_rfc2822(date_str)
                .map(|dt| Self { dt })
                .map_err(|err| Self::parse_error("RFC 2822", date_str, err))
        }
    }

    fn parse_error(category: &str, date_str: &str, err: impl std::fmt::Display) -> mlua::Error {
        mlua::Error::runtime(format!(
            "Invalid date string ({category}): {date_str}\nERR: {err}"
        ))
    }

    /// Resolves a naive datetime against the local timezone, preferring the
    /// earliest instant in case of ambiguity.
    fn from_local_naive(naive_datetime: NaiveDateTime) -> mlua::Result<Self> {
        match naive_datetime.and_local_timezone(Local) {
            LocalResult::Single(dt) | LocalResult::Ambiguous(dt, _) => Ok(Self {
                dt: dt.fixed_offset(),
            }),
            LocalResult::None => Err(mlua::Error::runtime("Error while resolving local time!")),
        }
    }

    /// Replaces the underlying datetime and returns an updated copy of self.
    fn with_replaced(
        &mut self,
        dt: Option<DateTime<FixedOffset>>,
        error: &str,
    ) -> mlua::Result<Self> {
        match dt {
            Some(dt) => {
                self.dt = dt;
                Ok(self.clone())
            }
            None => Err(mlua::Error::runtime(error)),
        }
    }

    fn shift_months(&self, months: i32) -> Option<Self> {
        let dt = if months >= 0 {
            self.dt.checked_add_months(Months::new(months as u32))?
        } else {
            self.dt
                .checked_sub_months(Months::new(months.unsigned_abs()))?
        };
        Some(Self { dt })
    }

    fn shift_years(&self, years: i32) -> Option<Self> {
        self.shift_months(years.checked_mul(12)?)
    }

    fn shift_days(&self, days: i64) -> Option<Self> {
        let dt = if days >= 0 {
            self.dt.checked_add_days(Days::new(days as u64))?
        } else {
            self.dt.checked_sub_days(Days::new(days.unsigned_abs()))?
        };
        Some(Self { dt })
    }

    fn shift_weeks(&self, weeks: i64) -> Option<Self> {
        self.shift_days(weeks.checked_mul(7)?)
    }
}

impl UserData for AstraDateTime {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        macro_rules! add_getter_method {
            ($method_name:expr, $field:ident) => {
                methods.add_method($method_name, |_, this, ()| Ok(this.dt.$field()));
            };
            ($method_name:expr, $field:ident, $conversion:expr) => {
                methods.add_method($method_name, |_, this, ()| {
                    Ok($conversion(this.dt.$field()))
                });
            };
        }
        macro_rules! add_setter_method {
            ($method_name:expr, $method:ident, $field_type:ty, $error_msg:expr) => {
                methods.add_method_mut($method_name, |_, this, field: $field_type| {
                    let new_dt = this.dt.$method(field);
                    this.with_replaced(new_dt, $error_msg)
                });
            };
        }
        macro_rules! add_formatted_method {
            ($method_name:expr, $format_str:expr) => {
                methods.add_method($method_name, |_, this, ()| {
                    Ok(format!("{}", this.dt.format($format_str)))
                });
            };
            ($method_name:expr, $operation:expr) => {
                methods.add_method($method_name, |_, this, ()| Ok($operation));
            };
        }
        macro_rules! add_to_datetime {
            ($method_name:expr, $method:ident) => {
                methods.add_method($method_name, |_, this, millis: i64| {
                    match this
                        .dt
                        .checked_add_signed(chrono::TimeDelta::$method(millis))
                    {
                        Some(delta) => Ok(Self { dt: delta }),
                        None => Err(mlua::Error::runtime("Invalid value")),
                    }
                });
            };
        }
        macro_rules! sub_from_datetime {
            ($method_name:expr, $method:ident) => {
                methods.add_method($method_name, |_, this, millis: i64| {
                    match this
                        .dt
                        .checked_sub_signed(chrono::TimeDelta::$method(millis))
                    {
                        Some(delta) => Ok(Self { dt: delta }),
                        None => Err(mlua::Error::runtime("Invalid value")),
                    }
                });
            };
        }
        macro_rules! add_shift_method {
            ($method_name:expr, $shift:ident, $amount:ty) => {
                methods.add_method($method_name, |_, this, amount: $amount| {
                    this.$shift(amount)
                        .ok_or_else(|| mlua::Error::runtime("Invalid value"))
                });
            };
            ($method_name:expr, $shift:ident, $amount:ty, neg) => {
                methods.add_method($method_name, |_, this, amount: $amount| {
                    this.$shift(amount.wrapping_neg())
                        .ok_or_else(|| mlua::Error::runtime("Invalid value"))
                });
            };
        }

        add_getter_method!("get_year", year);
        add_getter_method!("get_month", month);
        add_getter_method!("get_day", day);
        add_getter_method!("get_weekday", weekday, |w: Weekday| w
            .num_days_from_sunday());
        add_getter_method!("get_hour", hour);
        add_getter_method!("get_minute", minute);
        add_getter_method!("get_second", second);
        add_getter_method!("get_millisecond", timestamp_subsec_millis);
        add_getter_method!("get_epoch_milliseconds", timestamp_millis);
        add_getter_method!("get_timezone_offset", offset, |offset: &FixedOffset| offset
            .local_minus_utc()
            / 60);

        add_setter_method!("set_year", with_year, i32, "Invalid year!");
        add_setter_method!("set_month", with_month, u32, "Invalid month!");
        add_setter_method!("set_day", with_day, u32, "Invalid day!");
        add_setter_method!("set_hour", with_hour, u32, "Invalid hour!");
        add_setter_method!("set_minute", with_minute, u32, "Invalid minute!");
        add_setter_method!("set_second", with_second, u32, "Invalid second!");

        methods.add_method_mut("set_millisecond", |_, this, field: u32| {
            let new_dt = (field <= 999)
                .then(|| field * 1_000_000)
                .and_then(|nanos| this.dt.with_nanosecond(nanos));
            this.with_replaced(new_dt, "Invalid millisecond!")
        });
        methods.add_method_mut("set_epoch_milliseconds", |_, this, milli: i64| {
            let new_dt = DateTime::from_timestamp_millis(milli)
                .map(|dt| dt.with_timezone(&this.dt.timezone().fix()));
            this.with_replaced(new_dt, "Invalid millisecond!")
        });

        add_to_datetime!("add_milliseconds", milliseconds);
        add_to_datetime!("add_seconds", seconds);
        add_to_datetime!("add_minutes", minutes);
        add_to_datetime!("add_hours", hours);
        sub_from_datetime!("sub_milliseconds", milliseconds);
        sub_from_datetime!("sub_seconds", seconds);
        sub_from_datetime!("sub_minutes", minutes);
        sub_from_datetime!("sub_hours", hours);

        add_shift_method!("add_days", shift_days, i64);
        add_shift_method!("add_weeks", shift_weeks, i64);
        add_shift_method!("add_months", shift_months, i32);
        add_shift_method!("add_years", shift_years, i32);
        add_shift_method!("sub_days", shift_days, i64, neg);
        add_shift_method!("sub_weeks", shift_weeks, i64, neg);
        add_shift_method!("sub_months", shift_months, i32, neg);
        add_shift_method!("sub_years", shift_years, i32, neg);

        methods.add_method("diff_milliseconds", |_, this, other: Self| {
            Ok((this.dt - other.dt).num_milliseconds())
        });

        methods.add_method_mut(
            "set_time",
            |_, this, (hour, minute, second, millis): (u32, u32, u32, u32)| {
                let new_dt = (millis <= 999)
                    .then(|| millis * 1_000_000)
                    .and_then(|nanos| {
                        this.dt
                            .with_hour(hour)
                            .and_then(|dt| dt.with_minute(minute))
                            .and_then(|dt| dt.with_second(second))
                            .and_then(|dt| dt.with_nanosecond(nanos))
                    });
                this.with_replaced(new_dt, "Invalid time values")
            },
        );

        methods.add_method_mut(
            "set_date",
            |_, this, (year, month, day): (i32, u32, u32)| {
                let new_dt = this
                    .dt
                    .with_year(year)
                    .and_then(|dt| dt.with_month(month))
                    .and_then(|dt| dt.with_day(day));
                this.with_replaced(new_dt, "Invalid date values")
            },
        );

        methods.add_method("to_utc", |_, this, _: ()| {
            Ok(Self {
                dt: this.dt.to_utc().fixed_offset(),
            })
        });
        methods.add_method("to_local", |_, this, _: ()| {
            Ok(Self {
                dt: this.dt.with_timezone(&Local).fixed_offset(),
            })
        });

        add_getter_method!("to_rfc2822", to_rfc2822);
        add_getter_method!("to_rfc3339", to_rfc3339);
        add_getter_method!("to_datetime_string", to_rfc3339);
        add_formatted_method!("to_date_string", "%Y-%m-%d");
        add_formatted_method!("to_time_string", "%H:%M:%S%.3f%:z");
        add_formatted_method!("to_locale_date_string", "%x");
        add_formatted_method!("to_locale_time_string", "%X");
        add_formatted_method!("to_locale_datetime_string", "%c");

        methods.add_method("to_iso_string", |_, this, ()| {
            Ok(this.dt.to_rfc3339_opts(SecondsFormat::Millis, false))
        });
        methods.add_method("to_format", |_, this, format: String| {
            Ok(this.dt.format(&format).to_string())
        });

        // meta methods
        methods.add_meta_method(MetaMethod::ToString, |_, this, _: ()| {
            Ok(this.dt.to_rfc3339())
        });
        methods.add_meta_method(MetaMethod::Concat, |_, this, other: mlua::Value| {
            Ok(this.dt.to_rfc3339() + &other.to_string()?)
        });
        methods.add_meta_method(MetaMethod::Eq, |_, this, other: Self| {
            Ok(this.dt == other.dt)
        });
        methods.add_meta_method(MetaMethod::Le, |_, this, other: Self| {
            Ok(this.dt <= other.dt)
        });
        methods.add_meta_method(
            MetaMethod::Lt,
            |_, this, other: Self| Ok(this.dt < other.dt),
        );
        methods.add_meta_method(MetaMethod::Sub, |_, this, other: Self| {
            Ok((this.dt - other.dt).num_milliseconds())
        });
    }
}
