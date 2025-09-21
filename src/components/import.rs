use crate::{RuntimeFlags, ASTRA_STD_LIBS, RUNTIME_FLAGS, TEAL_IMPORT_SCRIPT};

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";

pub async fn find_first_lua_match_with_content(
    lua: &mlua::Lua,
    module_name: &str,
) -> Option<(std::path::PathBuf, String)> {
    let runtime_flags = RUNTIME_FLAGS.get_or_init(|| async { RuntimeFlags {
        stdlib_path: std::path::PathBuf::from("astra"),
        teal_compile_checks: true
    } }).await;
    let lua_path: String;
    if let Ok(path) = lua.load("return package.path").eval::<String>() {
        lua_path = path
    } else {
        return None;
    }
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
            pattern_path.join("d.lua"),
            pattern_path.join("d.tl"),
            pattern_path.clone(), // For directories or files without extensions
        ];

        // Check the file system
        for candidate in candidates.iter() {
            if let Ok(content) = tokio::fs::read_to_string(&candidate).await {
                return Some((candidate.clone(), content));
            }
        }

        // Check in packaged libs if it exists
        for candidate in candidates {
            if let Some(file_name) =  runtime_flags.stdlib_path.file_name()
                && let file_name = candidate.to_string_lossy().to_string().replace(
                        format!(".{}{}{}",
                        std::path::MAIN_SEPARATOR_STR,
                        file_name.to_string_lossy(), 
                        std::path::MAIN_SEPARATOR_STR).as_str(), ""
                    )
                // && let _ = println!("{file_name:?}")
                && let Some(file) = ASTRA_STD_LIBS.get_file(file_name)
                && let Some(content) = file.contents_utf8() {
                return Some((candidate, content.to_string()));
            }
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
        let runtime_flags = RUNTIME_FLAGS.get_or_init(|| async { RuntimeFlags {
            stdlib_path: std::path::PathBuf::from("astra"),
            teal_compile_checks: true
        } }).await;

        let current_script_path: String = lua.globals().get("ASTRA_INTERNAL__CURRENT_SCRIPT")?;
        // let is_current_script_teal = std::path::PathBuf::from(&current_script_path).ends_with("tl");

        #[allow(clippy::collapsible_else_if)]
        if let Some((file_path, content)) = find_first_lua_match_with_content(&lua, &path).await
        && let Some(is_teal) = file_path.extension().map(|extension| extension.to_string_lossy().contains("tl")) {
            let file_path = file_path.to_string_lossy().to_string().replace("./", "").replace(".\\", "");

            if runtime_flags.teal_compile_checks {
                lua.load(TEAL_IMPORT_SCRIPT
                    .replace("@SOURCE", &format!("global ASTRA_INTERNAL__CURRENT_SCRIPT=\"{file_path}\";{content}"))
                    .replace(
                        "local teal_compile_checks = true",
                        &format!("local teal_compile_checks = {}", runtime_flags.teal_compile_checks),
                    )
                    .replace("@FILE_NAME", &file_path)).exec_async().await?
            }
            let result = lua
            .load(if is_teal {
                format!(
                "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[global ASTRA_INTERNAL__CURRENT_SCRIPT=\"{file_path}\";{content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{file_path}\")()")
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
