use crate::{LUA, SCRIPT_PATH};
use clap::crate_version;
use std::str::FromStr;

/// Runs a Lua script.
pub async fn run_command(file_path: String, extra_args: Option<Vec<String>>) {
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
    let _ = registration(lua).await;

    // Handle extra arguments.
    if let Some(extra_args) = extra_args {
        if let Ok(args) = lua.create_table() {
            if let Err(e) = args.set(0, file_path.clone()) {
                eprintln!("Error adding arg to the args list: {e:?}");
            }

            for (index, value) in extra_args.into_iter().enumerate() {
                if let Err(e) = args.set((index + 1) as i32, value) {
                    eprintln!("Error adding arg to the args list: {e:?}");
                }
            }

            if let Err(e) = lua.globals().set("arg", args) {
                eprintln!("Error setting the global variable ARGS: {e:?}");
            }
        }
    }

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let user_file = std::fs::read_to_string(&file_path).expect("Couldn't read file");
    if let Err(e) = lua.load(user_file).set_name(file_path).exec_async().await {
        eprintln!("{e}");
    }

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
pub async fn export_bundle_command(file_path: Option<String>) {
    let (lib, _) = prepare_prelude();
    let file_path = file_path.unwrap_or_else(|| "astra_bundle.lua".to_string());

    // Write the bundled library to the file.
    #[allow(clippy::expect_used)]
    std::fs::write(file_path, lib).expect("Could not export the bundled library");
    println!("🚀 Successfully exported the bundled library!");
    std::process::exit(0);
}

/// Upgrades to the latest version.
pub async fn upgrade_command() -> Result<(), Box<dyn std::error::Error>> {
    let latest_tag = reqwest::Client::new()
        .get("https://api.github.com/repos/ArkForgeLabs/Astra/tags")
        .header(
            reqwest::header::USER_AGENT,
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
        )
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

        println!("Done! Enjoy!");
    } else {
        println!("Already up to date!");
    }

    Ok(())
}

/// Registers Lua components.
async fn registration(lua: &mlua::Lua) -> String {
    let (lib, cleaned_lib) = prepare_prelude();

    if let Err(e) = crate::components::register_components(lua).await {
        eprintln!("Error setting up the components:\n{e}");
    }

    // Set Astra version in Lua globals.
    if let Err(e) = lua
        .globals()
        .set("astra_internal__version", crate_version!())
    {
        eprintln!("Error adding version to Astra: {e:#?}");
    }

    if let Err(e) = lua
        .load(cleaned_lib.as_str())
        .set_name("astra_bundle.lua")
        .exec_async()
        .await
    {
        eprintln!("Couldn't add prelude:\n{e}");
    }

    lib
}

fn prepare_prelude() -> (String, String) {
    let lua_libs = include_dir::include_dir!("./src/lua/libs");
    println!("{lua_libs:#?}");

    /// Filters lines between start and end markers.
    fn filter(input: String, start: &str, end: &str) -> String {
        let mut new_lines = Vec::new();
        let mut removing = false;
        for line in input.lines() {
            if line.contains(start) {
                removing = true;
                continue;
            } else if line.contains(end) {
                removing = false;
                continue;
            }

            if !removing {
                new_lines.push(line);
            }
        }
        new_lines.join("\n")
    }

    let lib = "".to_string();

    let lib = filter(lib, "--- @START_REMOVING_PACK", "--- @END_REMOVING_PACK");
    let cleaned_lib = filter(
        lib.clone(),
        "--- @START_REMOVING_RUNTIME",
        "--- @END_REMOVING_RUNTIME",
    );

    (lib, cleaned_lib)
}
