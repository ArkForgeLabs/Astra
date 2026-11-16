use mlua::LuaSerdeExt;

use crate::components::SandboxFlags;

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__new_astra",
        lua.create_async_function(|lua, features: Option<mlua::Value>| async move {
            let features = features.unwrap_or(lua.to_value(&Vec::<SandboxFlags>::new())?);
            let features = lua.from_value::<Vec<SandboxFlags>>(features)?;

            Ok(AstraVM {
                lua: crate::create_lua_vm(false)?,
            })
        })?,
    )?;

    Ok(())
}

pub struct AstraVM {
    lua: mlua::Lua,
}
impl mlua::UserData for AstraVM {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method(
            "eval",
            |_, this, (content, name): (String, String)| async move {
                //
                this.lua
                    .load(content)
                    .set_name(name)
                    .eval_async::<mlua::Value>()
                    .await
            },
        );
    }
}
