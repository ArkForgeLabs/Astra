use mlua::{ExternalError, LuaSerdeExt};
use paste::paste;

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    json_encode(lua)?;
    json_decode(lua)?;

    json5_encode(lua)?;
    json5_decode(lua)?;

    yaml_encode(lua)?;
    yaml_decode(lua)?;

    ini_encode(lua)?;
    ini_decode(lua)?;

    toml_encode(lua)?;
    toml_decode(lua)?;

    csv_decode(lua)?;

    xml_encode(lua)?;
    xml_decode(lua)?;

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

macro_rules! gen_methods {
    ($crate_name:ident, $name:ident) => {
        paste! {
            fn [<$name _encode>](lua: &mlua::Lua) -> mlua::Result<()> {
                lua.globals().set(
                    "astra_internal__".to_string() + stringify!($name) + "_encode",
                    lua.create_function(|lua, input: mlua::Value| {
                        let value =
                            lua.from_value::<serde_json::Value>(sanetize_lua_input(&lua, input)?)?;
                        match $crate_name::to_string(&value) {
                            Ok(serialized) => Ok(lua.to_value(&serialized)?),
                            Err(e) => Err(e.into_lua_err()),
                        }
                    })?,
                )
            }

            fn [<$name _decode>](lua: &mlua::Lua) -> mlua::Result<()> {
                lua.globals().set(
                    "astra_internal__".to_string() + stringify!($name) + "_decode",
                    lua.create_function(|lua, input: String| {
                        match $crate_name::from_str::<serde_json::Value>(&input) {
                            Ok(deserialized) => lua.to_value(&deserialized),
                            Err(e) => Err(e.into_lua_err()),
                        }
                    })?,
                )
            }
        }
    };
}

gen_methods!(serde_json, json);
gen_methods!(serde_json5, json5);
gen_methods!(serde_yaml, yaml);
gen_methods!(serde_ini, ini);
gen_methods!(toml, toml);

fn xml_encode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__xml_encode",
        lua.create_async_function(|lua, (root, input): (String, mlua::Value)| async move {
            //
            let value = lua.from_value::<serde_value::Value>(sanetize_lua_input(&lua, input)?)?;
            match quick_xml::se::to_string_with_root(&root, &value) {
                Ok(serialized) => Ok(lua.to_value(&serialized)?),
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )
}

fn xml_decode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__xml_decode",
        lua.create_function(|lua, input: String| {
            let result = quick_xml::de::from_str::<serde_value::Value>(&input);

            match result {
                Ok(res) => lua.to_value(&res),
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )
}

fn csv_decode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__csv_decode",
        lua.create_function(|lua, (input, settings): (String, Option<mlua::Table>)| {
            let mut reader = csv::ReaderBuilder::new();

            if let Some(settings) = settings {
                if let Ok(buffer_capacity) = settings.get::<usize>("buffer_capacity") {
                    reader.buffer_capacity(buffer_capacity);
                }

                if let Ok(value) = settings.get::<String>("delimiter")
                    && let Some(value) = value.as_bytes().first()
                {
                    reader.delimiter(*value);
                }

                if let Ok(value) = settings.get::<String>("quote")
                    && let Some(value) = value.as_bytes().first()
                {
                    reader.quote(*value);
                }

                macro_rules! gen_fields {
                    ($field:ident) => {
                        if let Ok(value) = settings.get::<bool>(stringify!($field)) {
                            reader.$field(value);
                        }
                    };
                    ($field:ident, $type:ty) => {
                        if let Ok(value) = settings.get::<$type>(stringify!($field)) {
                            reader.$field(value.as_bytes().first().cloned());
                        }
                    };
                }

                gen_fields!(flexible);
                gen_fields!(quoting);
                gen_fields!(double_quote);
                gen_fields!(has_headers);
                gen_fields!(escape, String);
                gen_fields!(comment, String);
            }

            let mut reader = reader.from_reader(input.as_bytes());

            let header = reader
                .headers()
                .and_then(|i| i.deserialize::<Vec<serde_value::Value>>(None))
                .ok();
            let body = reader
                .into_byte_records()
                .filter_map(|x| {
                    println!("{x:?}");
                    x.and_then(|i| i.deserialize::<Vec<serde_value::Value>>(None))
                        .ok()
                })
                .collect::<Vec<_>>();

            lua.to_value(&(body, header))
        })?,
    )
}
