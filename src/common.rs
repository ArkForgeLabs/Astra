use std::sync::LazyLock;

pub static LUA: LazyLock<mlua::Lua> = LazyLock::new(mlua::Lua::new);

pub async fn init() {
    let lua = &LUA;
    let lib = include_str!("../lua/astra_bundle.lua");

    #[allow(clippy::expect_used)]
    lua.load(lib)
        .exec_async()
        .await
        .expect("Couldn't add prelude");

    #[cfg(feature = "sqlx")]
    #[allow(clippy::expect_used)]
    crate::database::Database::register_to_lua(lua)
        .await
        .expect("Could not register Database function");

    // settings
    if let Ok(settings) = lua.globals().get::<mlua::Table>("Astra") {
        // set the version
        if settings
            .set("version", crate::common::get_package_version())
            .is_ok()
        {
            if let Err(e) = lua.globals().set("Astra", settings) {
                println!("Error adding setting back to Astra: {e:#?}");
            }
        }
    }

    // commands
    let args = std::env::args().collect::<Vec<_>>();
    match args.get(1) {
        Some(command) if command == "run" => {
            // Filter out lines that start with "require" and contain "astra.lua" or "astra.bundle.lua"
            #[allow(clippy::expect_used)]
            let user_file =
                std::fs::read_to_string(args.get(2).expect("Couldn't open the lua file").clone())
                    .expect("Couldn't read file");

            let lines: Vec<&str> = user_file.lines().collect();

            // Filter out lines that start with "require" and contain "astra.lua" or "astra.bundle.lua"
            let filtered_lines: Vec<String> = lines
                .into_iter()
                .filter(|line| {
                    !(line.starts_with("require")
                        && (line.contains("astra") || line.contains("astra_bundle")))
                })
                .map(|line| line.to_string()) // Convert to String
                .collect();

            // Join the filtered lines back into a single string
            let updated_content = filtered_lines.join("\n");

            #[allow(clippy::expect_used)]
            lua.load(updated_content)
                .exec_async()
                .await
                .expect("Couldn't load lua file");
        }

        Some(command) if command == "export-bundle" => {
            #[allow(clippy::expect_used)]
            std::fs::write("./astra_bundle.lua", lib)
                .expect("Could not export the bundled library");

            println!("🚀 Successfully exported the bundled library!");
            std::process::exit(0);
        }

        _ => {
            println!("☹️  Available Commands: run | export-bundle");
            std::process::exit(0);
        }
    }
}

pub fn get_package_version() -> String {
    let project = include_str!("../Cargo.toml");
    if let Ok(toml_parse) = toml::from_str::<toml::Value>(project) {
        let get_version = move || -> Option<String> {
            let version = toml_parse
                .get("package")?
                .as_table()?
                .get("version")?
                .as_str()?;

            Some(version.to_string())
        };

        match get_version() {
            Some(version) => version,
            None => "v0.0.0".to_string(),
        }
    } else {
        "v0.0.0".to_string()
    }
}
