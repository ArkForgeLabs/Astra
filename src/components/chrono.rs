use chrono::{offset::LocalResult, prelude::*};
use mlua::UserData;

macro_rules! set_and_validate {
    ($x:expr, $method:ident, $arg:expr, $err_msg:expr) => {
        match $x.$method($arg) {
            Some(n) => {
                $x = n;
                Ok(())
            }
            None => Err(mlua::Error::runtime($err_msg)),
        }
    };
}

pub struct LuaDateTime {
    dt: DateTime<FixedOffset>,
}

impl super::AstraComponent for LuaDateTime {
    fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let table = lua.create_table()?;

        table.set(
            "astra_internal__datetime_new_now",
            lua.create_function(|_, ()| {
                let dt = Local::now().fixed_offset();
                Ok(Self { dt })
            })?,
        )?;

        table.set(
            "astra_internal__datetime_new_from",
            lua.create_function(
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
                    match NaiveDate::from_ymd_opt(year, month.unwrap_or(1), day.unwrap_or(1)) {
                        Some(naive_date) => {
                            match naive_date.and_hms_milli_opt(
                                hour.unwrap_or(0),
                                min.unwrap_or(0),
                                sec.unwrap_or(0),
                                milli.unwrap_or(0),
                            ) {
                                Some(naive_datetime) => {
                                    match naive_datetime.and_local_timezone(Local) {
                                        LocalResult::Single(dt) => Ok(Self {
                                            dt: dt.fixed_offset(),
                                        }),
                                        LocalResult::Ambiguous(earliest, _latest) => Ok(Self {
                                            dt: earliest.fixed_offset(),
                                        }),
                                        LocalResult::None => Err(mlua::Error::runtime(
                                            "Error while resolving local time!",
                                        )),
                                    }
                                }
                                None => Err(mlua::Error::runtime("Invalid time!")),
                            }
                        }
                        None => Err(mlua::Error::runtime("Invalid date!")),
                    }
                },
            )?,
        )?;

        table.set(
            "astra_internal__datetime_new_utc_now",
            lua.create_function(|_, ()| {
                let dt = Utc::now().fixed_offset();
                Ok(Self { dt })
            })?,
        )?;

        table.set(
            "astra_internal__datetime_new_utc_from",
            lua.create_function(
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
                    match NaiveDate::from_ymd_opt(year, month.unwrap_or(1), day.unwrap_or(1)) {
                        Some(naive_date) => {
                            match naive_date.and_hms_milli_opt(
                                hour.unwrap_or(0),
                                min.unwrap_or(0),
                                sec.unwrap_or(0),
                                milli.unwrap_or(0),
                            ) {
                                Some(naive_datetime) => Ok(Self {
                                    dt: naive_datetime.and_utc().fixed_offset(),
                                }),
                                None => Err(mlua::Error::runtime("Invalid time!")),
                            }
                        }
                        None => Err(mlua::Error::runtime("Invalid date!")),
                    }
                },
            )?,
        )?;

        Ok(())
    }
}

impl UserData for LuaDateTime {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("get_year", |_, this, ()| Ok(this.dt.year()));

        methods.add_method("get_month", |_, this, ()| Ok(this.dt.month()));

        methods.add_method("get_day", |_, this, ()| Ok(this.dt.day()));

        methods.add_method("get_weekday", |_, this, ()| {
            Ok(this.dt.weekday().num_days_from_sunday())
        });

        methods.add_method("get_hour", |_, this, ()| Ok(this.dt.hour()));

        methods.add_method("get_minute", |_, this, ()| Ok(this.dt.minute()));

        methods.add_method("get_second", |_, this, ()| Ok(this.dt.second()));

        methods.add_method("get_millisecond", |_, this, ()| {
            Ok(this.dt.timestamp_subsec_millis())
        });

        methods.add_method("get_epoch_milliseconds", |_, this, ()| {
            Ok(this.dt.timestamp_millis())
        });

        methods.add_method("get_timezone_offset", |_, this, ()| {
            Ok(this.dt.offset().local_minus_utc() / 60)
        });

        methods.add_method_mut("set_year", |_, this, year: i32| {
            set_and_validate!(this.dt, with_year, year, "Invalid Year!")
        });

        methods.add_method_mut("set_month", |_, this, month: u32| {
            set_and_validate!(this.dt, with_month, month, "Invalid month!")
        });

        methods.add_method_mut("set_day", |_, this, day: u32| {
            set_and_validate!(this.dt, with_day, day, "Invalid date!")
        });

        methods.add_method_mut("set_hour", |_, this, hour: u32| {
            set_and_validate!(this.dt, with_hour, hour, "Invalid hour!")
        });

        methods.add_method_mut("set_minute", |_, this, min: u32| {
            set_and_validate!(this.dt, with_minute, min, "Invalid minute!")
        });

        methods.add_method_mut("set_second", |_, this, sec: u32| {
            set_and_validate!(this.dt, with_second, sec, "Invalid second!")
        });

        methods.add_method_mut("set_millisecond", |_, this, milli: u32| {
            set_and_validate!(
                this.dt,
                with_nanosecond,
                milli * 1000000,
                "Invalid millisecond!"
            )
        });

        methods.add_method_mut("set_epoch_milliseconds", |_, this, milli: i64| {
            match DateTime::from_timestamp_millis(milli) {
                Some(dt) => {
                    this.dt = dt.with_timezone(&this.dt.timezone().fix());
                    Ok(())
                }
                None => Err(mlua::Error::runtime("Invalid millisecond!")),
            }
        });

        methods.add_method("to_date_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%a %b %d %Y")))
        });

        methods.add_method("to_time_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%T %Z%z")))
        });

        methods.add_method("to_datetime_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%a %b %d Y %T %Z%z")))
        });

        methods.add_method("to_iso_string", |_, this, ()| {
            Ok(this.dt.to_rfc3339_opts(SecondsFormat::Millis, false))
        });

        methods.add_method("to_locale_date_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%x")))
        });

        methods.add_method("to_locale_time_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%X")))
        });

        methods.add_method("to_locale_datetime_string", |_, this, ()| {
            Ok(format!("{}", this.dt.format("%c")))
        });
    }
}
