use crate::ASTRA_STD_LIBS;

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
                    lua_astra_stdlib.set(std::path::Path::new("astra").join(file_path), content)?;
                }
            }

            Ok(lua_astra_stdlib)
        })
        .await
        .cloned()
}

async fn registration(lua: &mlua::Lua, stdlib_path: String) -> mlua::Result<()> {
    crate::components::register_components(lua).await?;

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

    lua.globals().set(
        "ASTRA_INTERNAL__STDLIB_TABLE",
        stdlib_to_lua_table(lua).await?,
    )?;

    // astra.d.lua
    if let Some(content) = read_from_stdlib(
        &stdlib_path,
        std::path::PathBuf::from("lua").join("astra.d.lua"),
    )
    .await
    {
        lua.load(content)
            .set_name("astra.d.lua")
            .exec_async()
            .await?;
    }

    // teal.lua (does not work on luau)
    if !cfg!(feature = "luau") {
        if let Some(content) =
            read_from_stdlib(&stdlib_path, std::path::PathBuf::from("teal.lua")).await
        {
            lua.load(content).set_name("teal.lua").exec_async().await?;
        }

        // astra.d.tl
        if let Some(content) = read_from_stdlib(
            &stdlib_path,
            std::path::PathBuf::from("teal").join("astra.d.tl"),
        )
        .await
        {
            crate::components::execute_teal_code(lua, "astra.d.tl", &content).await?;
        }
    }

    Ok(())
}
