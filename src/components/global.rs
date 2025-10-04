use mlua::{LuaSerdeExt, UserData};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    dotenv_function(lua)?;
    pprint(lua)?;
    // json
    json_encode(lua)?;
    json_decode(lua)?;
    // env
    getenv(lua)?;
    setenv(lua)?;
    // async tasks
    spawn_task(lua)?;
    spawn_interval(lua)?;
    spawn_timeout(lua)?;

    Ok(())
}

pub fn dotenv_function(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__dotenv_load",
        lua.create_function(|_, file_name: String| {
            let _ = dotenvy::from_filename_override(file_name);
            Ok(())
        })?,
    )
}

pub fn pprint(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__pretty_print",
        lua.create_function(|_, input: mlua::Value| {
            if let Some(input) = input.as_string() {
                println!("{}", input.to_string_lossy());
            } else if input.is_userdata() {
                println!("{input:?}");
            } else {
                println!("{input:#?}");
            }

            Ok(())
        })?,
    )
}

pub fn json_encode(lua: &mlua::Lua) -> mlua::Result<()> {
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
                Ok(serialized) => Ok(serialized),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not serialize the input into a valid JSON string: {e:?}"
                ))),
            }
        })?,
    )
}

pub fn json_decode(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__json_decode",
        lua.create_function(|lua, input: String| {
            match serde_json::from_str::<serde_json::Value>(&input) {
                Ok(deserialized) => Ok(lua.to_value(&deserialized)),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not deserialize the input into a valid Lua value: {e:?}"
                ))),
            }
        })?,
    )
}

pub fn getenv(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__getenv",
        lua.create_function(|lua, key: String| {
            if let Ok(value) = std::env::var(key) {
                Ok(lua.to_value(&value)?)
            } else {
                Ok(mlua::Value::Nil)
            }
        })?,
    )
}

pub fn setenv(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__setenv",
        lua.create_function(|_, (key, value): (String, String)| {
            unsafe { std::env::set_var(key, value) };

            Ok(())
        })?,
    )
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

fn spawn_task(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__spawn_task",
        lua.create_async_function(|_, callback: mlua::Function| async move {
            Ok(create_async_function(async move {
                if let Err(e) = callback.call_async::<()>(()).await {
                    println!("Error running a task: {e}");
                }
            }))
        })?,
    )
}

fn spawn_timeout(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__spawn_timeout",
        lua.create_async_function(
            |_, (callback, sleep_length): (mlua::Function, u64)| async move {
                Ok(create_async_function(async move {
                    // sleep
                    tokio::time::sleep(std::time::Duration::from_millis(sleep_length)).await;

                    if let Err(e) = callback.call_async::<()>(()).await {
                        println!("Error running a task: {e}");
                    }
                }))
            },
        )?,
    )
}

fn spawn_interval(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__spawn_interval",
        lua.create_async_function(
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
        )?,
    )
}
