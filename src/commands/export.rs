use crate::{ASTRA_STD_LIBS, LUA};

/// Exports the Lua bundle.
pub async fn export_bundle_command(
    teal_export: bool,
    folder_path: Option<String>,
) -> std::io::Result<()> {
    #[allow(clippy::expect_used)]
    crate::components::register_components(&LUA)
        .await
        .expect("Error setting up the standard library");

    let folder_path = folder_path.unwrap_or(".".to_string());
    let folder_path = std::path::Path::new(&folder_path).join("astra");
    let _ = std::fs::remove_dir_all(&folder_path);
    let _ = std::fs::create_dir_all(&folder_path);

    ASTRA_STD_LIBS.extract(&folder_path)?;

    if !teal_export {
        let _ = std::fs::remove_dir_all(folder_path.join("teal"));
        let _ = std::fs::remove_file(folder_path.join("teal.lua"));
    }

    let runtime = if cfg!(feature = "lua54") {
        "Lua 5.4"
    } else if cfg!(feature = "luajit52") {
        "LuaJIT 5.2"
    } else if cfg!(feature = "luau") {
        "Luau"
    } else if cfg!(feature = "lua51") {
        "Lua 5.1"
    } else if cfg!(feature = "lua52") {
        "Lua 5.2"
    } else if cfg!(feature = "lua53") {
        "Lua 5.3"
    } else {
        "LuaJIT"
    };

    let tlconfig_file = include_str!("../../tlconfig.lua").replace("LuaJIT", runtime);
    let luarc_file = include_str!("../../.luarc.json").replace("LuaJIT", runtime);

    if teal_export {
        std::fs::exists("tlconfig.lua")
            .map(|exists| !exists)
            .map(|_| std::fs::write("tlconfig.lua", tlconfig_file))??;

        println!("🚀 Successfully exported the bundled library!");
    } else {
        std::fs::exists(".luarc.json")
            .map(|exists| !exists)
            .map(|_| std::fs::write(".luarc.json", luarc_file))??;

        println!(
            "🚀 Successfully exported the bundled library!\
\n\nTeal type definition and configuration have not been exported.\n
If you wish to export them as well, use the -t flag with astra export:\n\n\
astra export -t"
        );
    }
    Ok(())
}
