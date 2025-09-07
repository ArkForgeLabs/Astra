use crate::{ASTRA_STD_LIBS};
use std::io::Read;

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";

async fn find_first_lua_match_with_content(
    lua_path: &str,
    module_name: &str,
    is_current_script_teal: bool,
) -> Option<(std::path::PathBuf, String)> {
    let module_path = module_name.replace(".", std::path::MAIN_SEPARATOR_STR);
    
    // check the lua paths if the module exist there
    for pattern in lua_path.split(';').filter(|s| !s.is_empty()) {
        let pattern = pattern.replacen('?', &module_path, 1);
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

    // and finally get it from the packaged library
    if let Some(module_name) = module_name.split(".").last() {
        if is_current_script_teal && let Some((path, content)) = ASTRA_STD_LIBS
                .teal_libs
                .iter()
                .find(|lib| lib.0.contains(module_name))
        {
            return Some((std::path::PathBuf::from(&path), content.clone()));
        } else if let Some((path, content)) = ASTRA_STD_LIBS
            .lua_libs
            .iter()
            .find(|lib| lib.0.contains(module_name))
        {
            return Some((std::path::PathBuf::from(&path), content.clone()));
        }
    }

    None
}

pub async fn register_import_function(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set("require", lua.create_async_function(|lua, path: String| async move {
        let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");
        
        let mut cache = lua
            .globals()
            .get::<std::collections::HashMap<String, mlua::RegistryKey>>(key_id.as_str())
            .unwrap_or_default();

    if let Some(key) = cache.get(&path) {
        lua.registry_value::<mlua::Value>(key)
    } else {
            let lua_path: String = lua.load("return package.path").eval()?;
            let current_script_path: String = lua.globals().get("ASTRA_INTERNAL__CURRENT_SCRIPT")?;
            let is_current_script_teal = std::path::PathBuf::from(&current_script_path).ends_with("tl");

            #[allow(clippy::collapsible_else_if)]
            if let Some((file_path, content)) = find_first_lua_match_with_content(&lua_path, &path, is_current_script_teal).await
            && let Some(is_teal) = file_path.extension().map(|extension| extension.to_string_lossy().contains("tl")) {
                let file_path = file_path.to_string_lossy().to_string().replace("./", "").replace(".\\", "");

                let result = lua
                .load(if is_teal {
                    format!(
                    "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[global ASTRA_INTERNAL__CURRENT_SCRIPT=\"{file_path}\";{content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{file_path}\")()"
                )
                } else {
                    format!("ASTRA_INTERNAL__CURRENT_SCRIPT=\"{file_path}\";{content}")
                })
                .set_name(format!("@{file_path}"))
                .eval_async::<mlua::Value>()
                .await?;

                let key = lua.create_registry_value(&result)?;
                cache.insert(path, key);
                lua.globals().set(key_id, cache)?;
                lua.globals().set("ASTRA_INTERNAL__CURRENT_SCRIPT", current_script_path)?;

                Ok(result)
            } else {
                Err(mlua::Error::runtime(format!("Could not find the module {path}")))
            }
        }
    })?)
}
