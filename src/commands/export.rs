use crate::{ASTRA_STD_LIBS, LUA};

/// Exports the Lua bundle.
pub async fn export_bundle_command(folder_path: Option<String>) -> std::io::Result<()> {
    #[allow(clippy::expect_used)]
    crate::components::register_components(&LUA)
        .await
        .expect("Error setting up the standard library");

    let folder_path = folder_path.unwrap_or(".".to_string());
    let folder_path = std::path::Path::new(&folder_path);
    let _ = std::fs::remove_dir_all(folder_path.join("astra"));
    let _ = std::fs::create_dir_all(folder_path.join("astra"));
    ASTRA_STD_LIBS.extract(folder_path.join("astra"))?;

    let tlconfig_file = include_str!("../../tlconfig.lua");

    std::fs::exists("tlconfig.lua")
        .map(|exists| !exists)
        .map(|_| std::fs::write("tlconfig.lua", tlconfig_file))??;

    println!("🚀 Successfully exported the bundled library!");
    Ok(())
}
