mod commands;
pub use commands::*;
mod run;
pub use run::*;
mod upgrade;
pub use upgrade::*;
mod export;
pub use export::*;

pub async fn register_components(lua: &mlua::Lua) -> mlua::Result<()> {
    astra_small::import::register_import_function(lua).await?;
    astra_small::global::register_to_lua(lua)?;
    astra_serde::register_to_lua(lua)?;
    astra_http::server::register_to_lua(lua)?;
    astra_http::client::HTTPClientRequest::register_to_lua(lua)?;
    astra_small::database::Database::register_to_lua(lua)?;
    astra_small::datetime::AstraDateTime::register_to_lua(lua)?;
    astra_small::crypto::register_to_lua(lua)?;
    astra_small::file_system::register_to_lua(lua)?;
    astra_small::templates::TemplatingEngine::register_to_lua(lua)?;

    Ok(())
}
