use crate::AstraComponent;
use mlua::UserData;
use std::future::Future;

pub struct TaskHandler<T: Send + 'static>(tokio::task::JoinHandle<T>);

impl<T: Send + 'static> UserData for TaskHandler<T> {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("abort", |_, this, ()| {
            this.0.abort();
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
    TaskHandler(handle)
}

pub struct LuaTask {}
impl AstraComponent for LuaTask {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_async_function(|_, callback: mlua::Function| async move {
            Ok(create_async_function(async move {
                if let Err(e) = callback.call_async::<()>(()).await {
                    println!("Error running a task: {e}");
                }
            }))
        })?;

        lua.globals().set("astra_internal__spawn_task", function)
    }
}

pub struct LuaTimeout {}
impl AstraComponent for LuaTimeout {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_async_function(
            |_, (callback, sleep_length): (mlua::Function, u64)| async move {
                Ok(create_async_function(async move {
                    // sleep
                    tokio::time::sleep(std::time::Duration::from_millis(sleep_length)).await;

                    if let Err(e) = callback.call_async::<()>(()).await {
                        println!("Error running a task: {e}");
                    }
                }))
            },
        )?;

        lua.globals().set("astra_internal__spawn_timeout", function)
    }
}

pub struct LuaInterval {}
impl AstraComponent for LuaInterval {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_async_function(
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
        )?;

        lua.globals()
            .set("astra_internal__spawn_interval", function)
    }
}
