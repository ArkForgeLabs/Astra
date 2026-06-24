use crate::ASTRA_STD_LIBS;
use std::path::{MAIN_SEPARATOR_STR, PathBuf};

pub async fn find_first_lua_match_with_content(
    lua: &mlua::Lua,
    module_name: &str,
) -> Option<(PathBuf, String)> {
    let lua_path: String;
    if let Ok(path) = lua.load("return package.path").eval::<String>() {
        lua_path = path
    } else {
        lua_path = "?".to_string();
    }
    let module_path = module_name.replace(".", MAIN_SEPARATOR_STR);

    let runtime = if cfg!(feature = "luau") {
        "luau"
    } else {
        "lua"
    };

    // check the lua paths if the module exist there
    for pattern in lua_path.split(';').filter(|s| !s.is_empty()) {
        let pattern = pattern.replacen('?', &module_path, 1).replacen(
            &(".".to_owned() + MAIN_SEPARATOR_STR),
            "",
            1,
        );
        let pattern_path = PathBuf::from(&pattern);
        let pattern_path_without_extension =
            PathBuf::from(&pattern.replace(".luau", "").replace(".lua", ""));

        // Check all possible file patterns
        let path_builder = |base_path: &str| -> Vec<PathBuf> {
            vec![
                PathBuf::from(base_path).join(pattern_path.with_extension("lua")),
                PathBuf::from(base_path).join(pattern_path.with_extension("luau")),
                PathBuf::from(base_path).join(pattern_path_without_extension.join("init.lua")),
                PathBuf::from(base_path).join(pattern_path_without_extension.join("init.luau")),
                PathBuf::from(base_path).join(pattern_path_without_extension.join("d.lua")),
                PathBuf::from(base_path).join(pattern_path_without_extension.join("d.luau")),
                PathBuf::from(base_path).join(pattern_path.clone()), // For directories or files without extensions
            ]
        };
        let mut candidates = path_builder(".");
        candidates.extend(path_builder(runtime));

        // Check from the packed files
        if let Some(contents) = crate::commands::PACKED_FILES.get() {
            for candidate in candidates.iter() {
                if let Some(content) = contents
                    .imports
                    .get(&candidate.to_string_lossy().to_string())
                {
                    return Some((candidate.clone(), content.clone()));
                }
            }
        }

        // Check the file system
        for candidate in candidates.iter() {
            if let Ok(content) = tokio::fs::read_to_string(&candidate).await {
                return Some((candidate.clone(), content));
            }
        }

        // Check in packaged libs if it exists
        for candidate in &candidates {
            let file_path = if let Ok(file_path) = candidate.strip_prefix(format!(
                ".{}astra{}{runtime}{}",
                MAIN_SEPARATOR_STR, MAIN_SEPARATOR_STR, MAIN_SEPARATOR_STR
            )) {
                file_path
            } else if let Ok(file_path) = candidate.strip_prefix(format!(".{}", MAIN_SEPARATOR_STR))
            {
                file_path
            } else {
                candidate
            };

            // println!("FILE TO IMPORT: {:?}", file_path);

            if let Some(file) = ASTRA_STD_LIBS.get_file(file_path)
                && let Some(content) = file.contents_utf8()
            {
                return Some((candidate.to_path_buf(), content.to_string()));
            }
        }
    }

    None
}

async fn import(lua: &mlua::Lua, key_id: &str, path: &str) -> mlua::Result<mlua::Value> {
    let current_script_path: String = lua.globals().get::<String>("CURRENT_SCRIPT")?;

    if let Some((file_path, content)) = find_first_lua_match_with_content(lua, path).await {
        let file_path = file_path
            .to_string_lossy()
            .replace("./", "")
            .replace(".\\", "");

        lua.globals().set("CURRENT_SCRIPT", file_path.clone())?;
        let result = lua
            .load(content)
            .set_name(format!("@{file_path}"))
            .eval_async::<mlua::Value>()
            .await?;

        let key = lua.create_registry_value(&result)?;
        lua.globals().set(key_id, Some(key))?;
        lua.globals().set("CURRENT_SCRIPT", current_script_path)?;

        Ok(result)
    } else {
        Err(mlua::Error::runtime(format!(
            "Could not find the module {path}"
        )))
    }
}

pub fn register_import_function(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "require",
        lua.create_async_function(|lua, path: String| async move {
            let path = path.replace("@astra/", "");
            let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");

            if let Ok(cache) = lua
                .globals()
                .get::<Option<mlua::RegistryKey>>(key_id.as_str())
                && let Some(key) = cache
            {
                lua.registry_value::<mlua::Value>(&key)
            } else {
                import(&lua, &key_id, &path).await
            }
        })?,
    )
}
