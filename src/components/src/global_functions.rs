use mlua::LuaSerdeExt;

pub fn essential_global_functions(lua: &mlua::Lua) {
    dotenv_function(lua);
    pretty_print(lua);
    // json
    json_encode(lua);
    json_decode(lua);
    // env
    getenv(lua);
    setenv(lua);
}

pub fn dotenv_function(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|_, file_name: String| {
        let _ = dotenvy::from_filename_override(file_name);
        // eprintln!("Error loading a dotenv file: {e}");
        Ok(())
    }) {
        if let Err(e) = lua.globals().set("astra_internal__dotenv_load", function) {
            println!("Could not register the function for dotenv_load: {e}");
        }
    }
}

pub fn pretty_print(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|_, input: mlua::Value| {
        println!("{input:#?}");

        Ok(())
    }) {
        if let Err(e) = lua.globals().set("astra_internal__pretty_print", function) {
            println!("Could not register the function for pretty printing: {e}");
        }
    }
}

pub fn json_encode(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|lua, input: mlua::Value| {
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
            Ok(serialized) => Ok(serialized),
            Err(e) => Err(mlua::Error::runtime(format!(
                "Could not serialize the input into a valid JSON string: {e:?}"
            ))),
        }
    }) {
        if let Err(e) = lua.globals().set("astra_internal__json_encode", function) {
            println!("Could not register the function for JSON encoding: {e}");
        }
    }
}

pub fn json_decode(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|lua, input: String| {
        match serde_json::from_str::<serde_json::Value>(&input) {
            Ok(deserialized) => Ok(lua.to_value(&deserialized)),
            Err(e) => Err(mlua::Error::runtime(format!(
                "Could not deserialize the input into a valid Lua value: {e:?}"
            ))),
        }
    }) {
        if let Err(e) = lua.globals().set("astra_internal__json_decode", function) {
            println!("Could not register the function for JSON decoding: {e}");
        }
    }
}

pub fn getenv(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|lua, key: String| match std::env::var(key) {
        Ok(result) => Ok(lua.to_value(&result)),
        Err(e) => Err(mlua::Error::runtime(format!(
            "Could not fetch the environment variable: {e:?}"
        ))),
    }) {
        if let Err(e) = lua.globals().set("astra_internal__getenv", function) {
            println!("Could not register the function for getenv: {e}");
        }
    }
}

pub fn setenv(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|_, (key, value): (String, String)| {
        unsafe { std::env::set_var(key, value) };

        Ok(())
    }) {
        if let Err(e) = lua.globals().set("astra_internal__setenv", function) {
            println!("Could not register the function for setenv: {e}");
        }
    }
}
