use crate::ASTRA_STD_LIBS;

/// Exports the Lua bundle.
pub async fn export_bundle_command(folder_path: Option<String>) -> std::io::Result<()> {
    let folder_path = folder_path.unwrap_or(".".to_string());
    let folder_path = std::path::Path::new(&folder_path).join("astra");
    let _ = std::fs::remove_dir_all(&folder_path);
    let _ = std::fs::create_dir_all(&folder_path);

    ASTRA_STD_LIBS.extract(&folder_path)?;

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

    #[cfg(not(feature = "luau"))]
    std::fs::exists(".luarc.json")
        .map(|exists| !exists)
        .map(|_| {
            std::fs::write(
                ".luarc.json",
                include_str!("../../.luarc.json").replace("LuaJIT", runtime),
            )
        })??;

    #[cfg(feature = "luau")]
    std::fs::exists(".luaurc")
        .map(|exists| !exists)
        .map(|_| std::fs::write(".luaurc", include_str!("../../.luaurc")))??;

    std::fs::exists(".stylua.toml")
        .map(|exists| !exists)
        .map(|_| {
            std::fs::write(
                ".stylua.toml",
                include_str!("../../.stylua.toml").replace("LuaJIT", runtime),
            )
        })??;

    println!("🚀 Successfully exported the bundled type definitions!");
    Ok(())
}
