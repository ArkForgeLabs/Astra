pub struct LuaTask {}
impl crate::utils::LuaUtils for LuaTask {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        // let function = lua.create_async_function(|_, callback: mlua::Function| async move {
        //     tokio::spawn(async move {
        //         if let Err(e) = callback.call_async::<()>(()).await {
        //             println!("Error running a task: {e}");
        //         }
        //     });

        //     Ok(())
        // })?;

        // lua.globals().set("new_task", function)

        Ok(())
    }
}
