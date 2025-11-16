use mlua::{ExternalError, LuaSerdeExt};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    // json
    json_encode(lua)?;
    json_decode(lua)?;

    Ok(())
}

fn json_encode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__json_encode",
        lua.create_function(|lua, input: mlua::Value| {
            // removing functions
            let input = if let Some(input) = input.as_table() {
                let new_input = lua.create_table()?;

                for pair in input.pairs::<mlua::Value, mlua::Value>() {
                    let (key, value) = pair?;
                    if !value.is_function()
                        && !value.is_light_userdata()
                        && !value.is_userdata()
                        && !value.is_error()
                        && !value.is_thread()
                    {
                        new_input.set(key, value)?;
                    }
                }

                lua.to_value(&new_input)?
            } else {
                input
            };

            let json_value = lua.from_value::<serde_json::Value>(input)?;
            match serde_json::to_string(&json_value) {
                Ok(serialized) => Ok(lua.to_value(&serialized)?),
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )
}

fn json_decode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__json_decode",
        lua.create_function(|lua, input: String| {
            match serde_json::from_str::<serde_json::Value>(&input) {
                Ok(deserialized) => lua.to_value(&deserialized),
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )
}
