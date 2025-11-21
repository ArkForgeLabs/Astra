use crate::ASTRA_STD_LIBS;

pub async fn find_first_lua_match_with_content(
    lua: &mlua::Lua,
    module_name: &str,
) -> Option<(std::path::PathBuf, String)> {
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
        for candidate in &candidates {
            let file_path = if let Ok(file_path) = candidate.strip_prefix(format!(
                ".{}astra{}",
                std::path::MAIN_SEPARATOR_STR,
                std::path::MAIN_SEPARATOR_STR
            )) {
                file_path
            } else if let Ok(file_path) =
                candidate.strip_prefix(format!(".{}", std::path::MAIN_SEPARATOR_STR))
            {
                file_path
            } else {
                candidate
            };

            // println!(
            //     "FILE TO IMPORT: {:?}",
            //     std::path::PathBuf::from("lua")
            //         .join(file_path)
            //         .to_string_lossy()
            //         .replace("\\", "/")
            // );

            if let Some(file) = ASTRA_STD_LIBS.get_file(
                std::path::PathBuf::from("lua")
                    .join(file_path)
                    .to_string_lossy()
                    .replace("\\", "/"),
            ) && let Some(content) = file.contents_utf8()
            {
                return Some((candidate.to_path_buf(), content.to_string()));
            }

            if let Some(file) = ASTRA_STD_LIBS.get_file(
                std::path::PathBuf::from("teal")
                    .join(file_path)
                    .to_string_lossy()
                    .replace("\\", "/"),
            ) && let Some(content) = file.contents_utf8()
            {
                if !lua.globals().contains_key("TEAL_COMPILER").unwrap_or(false) {
                    #[allow(clippy::expect_used)]
                    super::load_teal(lua)
                        .await
                        .expect("Could not load the Teal compiler...");
                }

                return Some((candidate.to_path_buf(), content.to_string()));
            }
        }
    }

    None
}

pub async fn register_import_function(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "require",
        lua.create_async_function(|lua, path: String| async move {
            let key_id = format!("ASTRA_INTERNAL__IMPORT_CACHE_{path}");

            if let Ok(cache) = lua
                .globals()
                .get::<Option<mlua::RegistryKey>>(key_id.as_str())
                && let Some(key) = cache
            {
                lua.registry_value::<mlua::Value>(&key)
            } else {
                let current_script_path: String =
                    lua.globals().get("ASTRA_INTERNAL__CURRENT_SCRIPT")?;
                // let is_current_script_teal = std::path::PathBuf::from(&current_script_path).ends_with("tl");

                #[allow(clippy::collapsible_else_if)]
                if let Some((file_path, content)) =
                    find_first_lua_match_with_content(&lua, &path).await
                    && let Some(is_teal) = file_path
                        .extension()
                        .map(|extension| extension.to_string_lossy().contains("tl"))
                {
                    let file_path = file_path
                        .to_string_lossy()
                        .replace("./", "")
                        .replace(".\\", "");

                    lua.globals()
                        .set("ASTRA_INTERNAL__CURRENT_SCRIPT", file_path.clone())?;
                    let result = if is_teal {
                        super::execute_teal_code(&lua, &file_path, &content).await?
                    } else {
                        lua.load(content)
                            .set_name(file_path)
                            .eval_async::<mlua::Value>()
                            .await?
                    };

                    let key = lua.create_registry_value(&result)?;
                    lua.globals().set(key_id, Some(key))?;
                    lua.globals()
                        .set("ASTRA_INTERNAL__CURRENT_SCRIPT", current_script_path)?;

                    Ok(result)
                } else {
                    Err(mlua::Error::runtime(format!(
                        "Could not find the module {path}"
                    )))
                }
            }
        })?,
    )
}
