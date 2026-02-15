use mlua::{LuaSerdeExt, UserData};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    dotenv_function(lua)?;
    invalidate_cache(lua)?;
    pprint(lua)?;
    pprintln(lua)?;
    AstraRegex::register_to_lua(lua)?;
    uuid_v4(lua)?;
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
        lua.create_function(|_, args: mlua::MultiValue| {
            for input in args.iter() {
                if let Ok(s) = input.to_string() {
                    print!("{} ", s);
                } else if input.is_userdata() {
                    print!("{input:?} ")
                } else {
                    print!("{input:#?} ")
                };
            }

            Ok(())
        })?,
    )
}
pub fn pprintln(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__pretty_println",
        lua.create_function(|_, args: mlua::MultiValue| {
            for input in args.iter() {
                if let Ok(s) = input.to_string() {
                    print!("{} ", s);
                } else if input.is_userdata() {
                    print!("{input:?} ")
                } else {
                    print!("{input:#?} ")
                };
            }
            println!();

            Ok(())
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

pub fn uuid_v4(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__uuid",
        lua.create_function(|lua, _: ()| lua.to_value(&uuid::Uuid::new_v4()))?,
    )
}

pub fn invalidate_cache(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__invalidate_cache",
        lua.create_function(|lua, path: String| {
            let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");

            if let Ok(cache) = lua
                .globals()
                .get::<Option<mlua::RegistryKey>>(key_id.clone())
                && let Some(key) = cache
            {
                lua.remove_registry_value(key)?;
            }

            lua.globals().raw_remove(key_id)?;

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

pub struct AstraRegex {
    re: regex::Regex,
}
impl AstraRegex {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_function(|_, regex_string: String| {
            match regex::Regex::new(&regex_string) {
                Ok(re) => Ok(Self { re }),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not compile the regex: {e}"
                ))),
            }
        })?;
        lua.globals().set("astra_internal__regex", function)?;

        Ok(())
    }
}
impl mlua::UserData for AstraRegex {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("captures", |_, this, content: String| {
            let captures = this
                .re
                .captures_iter(&content)
                .map(|capture| {
                    capture
                        .iter()
                        .filter_map(|content| content.map(|content| content.as_str().to_string()))
                        .collect::<Vec<_>>()
                })
                .collect::<Vec<_>>();

            Ok(captures)
        });

        methods.add_method("is_match", |_, this, content: String| {
            Ok(this.re.is_match(&content))
        });

        methods.add_method(
            "replace",
            |_, this, (content, replace, limit): (String, String, Option<usize>)| {
                Ok(this
                    .re
                    .replacen(&content, limit.unwrap_or_default(), replace)
                    .to_string())
            },
        );
    }
}
