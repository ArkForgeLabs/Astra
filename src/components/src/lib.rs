use mlua::LuaSerdeExt;
use tokio::sync::OnceCell;
mod crypto;
mod database;
mod fileio;
pub mod global_functions;
pub mod http;
mod http_client_request;
mod require;
mod tasks;

/// Global script path.
pub static SCRIPT_PATH: OnceCell<std::path::PathBuf> = OnceCell::const_new();

pub trait AstraComponent {
    fn register_to_lua(lua: &mlua::Lua) -> impl std::future::Future<Output = mlua::Result<()>>;
}

pub async fn register_components(lua: &mlua::Lua) -> mlua::Result<()> {
    http::register_run_function(lua).await?;
    http_client_request::HTTPClientRequest::register_to_lua(lua).await?;
    database::Database::register_to_lua(lua).await?;
    tasks::LuaTask::register_to_lua(lua).await?;
    tasks::LuaTimeout::register_to_lua(lua).await?;
    tasks::LuaInterval::register_to_lua(lua).await?;
    crypto::LuaCrypto::register_to_lua(lua).await?;
    fileio::FileIO::register_to_lua(lua).await?;
    require::LuaRequire::register_to_lua(lua).await?;

    Ok(())
}

#[derive(Debug, Clone)]
pub struct BodyLua {
    #[allow(unused)]
    pub body: bytes::Bytes,
    pub body_string: String,
}
impl BodyLua {
    pub fn new(bytes: bytes::Bytes) -> Self {
        let body_string = String::from_utf8_lossy(&bytes).to_string();

        Self {
            body: bytes,
            body_string,
        }
    }
}
impl mlua::UserData for BodyLua {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("text", |_, this, ()| Ok(this.body_string.clone()));

        methods.add_method("json", |lua, this, ()| {
            match serde_json::from_str::<serde_json::Value>(&this.body_string) {
                Ok(body_json) => Ok(lua.to_value(&body_json)?),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not parse the body as JSON: {e:#?}"
                ))),
            }
        });
    }
}

#[allow(unused)]
pub mod macros {
    macro_rules! impl_deref {
        ($struct:ty,$type:ty) => {
            impl std::ops::Deref for $struct {
                type Target = $type;

                fn deref(&self) -> &Self::Target {
                    &self.0
                }
            }
            impl std::ops::DerefMut for $struct {
                fn deref_mut(&mut self) -> &mut Self::Target {
                    &mut self.0
                }
            }
        };
    }

    macro_rules! impl_deref_field {
        ($struct:ty,$type:ty,$field:ident) => {
            impl std::ops::Deref for $struct {
                type Target = $type;

                fn deref(&self) -> &Self::Target {
                    &self.$field
                }
            }
            impl std::ops::DerefMut for $struct {
                fn deref_mut(&mut self) -> &mut Self::Target {
                    &mut self.$field
                }
            }
        };
    }

    pub(crate) use impl_deref;
    pub(crate) use impl_deref_field;
}
