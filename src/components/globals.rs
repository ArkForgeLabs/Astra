use mlua::LuaSerdeExt;

/// Registers Astra replacements and additions for the base-library globals.
pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    let safe_mode = crate::SAFE_MODE.load(std::sync::atomic::Ordering::Relaxed);

    lua.globals().set(
        "print",
        lua.create_function(|_, args: mlua::MultiValue| {
            for input in args.iter() {
                if (input.is_string() || input.is_error())
                    && let Ok(s) = input.to_string()
                {
                    print!("{} ", s);
                } else if input.is_userdata() {
                    print!("{input:?} ")
                } else {
                    print!("{input:#?} ")
                }
            }
            println!();
            Ok(())
        })?,
    )?;

    // env access as globals, filling the gap the disabled `os` library leaves
    lua.globals().set(
        "getenv",
        lua.create_function(move |lua, key: String| -> mlua::Result<mlua::Value> {
            if safe_mode {
                return Err(mlua::Error::runtime("getenv is disabled in safe mode"));
            }

            if let Ok(value) = std::env::var(key) {
                lua.to_value_with(
                    &value,
                    mlua::serde::SerializeOptions::new()
                        .serialize_none_to_null(false)
                        .serialize_unit_to_null(false),
                )
            } else {
                Ok(mlua::Value::Nil)
            }
        })?,
    )?;

    lua.globals().set(
        "setenv",
        lua.create_function(move |_, (key, value): (String, String)| {
            if !safe_mode {
                unsafe { std::env::set_var(key, value) };

                Ok(())
            } else {
                Err(mlua::Error::runtime("setenv is disabled in safe mode"))
            }
        })?,
    )?;

    // dofile/loadfile are the only base globals that reach the filesystem;
    // swap the C implementations for Astra ones with matching semantics
    // (loadfile -> nil + message on failure, dofile -> raises)
    lua.globals().set(
        "loadfile",
        lua.create_function(
            move |lua, filename: String| -> mlua::Result<mlua::MultiValue> {
                if !safe_mode {
                    match load_chunk(lua, &filename) {
                        Ok(chunk) => Ok(mlua::MultiValue::from_vec(vec![mlua::Value::Function(
                            chunk,
                        )])),
                        Err(e) => Ok(mlua::MultiValue::from_vec(vec![
                            mlua::Value::Nil,
                            mlua::Value::String(lua.create_string(e.to_string())?),
                        ])),
                    }
                } else {
                    Err(mlua::Error::runtime("loadfile is disabled in safe mode"))
                }
            },
        )?,
    )?;

    lua.globals().set(
        "dofile",
        lua.create_function(
            move |lua, filename: Option<String>| -> mlua::Result<mlua::MultiValue> {
                if !safe_mode {
                    let Some(filename) = filename else {
                        return Err(mlua::Error::runtime(
                            "bad argument #1 to 'dofile' (filename expected)",
                        ));
                    };
                    load_chunk(lua, &filename)?.call(())
                } else {
                    Err(mlua::Error::runtime("dofile is disabled in safe mode"))
                }
            },
        )?,
    )?;

    // environment-swap primitives can escape sandbox
    if safe_mode {
        #[cfg(any(
            feature = "lua51",
            feature = "luajit",
            feature = "luajit52",
            feature = "luau"
        ))]
        {
            lua.globals().set(
                "getfenv",
                lua.create_function(|_, ()| -> mlua::Result<()> {
                    Err(mlua::Error::runtime("getfenv is disabled in safe mode"))
                })?,
            )?;
            lua.globals().set(
                "setfenv",
                lua.create_function(|_, ()| -> mlua::Result<()> {
                    Err(mlua::Error::runtime("setfenv is disabled in safe mode"))
                })?,
            )?;
        }
    }

    Ok(())
}

fn load_chunk(lua: &mlua::Lua, filename: &str) -> mlua::Result<mlua::Function> {
    let source = std::fs::read_to_string(filename)
        .map_err(|e| mlua::Error::runtime(format!("cannot open {filename}: {e}")))?;

    // strip shebang lines, matching base loadfile behavior
    let source = source
        .lines()
        .filter(|line| !line.starts_with("#!"))
        .collect::<Vec<_>>()
        .join("\n");

    lua.load(source)
        .set_name(format!("@{filename}"))
        .into_function()
}
