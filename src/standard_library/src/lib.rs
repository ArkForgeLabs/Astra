mod crypto;
pub mod database;
mod datetime;
mod file_system;
pub mod global;
mod import;
mod templates;

pub use common::LUA;

#[derive(Debug, Clone)]
pub struct RuntimeFlags {
    pub stdlib_path: std::path::PathBuf,
    pub check_teal_code: bool,
}
pub static RUNTIME_FLAGS: tokio::sync::OnceCell<RuntimeFlags> = tokio::sync::OnceCell::const_new();

/// Global standard libraries and type definitions from Astra
pub static ASTRA_STD_LIBS: std::sync::LazyLock<include_dir::Dir<'_>> =
    std::sync::LazyLock::new(|| include_dir::include_dir!("astra"));

pub const TEAL_IMPORT_SCRIPT: &str = include_str!("./teal_check.lua");

pub async fn register_components(lua: &mlua::Lua) -> mlua::Result<()> {
    import::register_import_function(lua).await?;
    global::register_to_lua(lua)?;
    astra_serde::register_to_lua(lua)?;
    astra_http::server::register_to_lua(lua)?;
    astra_http::client::HTTPClientRequest::register_to_lua(lua)?;
    database::Database::register_to_lua(lua)?;
    datetime::AstraDateTime::register_to_lua(lua)?;
    crypto::register_to_lua(lua)?;
    file_system::register_to_lua(lua)?;
    templates::TemplatingEngine::register_to_lua(lua)?;

    Ok(())
}

// to capture all types of string literals
const ONE_HUNDRED_EQUAL_SIGNS: &str = "================================================\
====================================================";
pub async fn execute_teal_code(
    lua: &mlua::Lua,
    module_name: &str,
    module_content: &str,
) -> mlua::Result<mlua::Value> {
    let runtime_flags = crate::RUNTIME_FLAGS
        .get_or_init(|| async {
            crate::RuntimeFlags {
                stdlib_path: std::path::PathBuf::from("astra"),
                check_teal_code: false,
            }
        })
        .await;

    if runtime_flags.check_teal_code && module_name.ends_with(".tl") {
        lua.globals()
            .set("ASTRA_INTERNAL__CURRENT_SCRIPT", module_name)?;
        let compile_check_chunk = crate::TEAL_IMPORT_SCRIPT
            .replace("@SOURCE", module_content)
            .replace("@FILE_NAME", module_name);

        lua.load(compile_check_chunk)
            .set_name(module_name)
            .exec_async()
            .await?;
    }

    let module_content = if module_name.ends_with(".tl") {
        let module_name = module_name.replace("\\", "/");
        format!(
            "Astra.teal.load([{ONE_HUNDRED_EQUAL_SIGNS}[{module_content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{module_name}\")()"
        )
    } else {
        module_content.to_string()
    };

    let result = lua
        .load(module_content)
        .set_name(module_name)
        .eval_async::<mlua::Value>()
        .await?;

    Ok(result)
}
