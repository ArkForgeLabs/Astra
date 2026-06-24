mod run;
pub use run::*;
mod upgrade;
pub use upgrade::*;
mod export;
pub use export::*;
mod build;
pub use build::*;

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
    lua.globals().set("CURRENT_SCRIPT", script_path)?;
    lua.globals().set("MAIN_SCRIPT", script_path)?;

    lua.globals().set("_RUNTIME", runtime_details(lua)?)?;

    let _ = dotenvy::from_filename_override(".env");
    let _ = dotenvy::from_filename_override(".env.production");
    let _ = dotenvy::from_filename_override(".env.prod");
    let _ = dotenvy::from_filename_override(".env.development");
    let _ = dotenvy::from_filename_override(".env.dev");
    let _ = dotenvy::from_filename_override(".env.test");
    let _ = dotenvy::from_filename_override(".env.local");

    Ok(())
}

fn runtime_details(lua: &mlua::Lua) -> mlua::Result<mlua::Table> {
    let runtime_table = lua.create_table()?;

    // details about the current build
    {
        let version_table = lua.create_table()?;
        version_table.set("display", clap::crate_version!())?;

        // set the semantic versioning
        {
            let version_semantic_table = lua.create_table()?;
            let version = clap::crate_version!().split(".").collect::<Vec<_>>();
            version_semantic_table.set(
                "major",
                version
                    .first()
                    .and_then(|value| value.parse::<u16>().ok())
                    .unwrap_or(0),
            )?;
            version_semantic_table.set(
                "minor",
                version
                    .get(1)
                    .and_then(|value| value.parse::<u16>().ok())
                    .unwrap_or(0),
            )?;
            version_semantic_table.set(
                "patch",
                version
                    .get(2)
                    .and_then(|value| value.parse::<u16>().ok())
                    .unwrap_or(0),
            )?;
            version_table.set("semantic", version_semantic_table)?;
        }

        // set the git details
        {
            let git_table = lua.create_table()?;

            git_table.set("url", "https://git.arkforge.net/ArkForgeLabs/Astra")?;
            git_table.set("commit", env!("GIT_HASH"))?;
            git_table.set("branch", "main")?;

            version_table.set("git", git_table)?;
        }

        runtime_table.set("version", version_table)?;
    }

    runtime_table.set("name", "astra")?;
    runtime_table.set("url", "https://astra.arkforge.net")?;

    Ok(runtime_table)
}
