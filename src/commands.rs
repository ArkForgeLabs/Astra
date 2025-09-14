use crate::{ASTRA_STD_LIBS, LUA, RUNTIME_FLAGS, TEAL_IMPORT_SCRIPT};
use clap::crate_version;

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";

async fn run_command_prerequisite(
    file_path: &str,
    stdlib_path: Option<String>,
    teal_compile_checks: Option<bool>,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;

    let stdlib_path = stdlib_path.unwrap_or("astra".to_string());
    let teal_compile_checks = teal_compile_checks.unwrap_or(true);

    #[allow(clippy::expect_used)]
    RUNTIME_FLAGS
        .set(crate::RuntimeFlags {
            stdlib_path: std::path::PathBuf::from(stdlib_path.clone()),
            teal_compile_checks,
        })
        .expect("Could not set the global STDLIB_PATH");

    // Register Lua components.
    registration(lua, stdlib_path, teal_compile_checks).await;

    // Handle extra arguments.
    if let Some(extra_args) = extra_args
        && let Ok(args) = lua.create_table()
    {
        if let Err(e) = args.set(0, file_path) {
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

/// Runs a Lua script.
pub async fn run_command(
    file_path: String,
    stdlib_path: Option<String>,
    teal_compile_checks: Option<bool>,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;

    run_command_prerequisite(&file_path, stdlib_path, teal_compile_checks, extra_args).await;
    let teal_compile_checks = teal_compile_checks.unwrap_or(true);

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let mut user_file = std::fs::read_to_string(&file_path).expect("Couldn't read file");

    if let Some(is_teal) = std::path::PathBuf::from(&file_path).extension()
        && is_teal == "tl"
    {
        if teal_compile_checks
            && let Err(e) = lua
                .load(
                    TEAL_IMPORT_SCRIPT
                        .replace("@SOURCE", &user_file)
                        .replace("@FILE_NAME", &file_path),
                )
                .set_name(format!("@{file_path}"))
                .exec_async()
                .await
        {
            tracing::error!("{e}");
        }

        user_file = format!(
            "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[global ASTRA_INTERNAL__CURRENT_SCRIPT=\"{file_path}\";{user_file}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{file_path}\")()"
        )
    }
    #[allow(clippy::expect_used)]
    lua.globals()
        .set("ASTRA_INTERNAL__CURRENT_SCRIPT", file_path.clone())
        .expect("Couldn't set the script path");

    if let Err(e) = lua
        .load(user_file)
        .set_name(format!("@{file_path}"))
        .exec_async()
        .await
    {
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
pub async fn export_bundle_command(folder_path: Option<String>) -> std::io::Result<()> {
    #[allow(clippy::expect_used)]
    crate::components::register_components(&LUA)
        .await
        .expect("Error setting up the standard library");

    let folder_path = folder_path.unwrap_or(".".to_string());
    let folder_path = std::path::Path::new(&folder_path);
    let _ = std::fs::remove_dir_all(folder_path.join("astra"));
    ASTRA_STD_LIBS.extract(folder_path)?;

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
        .replace("astra", folder_path.to_string_lossy().as_ref())
        .replace("LuaJIT", runtime);
    let tlconfig_file =
        include_str!("../tlconfig.lua").replace("astra", folder_path.to_string_lossy().as_ref());

    std::fs::exists(".luarc.json")
        .map(|exists| !exists)
        .map(|_| std::fs::write(".luarc.json", luarc_file))??;
    std::fs::exists("tlconfig.lua")
        .map(|exists| !exists)
        .map(|_| std::fs::write("tlconfig.lua", tlconfig_file))??;

    println!("🚀 Successfully exported the bundled library!");
    Ok(())
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
        println!("Already up to date!")
    }

    Ok(())
}

async fn registration(lua: &mlua::Lua, stdlib_path: String, teal_compile_checks: bool) {
    #[allow(clippy::expect_used)]
    crate::components::register_components(lua)
        .await
        .expect("Error setting up the standard library");

    let stdlib_path = std::path::PathBuf::from(stdlib_path);

    async fn read_from_stdlib(
        stdlib_path: &std::path::Path,
        path: std::path::PathBuf,
    ) -> Option<String> {
        if let Ok(content) = tokio::fs::read_to_string(stdlib_path.join(path.clone())).await {
            return Some(content);
        }

        if let Some(file) = ASTRA_STD_LIBS.get_file(path)
            && let Some(content) = file.contents_utf8()
        {
            return Some(content.to_string());
        }

        None
    }

    // astra.d.lua
    if let Some(content) = read_from_stdlib(
        &stdlib_path,
        std::path::PathBuf::from("lua").join("astra.d.lua"),
    )
    .await
        && let Err(e) = lua.load(content).set_name("astra.d.lua").exec_async().await
    {
        tracing::error!("Could not load the astra's lua globals: {e}");
    }

    // teal.lua (does not work on luau)
    if !cfg!(feature = "luau")
        && let Some(teal_source) = read_from_stdlib(
            &stdlib_path,
            std::path::PathBuf::from("teal").join("astra.d.tl"),
        )
        .await
    {
        if let Some(content) =
            read_from_stdlib(&stdlib_path, std::path::PathBuf::from("teal.lua")).await
            && let Err(e) = lua
                .load(content.replace("@ASTRA_TEAL_SOURCE", teal_source.as_str()))
                .set_name("teal.lua")
                .exec_async()
                .await
        {
            tracing::error!("Could not load the teal: {e}");
        }

        // astra.d.tl
        if teal_compile_checks
            && let Err(e) = lua
                .load(
                    TEAL_IMPORT_SCRIPT
                        .replace("@SOURCE", &teal_source)
                        .replace("@FILE_NAME", "astra.d.tl"),
                )
                .set_name("astra.d.tl")
                .exec_async()
                .await
        {
            tracing::error!("Could not load the astra's teal globals: {e}");
        }
        if let Err(e) = lua
                .load(
                format!("Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[{teal_source}]{ONE_HUNDRED_EQUAL_SIGNS}], \"astra.d.tl\")()")
                )
                .set_name("astra.d.tl")
                .exec_async()
                .await
        {
            tracing::error!("Could not load the astra's teal globals: {e}");
        }
    }
}
