use crate::{LUA, SCRIPT_PATH};
use clap::crate_version;
use std::str::FromStr;

/// Runs a Lua script.
pub async fn run_command(
    file_path: String,
    stdlib_path: Option<String>,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;

    // ! Move VM preparation into a separate function
    // ! To enable VM creation on route request

    // Set the script path.
    #[allow(clippy::expect_used)]
    let path =
        std::path::PathBuf::from_str(&file_path).expect("Could not turn path into a path buffer");
    #[allow(clippy::expect_used)]
    SCRIPT_PATH
        .set(path)
        .expect("Could not set the script path to OnceCell");

    // Register Lua components.
    registration(lua, stdlib_path).await;

    // Handle extra arguments.
    if let Some(extra_args) = extra_args {
        if let Ok(args) = lua.create_table() {
            if let Err(e) = args.set(0, file_path.clone()) {
                tracing::error!("Error adding arg to the args list: {e:?}");
            }

            for (index, value) in extra_args.into_iter().enumerate() {
                if let Err(e) = args.set((index + 1) as i32, value) {
                    tracing::error!("Error adding arg to the args list: {e:?}");
                }
            }

            if let Err(e) = lua.globals().set("arg", args) {
                tracing::error!("Error setting the global variable ARGS: {e:?}");
            }
        }
    }

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let user_file = std::fs::read_to_string(&file_path).expect("Couldn't read file");
    if let Err(e) = lua.load(user_file).set_name(file_path).exec_async().await {
        tracing::error!("{e}");
    }

    // TODO: JOIN ALL TASKS HERE, AND EXIT IN CASE OF ERROR

    // Wait for all Tokio tasks to finish.
    let metrics = tokio::runtime::Handle::current().metrics();
    loop {
        let alive_tasks = metrics.num_alive_tasks();
        if alive_tasks == 0 {
            break;
        }
    }
}

/// Exports the Lua bundle.
pub async fn export_bundle_command(folder_path: Option<String>) {
    let mut lua_lib = pure_lua_libs();
    #[allow(clippy::expect_used)]
    let std_lib = crate::components::register_components(&LUA)
        .await
        .expect("Error setting up the standard library");
    lua_lib.extend(std_lib);

    let folder_path = std::path::Path::new(&folder_path.unwrap_or(".".to_string())).join(".astra");

    let _ = std::fs::remove_dir_all(&folder_path);
    let _ = std::fs::create_dir_all(&folder_path);
    for (file_path, content) in lua_lib {
        // Write the bundled library to the file.
        std::fs::write(folder_path.join(&file_path), content)
            .unwrap_or_else(|e| panic!("Could not export the {file_path}: {e}"));
    }

    let runtime = if cfg!(feature = "lua54") {
        "Lua 5.4"
    } else if cfg!(feature = "luajit52") {
        "LuaJIT"
    } else if cfg!(feature = "lua51") {
        "Lua 5.1"
    } else if cfg!(feature = "lua52") {
        "Lua 5.2"
    } else if cfg!(feature = "lua53") {
        "Lua 5.3"
    } else {
        "LuaJIT"
    };
    let luarc_file = include_str!("../.luarc.json")
        .replace("src", ".astra")
        .replace("LuaJIT", runtime);
    if let Ok(does_luarc_exist) = std::fs::exists(".luarc.json") {
        if !does_luarc_exist {
            std::fs::write(".luarc.json", luarc_file)
                .unwrap_or_else(|e| panic!("Could not export the .luarc.json: {e}"));
        }
    }

    println!("🚀 Successfully exported the bundled library!");
    std::process::exit(0);
}

/// Upgrades to the latest version.
pub async fn upgrade_command(user_agent: Option<String>) -> Result<(), Box<dyn std::error::Error>> {
    let user_agent = user_agent.unwrap_or(
        "Mozilla/5.0 (X11; \
            Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) \
            Chrome/51.0.2704.103 Safari/537.36"
            .to_string(),
    );
    let latest_tag = reqwest::Client::new()
        .get("https://api.github.com/repos/ArkForgeLabs/Astra/tags")
        .header(reqwest::header::USER_AGENT, user_agent)
        .send()
        .await?
        .json::<serde_json::Value>()
        .await?;

    // Get the latest tag.
    #[allow(clippy::expect_used)]
    let latest_tag = latest_tag
        .as_array()
        .expect("Could not obtain a list of releases")
        .first()
        .expect("Could not get the first available release")
        .as_object()
        .expect("Could not get the release details")
        .get("name")
        .expect("Could not get the tag")
        .as_str()
        .expect("Tag content is not in correct format");

    // Compare the latest tag with the current version.
    if version_compare::compare_to(latest_tag, crate_version!(), version_compare::Cmp::Gt)
        .is_ok_and(|compared| compared)
    {
        println!("Updating from {} to {latest_tag}...", crate_version!());

        let runtime = if cfg!(feature = "lua54") {
            "lua54"
        } else if cfg!(feature = "luajit52") {
            "luajit52"
        } else if cfg!(feature = "luau") {
            "luau"
        } else if cfg!(feature = "lua51") {
            "lua51"
        } else if cfg!(feature = "lua52") {
            "lua52"
        } else if cfg!(feature = "lua53") {
            "lua53"
        } else {
            "luajit"
        };

        let architecture = if cfg!(windows) {
            "windows-amd64.exe"
        } else {
            "linux-amd64"
        };

        let file_name = format!("astra-{runtime}-{architecture}");
        let url =
            format!("https://github.com/ArkForgeLabs/Astra/releases/latest/download/{file_name}");

        // Download the latest release.
        let content = reqwest::get(url).await?.bytes().await?;
        let current_file_name = std::env::current_exe()?.to_string_lossy().to_string();

        std::fs::write(format!("{file_name}-{latest_tag}"), content)?;
        std::fs::rename(
            current_file_name.clone(),
            format!("{current_file_name}_old"),
        )?;
        std::fs::rename(
            format!("{file_name}-{latest_tag}"),
            current_file_name.clone(),
        )?;
        std::fs::remove_file(format!("{current_file_name}_old"))?;

        #[cfg(target_os = "linux")]
        {
            let _ = std::process::Command::new("chmod")
                .arg("+x")
                .arg(current_file_name)
                .spawn();
        }

        println!(
            r#"🚀 Update complete!

Some of the next steps could be updating the exported type definitions:

astra export"#
        );
    } else {
        println!("Already up to date!");
    }

    Ok(())
}

/// Registers Lua components.
async fn registration(lua: &mlua::Lua, stdlib_path: Option<String>) {
    let mut lua_lib: Vec<(String, String)> = Vec::new();

    let folder_path = stdlib_path.unwrap_or(
        // get the folder path from .luarc.json
        // { "workspace.library": ["./folder_path"] }
        if let Ok(exists) = tokio::fs::try_exists(".astra").await
            && exists
        {
            ".astra".to_string()
        } else if let Ok(file) = tokio::fs::read_to_string(".luarc.json").await
            && let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&file)
            && let Some(parsed) = parsed.as_object()
            && let Some(parsed) = parsed.get("workspace.library")
            && let Some(parsed) = parsed.as_array()
            && let Some(folder_path) = parsed.first()
            && let Some(folder_path) = folder_path.as_str()
        {
            folder_path.to_string()
        } else {
            "".to_string()
        },
    );
    if let Ok(mut files) = tokio::fs::read_dir(folder_path).await {
        // add them to the lua_lib for being sent to interpretation
        while let Ok(Some(file)) = files.next_entry().await {
            if (file.path().ends_with("lua") || file.path().ends_with("luau")) // make sure only lua files are loaded
                && let Ok(content) = tokio::fs::read_to_string(file.path()).await
            {
                lua_lib.push((file.path().to_string_lossy().to_string(), content));
            }
        }
    }
    if lua_lib.is_empty() {
        // if the folder couldn't be opened or issues existed
        #[allow(clippy::expect_used)]
        let registration = crate::components::register_components(lua)
            .await
            .expect("Error setting up the standard library");

        lua_lib = registration;
    }
    let mut final_lib = pure_lua_libs();
    final_lib.extend(lua_lib);

    // Try to make astra.lua the first to get interpreted
    if let Some(index) = final_lib.iter().position(|entry| {
        let name = entry.0.to_ascii_lowercase();
        name == "astra.lua"
    }) {
        let value = final_lib.remove(index);
        final_lib.insert(0, value);
    }

    let rerun_limit = 100;
    let mut failed_to_load_modules: Vec<(String, String)> = Vec::new();

    // First attempt to load all modules
    for (file_name, content) in final_lib {
        match lua
            .load(content.as_str())
            .set_name(&file_name)
            .exec_async()
            .await
        {
            Err(e) => {
                if e.to_string().contains("attempt to index a nil value") {
                    failed_to_load_modules.insert(0, (file_name, content));
                } else {
                    tracing::error!("Couldn't add prelude:\n{e}");
                }
            }
            Ok(_result) => (),
        }
    }

    for _ in 0..rerun_limit {
        if failed_to_load_modules.is_empty() {
            break; // All modules have been loaded successfully
        }

        let mut new_failed_modules: Vec<(String, String)> = Vec::new();

        for (file_name, content) in failed_to_load_modules {
            match lua
                .load(content.as_str())
                .set_name(&file_name)
                .exec_async()
                .await
            {
                Err(e) => {
                    if e.to_string().contains("attempt to index a nil value") {
                        new_failed_modules.insert(0, (file_name, content));
                    } else {
                        tracing::error!("Couldn't add prelude:\n{e}");
                    }
                }
                Ok(_result) => (),
            }
        }

        failed_to_load_modules = new_failed_modules;
    }

    if !failed_to_load_modules.is_empty() {
        for (file_name, _) in failed_to_load_modules {
            tracing::error!(
                "Failed to load module '{}' after {} retries",
                file_name,
                rerun_limit
            );
        }
    }
}

fn pure_lua_libs() -> Vec<(String, String)> {
    let mut lua_lib = include_dir::include_dir!("./src/lua_libs")
        .files()
        .filter_map(|file| {
            if let Some(name) = file.path().file_name()
                && let Some(name) = name.to_str().map(|name| name.to_string())
                && let Some(content) = file.contents_utf8()
            {
                Some((name, content.replace("@ASTRA_VERSION", crate_version!())))
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    lua_lib.sort_by(|itema, itemb| itema.0.cmp(&itemb.0));

    lua_lib
}
