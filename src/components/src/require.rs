use super::AstraComponent;
use mlua::RegistryKey;
use std::collections::HashMap;

pub struct LuaRequire {}
impl AstraComponent for LuaRequire {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        lua.globals().set(
            "astra_internal__require",
            lua.create_async_function(|lua, path: String| async move {
                if path.contains("astra_bundle") {
                    return Ok(mlua::Value::Nil);
                }

                let mut cache = lua
                    .globals()
                    .get::<HashMap<String, RegistryKey>>("ASTRA_INTERNAL__IMPORT_CACHE")
                    .unwrap_or_default();

                if let Some(key) = cache.get(&path) {
                    lua.registry_value::<mlua::Value>(key)
                } else {
                    let cleaned_path = path.replace(".", std::path::MAIN_SEPARATOR_STR);
                    let file = std::fs::read_to_string(format!("{cleaned_path}.lua"))?;
                    let result = lua
                        .load(file)
                        .set_name(cleaned_path)
                        .eval_async::<mlua::Value>()
                        .await?;

                    let key = lua.create_registry_value(&result)?;
                    cache.insert(path, key);
                    lua.globals().set("ASTRA_INTERNAL__IMPORT_CACHE", cache)?;

                    Ok(result)
                }
            })?,
        )?;

        Ok(())
    }
}
