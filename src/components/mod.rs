use mlua::{ExternalError, FromLua, LuaSerdeExt};

mod astra_serde;
mod crypto;
pub mod database;
mod datetime;
mod file_system;
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
    file_system::register_to_lua(lua)?;
    templates::TemplatingEngine::register_to_lua(lua)?;

    Ok(())
}

macro_rules! astra_buffer_types {
    ($name:ident, $buffer_type:ty) => {
        #[derive(Debug, Clone, FromLua)]
        pub struct $name(std::sync::Arc<tokio::sync::Mutex<$buffer_type>>);
        macros::impl_deref!($name, std::sync::Arc<tokio::sync::Mutex<$buffer_type>>);
        impl $name {
            pub fn new(bytes: $buffer_type) -> Self {
                Self(std::sync::Arc::new(tokio::sync::Mutex::new(bytes)))
            }
        }
        impl mlua::UserData for $name {
            fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
                methods.add_async_method("bytes", |_, this, ()| async move {
                    let bytes = this.lock().await;
                    Ok(bytes.to_vec())
                });
                methods.add_async_method("text", |_, this, ()| async move {
                    let bytes = this.lock().await;
                    Ok(String::from_utf8_lossy(&bytes).to_string())
                });
                methods.add_async_method("json", |lua, this, ()| async move {
                    let bytes = this.lock().await;
                    match serde_json::from_str::<serde_json::Value>(
                        &String::from_utf8_lossy(&bytes).to_string(),
                    ) {
                        Ok(parsed_json) => lua.to_value(&parsed_json),
                        Err(e) => Err(e.into_lua_err()),
                    }
                });
            }
        }
    };
}

astra_buffer_types!(AstraBuffer, bytes::Bytes);
astra_buffer_types!(AstraBufferMut, bytes::BytesMut);

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
            "TEAL_COMPILER.load([{ONE_HUNDRED_EQUAL_SIGNS}[{module_content}]{ONE_HUNDRED_EQUAL_SIGNS}], \"{module_name}\")()"
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

pub(crate) fn is_table_byte_array(table: &mlua::Table) -> mlua::Result<bool> {
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

pub async fn read_from_stdlib(
    stdlib_path: &std::path::Path,
    path: std::path::PathBuf,
) -> Option<String> {
    if let Ok(content) = tokio::fs::read_to_string(stdlib_path.join(path.clone())).await {
        return Some(content);
    }

    if let Some(file) = crate::ASTRA_STD_LIBS.get_file(path)
        && let Some(content) = file.contents_utf8()
    {
        return Some(content.to_string());
    }

    None
}

pub async fn load_teal(lua: &mlua::Lua) -> mlua::Result<()> {
    if !cfg!(feature = "luau") {
        let stdlib_path = &crate::RUNTIME_FLAGS
            .get_or_init(|| async {
                crate::RuntimeFlags {
                    stdlib_path: std::path::PathBuf::from("astra"),
                    check_teal_code: false,
                }
            })
            .await
            .stdlib_path;

        if let Some(content) =
            read_from_stdlib(stdlib_path, std::path::PathBuf::from("teal.lua")).await
        {
            lua.load(content).set_name("teal.lua").exec_async().await?;
        }

        // astra.d.tl
        if let Some(content) = read_from_stdlib(
            stdlib_path,
            std::path::PathBuf::from("teal").join("astra.d.tl"),
        )
        .await
        {
            crate::components::execute_teal_code(lua, "astra.d.tl", &content).await?;
        }
    }

    Ok(())
}
