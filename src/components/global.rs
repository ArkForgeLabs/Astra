use mlua::{LuaSerdeExt, UserData};

pub fn register_to_lua(lua: &mlua::Lua) {
    dotenv_function(lua);
    pprint(lua);
    // json
    json_encode(lua);
    json_decode(lua);
    // env
    getenv(lua);
    setenv(lua);
    // async tasks
    spawn_task(lua);
    spawn_interval(lua);
    spawn_timeout(lua);
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

pub fn pprint(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_function(|_, input: mlua::Value| {
        if input.is_userdata() {
            println!("{input:?}");
        } else {
            println!("{input:#?}");
        }

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
    if let Ok(function) = lua.create_function(|lua, key: String| {
        if let Ok(value) = std::env::var(key) {
            Ok(lua.to_value(&value)?)
        } else {
            Ok(mlua::Value::Nil)
        }
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

pub struct TaskHandler<T: Send + 'static> {
    pub handler: Option<tokio::task::JoinHandle<T>>,
}
impl<T: Send + 'static> UserData for TaskHandler<T> {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("abort", |_, this, ()| {
            let handler = this.handler.take();
            if let Some(handler) = handler {
                handler.abort();
            }
            Ok(())
        });

        methods.add_async_method_mut("await", |_, mut this, ()| async move {
            let handler = this.handler.take();
            if let Some(handler) = handler {
                // TODO: Handle the return
                let _ = handler.await;
            }
            Ok(())
        });
    }
}

fn create_async_function<F, T>(function: F) -> TaskHandler<T>
where
    F: Future<Output = T> + Send + 'static,
    T: Send + 'static,
{
    let handle = tokio::spawn(function);
    TaskHandler {
        handler: Some(handle),
    }
}

fn spawn_task(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_async_function(|_, callback: mlua::Function| async move {
        Ok(create_async_function(async move {
            if let Err(e) = callback.call_async::<()>(()).await {
                println!("Error running a task: {e}");
            }
        }))
    }) {
        if let Err(e) = lua.globals().set("astra_internal__spawn_task", function) {
            println!("Could not register the function for spawn_task: {e}");
        }
    }
}

fn spawn_timeout(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_async_function(
        |_, (callback, sleep_length): (mlua::Function, u64)| async move {
            Ok(create_async_function(async move {
                // sleep
                tokio::time::sleep(std::time::Duration::from_millis(sleep_length)).await;

                if let Err(e) = callback.call_async::<()>(()).await {
                    println!("Error running a task: {e}");
                }
            }))
        },
    ) {
        if let Err(e) = lua.globals().set("astra_internal__spawn_timeout", function) {
            println!("Could not register the function for spawn_timeout: {e}");
        }
    }
}

fn spawn_interval(lua: &mlua::Lua) {
    if let Ok(function) = lua.create_async_function(
        |_, (callback, sleep_length): (mlua::Function, u64)| async move {
            Ok(create_async_function(async move {
                loop {
                    if let Err(e) = callback.call_async::<()>(()).await {
                        println!("Error running a task: {e}");
                    }

                    // sleep
                    tokio::time::sleep(std::time::Duration::from_millis(sleep_length)).await;
                }
            }))
        },
    ) {
        if let Err(e) = lua
            .globals()
            .set("astra_internal__spawn_interval", function)
        {
            println!("Could not register the function for spawn_interval: {e}");
        }
    }
}
