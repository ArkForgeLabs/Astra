use mlua::LuaSerdeExt;

/// Installs error stubs for dangerous base/builtin globals in restricted VMs.
pub fn sanitize_base(lua: &mlua::Lua) -> mlua::Result<()> {
    // These globals are restricted in sandboxed VMs unless explicitly allowed
    for name in [
        "print",
        "load",
        "loadstring",
        "loadfile",
        "dofile",
        "getfenv",
        "setfenv",
    ] {
        let message = format!("{name} is disabled in safe mode");
        lua.globals().set(
            name,
            lua.create_function(move |_, _: mlua::MultiValue| -> mlua::Result<()> {
                Err(mlua::Error::runtime(message.clone()))
            })?,
        )?;
    }

    // luau keeps a broken native one, so it is removed
    // explicitly to match. The import component installs its own require.
    lua.globals().set("require", mlua::Value::Nil)?;

    Ok(())
}

/// Registers Astra replacements and additions for the base-library globals.
pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
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
            unsafe { std::env::set_var(key, value) };

            Ok(())
        })?,
    )?;

    // dofile/loadfile are the only base globals that reach the filesystem;
    // swap the C implementations for Astra ones with matching semantics
    // (loadfile -> nil + message on failure, dofile -> raises)
    lua.globals().set(
        "loadfile",
        lua.create_function(
            move |lua, filename: String| -> mlua::Result<mlua::MultiValue> {
                match load_chunk(lua, &filename) {
                    Ok(chunk) => Ok(mlua::MultiValue::from_vec(vec![mlua::Value::Function(
                        chunk,
                    )])),
                    Err(e) => Ok(mlua::MultiValue::from_vec(vec![
                        mlua::Value::Nil,
                        mlua::Value::String(lua.create_string(e.to_string())?),
                    ])),
                }
            },
        )?,
    )?;

    lua.globals().set(
        "dofile",
        lua.create_function(
            move |lua, filename: Option<String>| -> mlua::Result<mlua::MultiValue> {
                let Some(filename) = filename else {
                    return Err(mlua::Error::runtime(
                        "bad argument #1 to 'dofile' (filename expected)",
                    ));
                };
                load_chunk(lua, &filename)?.call(())
            },
        )?,
    )?;

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
