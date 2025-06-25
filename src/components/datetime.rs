use chrono::{offset::LocalResult, prelude::*};
use mlua::UserData;

pub struct LuaDateTime {
    dt: DateTime<FixedOffset>,
}

impl super::AstraComponent for LuaDateTime {
    fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        lua.globals().set(
            "astra_internal__datetime_new_now",
            lua.create_function(|_, ()| {
                let dt = Local::now().fixed_offset();
                Ok(Self { dt })
            })?,
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

        lua.globals().set(
            "astra_internal__datetime_new_utc_now",
            lua.create_function(|_, ()| {
                let dt = Utc::now().fixed_offset();
                Ok(Self { dt })
            })?,
        )?;

        lua.globals().set(
            "astra_internal__datetime_new_utc_from",
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
            ($method_name:expr,$method:ident, $field_type:ty, $error_msg:expr) => {
                methods.add_method_mut($method_name, |_, this, field: $field_type| {
                    match this.dt.$method(field) {
                        Some(n) => {
                            this.dt = n;
                            Ok(())
                        }
                        None => Err(mlua::Error::runtime($error_msg)),
                    }
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
            match this.dt.with_nanosecond(field * 1_000_000) {
                Some(n) => {
                    this.dt = n;
                    Ok(())
                }
                None => Err(mlua::Error::runtime("Invalid millisecond!")),
            }
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

        add_formatted_method!("to_date_string", "%a %b %d %Y");
        add_formatted_method!("to_time_string", "%T %Z%z");
        add_formatted_method!("to_datetime_string", "%a %b %d %Y %T %Z%z");
        methods.add_method("to_iso_string", |_, this, ()| {
            Ok(this.dt.to_rfc3339_opts(SecondsFormat::Millis, false))
        });
        add_formatted_method!("to_locale_date_string", "%x");
        add_formatted_method!("to_locale_time_string", "%X");
        add_formatted_method!("to_locale_datetime_string", "%c");
    }
}
