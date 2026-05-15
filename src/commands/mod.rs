mod run;
pub use run::*;
mod upgrade;
pub use upgrade::*;
mod export;
pub use export::*;

static LUA_ASTRA_STDLIB_TABLE: tokio::sync::OnceCell<mlua::Table> =
    tokio::sync::OnceCell::const_new();
async fn stdlib_to_lua_table(lua: &mlua::Lua) -> mlua::Result<mlua::Table> {
    LUA_ASTRA_STDLIB_TABLE
        .get_or_try_init(|| async {
            let lua_astra_stdlib = lua.create_table()?;

            for dir in crate::ASTRA_STD_LIBS.dirs() {
                for file in dir.files() {
                    let file_path = file
                        .path()
                        .to_string_lossy()
                        .replace("\\", std::path::MAIN_SEPARATOR_STR)
                        .replace("/", std::path::MAIN_SEPARATOR_STR);
                    let content = file.contents_utf8().unwrap_or("");
                    // println!(
                    //     ">> {:?}",
                    //     std::path::Path::new("astra").join(file_path.clone())
                    // );
                    lua_astra_stdlib.set(std::path::Path::new("astra").join(file_path), content)?;
                    #[allow(clippy::expect_used)]
                    lua_astra_stdlib.set(
                        file.path()
                            .file_name()
                            .expect("Could not set the filename for stdlib"),
                        content,
                    )?;
                }
            }

            Ok(lua_astra_stdlib)
        })
        .await
        .cloned()
}

async fn registration(lua: &mlua::Lua, script_path: &str) -> mlua::Result<()> {
    crate::components::register_components(lua).await?;

    lua.globals().set(
        "ASTRA_INTERNAL__STDLIB_TABLE",
        stdlib_to_lua_table(lua).await?,
    )?;
    lua.globals().set("ASTRA_VERSION", clap::crate_version!())?;
    lua.globals().set("CURRENT_SCRIPT", script_path)?;
    lua.globals().set("MAIN_SCRIPT", script_path)?;

    let _ = dotenvy::from_filename_override(".env");
    let _ = dotenvy::from_filename_override(".env.production");
    let _ = dotenvy::from_filename_override(".env.prod");
    let _ = dotenvy::from_filename_override(".env.development");
    let _ = dotenvy::from_filename_override(".env.dev");
    let _ = dotenvy::from_filename_override(".env.test");
    let _ = dotenvy::from_filename_override(".env.local");

    Ok(())
}
