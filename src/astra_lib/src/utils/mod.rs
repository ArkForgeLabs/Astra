#[cfg(feature = "sqlx")]
mod database;
mod http_client_request;
mod tasks;

pub trait LuaUtils {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()>;
}

pub async fn register_utils(lua: &mlua::Lua) -> mlua::Result<()> {
    #[cfg(feature = "sqlx")]
    database::Database::register_to_lua(lua).await?;
    http_client_request::HTTPClientRequest::register_to_lua(lua).await?;
    tasks::LuaTask::register_to_lua(lua).await?;

    Ok(())
}
