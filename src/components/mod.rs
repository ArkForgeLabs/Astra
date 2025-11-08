use mlua::{ExternalError, LuaSerdeExt};

mod astra_serde;
mod crypto;
pub mod database;
mod datetime;
mod file_io;
pub mod global;
pub mod http;
mod import;
mod templates;

pub async fn register_components(lua: &mlua::Lua) -> mlua::Result<()> {
    import::register_import_function(lua).await?;
    global::register_to_lua(lua)?;
    astra_serde::register_to_lua(lua)?;
    http::server::register_to_lua(lua)?;
    http::client::HTTPClientRequest::register_to_lua(lua)?;
    database::Database::register_to_lua(lua)?;
    datetime::AstraDateTime::register_to_lua(lua)?;
    crypto::register_to_lua(lua)?;
    file_io::register_to_lua(lua)?;
    templates::TemplatingEngine::register_to_lua(lua)?;

    Ok(())
}

#[derive(Debug, Clone)]
pub struct AstraHTTPBody {
    #[allow(unused)]
    pub body: bytes::Bytes,
    pub body_string: String,
}
impl AstraHTTPBody {
    pub fn new(bytes: bytes::Bytes) -> Self {
        let body_string = String::from_utf8_lossy(&bytes).to_string();

        Self {
            body: bytes,
            body_string,
        }
    }
}
impl mlua::UserData for AstraHTTPBody {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("text", |_, this, ()| Ok(this.body_string.clone()));

        methods.add_method("json", |lua, this, ()| {
            match serde_json::from_str::<serde_json::Value>(&this.body_string) {
                Ok(body_json) => lua.to_value(&body_json),
                Err(e) => Err(e.into_lua_err()),
            }
        });
    }
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

fn is_table_json(table: &mlua::Table) -> mlua::Result<bool> {
    let mut has_string_key = false;
    let mut has_non_sequential_integer_key = false;
    let mut max_int_key = 0;

    for pair in table.pairs::<mlua::Value, mlua::Value>() {
        let (key, _) = pair?;
        match key {
            mlua::Value::String(_) => has_string_key = true,
            mlua::Value::Integer(i) => {
                if i <= 0 || i > max_int_key + 1 {
                    has_non_sequential_integer_key = true;
                }
                max_int_key = max_int_key.max(i);
            }
            _ => return Ok(true), // Other key types (e.g., floats, booleans) are JSON-like
        }
    }

    Ok(has_string_key || has_non_sequential_integer_key)
}

fn is_table_byte_array(table: &mlua::Table) -> mlua::Result<bool> {
    let mut i = 1;
    for pair in table.pairs::<i64, i64>() {
        let (key, value) = pair?;
        if key != i || !(0..=255).contains(&value) {
            return Ok(false);
        }
        i += 1;
    }
    Ok(true)
}
