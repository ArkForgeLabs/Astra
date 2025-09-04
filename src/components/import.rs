
// TODO: Change into require syntax instead of global Astra table.
// TODO: Have the modules loaded from packed ones if none are available on the path

fn parse_lua_path(lua_path: &str, module_name: &str) -> Vec<std::path::PathBuf> {
    lua_path
        // Split by semicolons
        .split(';')
        // Filter out empty entries
        .filter(|s| !s.is_empty())
        // Replace '?' with the module name
        .map(|pattern| pattern.replacen('?', module_name, 1))
        // Convert to PathBuf
        .map(std::path::PathBuf::from)
        // Check for .lua and .tl files
        .flat_map(|pattern| {
            let mut candidates = Vec::new();

            // Try .lua extension
            let lua_path = pattern.with_extension("lua");
            if std::fs::metadata(&lua_path).is_ok() {
                candidates.push(lua_path);
            }

            // Try .tl extension
            let tl_path = pattern.with_extension("tl");
            if std::fs::metadata(&tl_path).is_ok() {
                candidates.push(tl_path);
            }

            // Try without extension (for directories or init.lua/init.tl)
            if std::fs::metadata(&pattern).is_ok() {
                candidates.push(pattern.clone());
            }

            // Try appending /init.lua
            let init_lua_path = pattern.join("init.lua");
            if std::fs::metadata(&init_lua_path).is_ok() {
                candidates.push(init_lua_path);
            }

            // Try appending /init.tl
            let init_tl_path = pattern.join("init.tl");
            if std::fs::metadata(&init_tl_path).is_ok() {
                candidates.push(init_tl_path);
            }

            candidates
        })
        .collect()
}

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";

pub fn register_import_function(lua: &mlua::Lua) -> mlua::Result<()> {
lua.globals().set("require", lua.create_async_function(|lua, path: String| async move {
        let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");
        let key_id = key_id.as_str();

        let mut cache = lua
            .globals()
            .get::<std::collections::HashMap<String, mlua::RegistryKey>>(key_id)
            .unwrap_or_default();

        if let Some(key) = cache.get(&path) {
            lua.registry_value::<mlua::Value>(key)
        } else {
            let cleaned_path = path.replace(".", std::path::MAIN_SEPARATOR_STR);

            let file: String;
            if std::fs::exists(format!("{cleaned_path}.tl")).unwrap_or(false) {
                let file_content = tokio::fs::read_to_string(format!("{cleaned_path}.tl")).await?;

                file = format!(
                    "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[{file_content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{cleaned_path}.tl\")()"
                )
            } else if std::fs::exists(format!("{cleaned_path}.teal")).unwrap_or(false) {
                let file_content = tokio::fs::read_to_string(format!("{cleaned_path}.teal")).await?;

                file = format!(
                    "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[{file_content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{cleaned_path}.teal\")()"
                )
            } else if std::fs::exists(format!("{cleaned_path}.lua")).unwrap_or(false) {
                file = tokio::fs::read_to_string(format!("{cleaned_path}.lua")).await?;
            } else {
                 return Err(mlua::Error::runtime(format!("Could not find the file: {cleaned_path}")));
            } 

            let result = lua
                .load(file)
                .set_name(cleaned_path)
                .eval_async::<mlua::Value>()
                .await?;

            let key = lua.create_registry_value(&result)?;
            cache.insert(path, key);
            lua.globals().set(key_id, cache)?;

            Ok(result)
        }
    })?)
}
