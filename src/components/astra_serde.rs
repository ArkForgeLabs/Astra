use mlua::{ExternalError, LuaSerdeExt};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    json_encode(lua)?;
    json_decode(lua)?;

    json5_encode(lua)?;
    json5_decode(lua)?;

    yaml_encode(lua)?;
    yaml_decode(lua)?;

    ini_encode(lua)?;
    ini_decode(lua)?;

    xml_encode(lua)?;
    xml_decode(lua)?;

    toml_encode(lua)?;
    toml_decode(lua)?;

    Ok(())
}

fn sanetize_lua_input(lua: &mlua::Lua, input: mlua::Value) -> mlua::Result<mlua::Value> {
    if let Some(input) = input.as_table() {
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

        lua.to_value(&new_input)
    } else {
        Ok(input)
    }
}

#[crabtime::function]
fn gen_methods(crate_name: String, name: String) {
    let encode_str = format!("\"astra_internal__{name}_encode\"");
    let decode_str = format!("\"astra_internal__{name}_decode\"");

    crabtime::output!(
        fn {{name}}_encode(lua: &mlua::Lua) -> mlua::Result<()> {
            lua.globals().set(
                {{encode_str}},
                lua.create_function(|lua, input: mlua::Value| {
                    let value =
                        lua.from_value::<serde_value::Value>(sanetize_lua_input(lua, input)?)?;
                    match {{crate_name}}::to_string(&value) {
                        Ok(serialized) => Ok(lua.to_value(&serialized)?),
                        Err(e) => Err(e.into_lua_err()),
                    }
                })?,
            )
        }

        fn {{name}}_decode(lua: &mlua::Lua) -> mlua::Result<()> {
            lua.globals().set(
                {{decode_str}},
                lua.create_function(|lua, input: String| {
                    match {{crate_name}}::from_str::<serde_value::Value>(&input) {
                        Ok(deserialized) => lua.to_value(&deserialized),
                        Err(e) => Err(e.into_lua_err()),
                    }
                })?,
            )
        }
    )
}

gen_methods!("serde_json", "json");
gen_methods!("serde_json5", "json5");
gen_methods!("serde_yaml", "yaml");
gen_methods!("serde_ini", "ini");
gen_methods!("serde_xml_rs", "xml");
gen_methods!("toml", "toml");
