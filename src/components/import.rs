// TODO: Change into require syntax instead of global Astra table.
// TODO: Have the modules loaded from packed ones if none are available on the path

use std::io::Read;

fn find_first_lua_match_with_content(
    lua_path: &str,
    module_name: &str,
) -> Option<(std::path::PathBuf, String)> {
    for pattern in lua_path.split(';').filter(|s| !s.is_empty()) {
        let module_name = module_name.replace(".", std::path::MAIN_SEPARATOR_STR);
        let pattern = pattern.replacen('?', &module_name, 1);
        let pattern_path = std::path::PathBuf::from(&pattern);

        // Check all possible file patterns
        let candidates = vec![
            pattern_path.with_extension("lua"),
            pattern_path.with_extension("tl"),
            pattern_path.join("init.lua"),
            pattern_path.join("init.tl"),
            pattern_path.clone(), // For directories or files without extensions
        ];

        for candidate in candidates {
            if let Ok(mut file) = std::fs::File::open(&candidate) {
                let mut content = String::new();
                if file.read_to_string(&mut content).is_ok() {
                    return Some((candidate, content));
                }
            }
        }
    }
    None
}

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";

pub fn register_import_function(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set("require", lua.create_async_function(|lua, path: String| async move {
        let lua_path: String = lua.load("return package.path").eval()?;

        let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");
        let key_id = key_id.as_str();

        let mut cache = lua
            .globals()
            .get::<std::collections::HashMap<String, mlua::RegistryKey>>(key_id)
            .unwrap_or_default();

        if let Some(key) = cache.get(&path) {
            lua.registry_value::<mlua::Value>(key)
        } else {
            #[allow(clippy::collapsible_else_if)]
            if let Some((file_path, content)) = find_first_lua_match_with_content(&lua_path, &path)
            && let Some(is_teal) = file_path.extension().map(|extension| extension.to_string_lossy().contains("tl")) {
                let file_path = file_path.to_string_lossy().to_string();
                let result = lua
                .load(if is_teal {
                    format!(
                    "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[{content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{file_path}\")()"
                )
                } else {
                    content
                })
                .set_name(file_path)
                .eval_async::<mlua::Value>()
                .await?;

                let key = lua.create_registry_value(&result)?;
                cache.insert(path, key);
                lua.globals().set(key_id, cache)?;

                Ok(result)
            } else {
                Err(mlua::Error::runtime(format!("Could not find the module {path}")))
            }
        }
    })?)
}
