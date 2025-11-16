use super::AstraBufferMut;
use mlua::{ExternalError, LuaSerdeExt, UserData};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    let lua_globals = lua.globals();

    macro_rules! file_io_methods {
        ($name:expr, $method:expr) => {
            lua_globals.set(
                $name,
                lua.create_async_function(
                    |_, path: String| async move { Ok($method(path).await?) },
                )?,
            )?;
        };
    }

    lua_globals.set(
        "astra_internal__get_metadata",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::metadata(path).await {
                Ok(result) => Ok(AstraFileMetadata(result)),
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__new_buffer",
        lua.create_function(|_, capacity: usize| {
            Ok(AstraBufferMut::new(bytes::BytesMut::with_capacity(
                capacity,
            )))
        })?,
    )?;

    lua_globals.set(
        "astra_internal__open_file",
        lua.create_async_function(|_, path: String| async {
            Ok(AstraFile(tokio::fs::File::open(path).await?))
        })?,
    )?;

    file_io_methods!("astra_internal__read_file_bytes", tokio::fs::read);
    file_io_methods!(
        "astra_internal__read_file_string",
        tokio::fs::read_to_string
    );

    lua_globals.set(
        "astra_internal__write_file",
        lua.create_async_function(|lua, (path, value): (String, mlua::Value)| async move {
            match value.clone() {
                mlua::Value::String(contents) => {
                    Ok(tokio::fs::write(path, contents.to_string_lossy()).await?)
                }
                mlua::Value::Table(contents) => {
                    if super::is_table_byte_array(&contents)? {
                        Ok(tokio::fs::write(path, lua.from_value::<Vec<u8>>(value)?).await?)
                    } else if let Ok(contents) = serde_json::to_string(&contents) {
                        Ok(tokio::fs::write(path, contents).await?)
                    } else {
                        Err(mlua::Error::runtime("Invalid data type to write"))
                    }
                }
                _ => Err(mlua::Error::runtime("Invalid data type to write")),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__read_dir",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::read_dir(path).await {
                Ok(mut result) => {
                    let mut entries = Vec::new();
                    while let Some(entry_result) = result.next_entry().await.transpose() {
                        match entry_result {
                            Ok(entry) => entries.push(AstraDirEntry(entry)),
                            Err(_) => continue,
                        }
                    }
                    Ok(entries)
                }
                Err(e) => Err(e.into_lua_err()),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__get_current_dir",
        lua.create_function(|_, ()| Ok(std::env::current_dir()?))?,
    )?;

    lua_globals.set(
        "astra_internal__get_separator",
        lua.create_function(|_, ()| Ok(std::path::MAIN_SEPARATOR_STR))?,
    )?;

    file_io_methods!("astra_internal__exists", tokio::fs::try_exists);
    lua_globals.set(
        "astra_internal__change_dir",
        lua.create_function(|_, path: String| Ok(std::env::set_current_dir(path)?))?,
    )?;

    file_io_methods!("astra_internal__create_dir", tokio::fs::create_dir);
    file_io_methods!("astra_internal__create_dir_all", tokio::fs::create_dir_all);
    file_io_methods!("astra_internal__remove", tokio::fs::remove_file);
    file_io_methods!("astra_internal__remove_dir", tokio::fs::remove_dir);
    file_io_methods!("astra_internal__remove_dir_all", tokio::fs::remove_dir_all);

    lua_globals.set(
        "astra_internal__get_script_path",
        lua.create_function(|lua, ()| {
            let current_script_path: String =
                lua.globals().get("ASTRA_INTERNAL__CURRENT_SCRIPT")?;
            let current_script_path = std::path::PathBuf::from(
                current_script_path.replace(".", std::path::MAIN_SEPARATOR_STR),
            );

            let current_dir = std::env::current_dir()?;

            Ok(current_dir
                .join(current_script_path)
                .to_string_lossy()
                .to_string())
        })?,
    )?;

    Ok(())
}

#[derive(Debug)]
struct AstraFile(tokio::fs::File);
super::macros::impl_deref!(AstraFile, tokio::fs::File);
impl UserData for AstraFile {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        macro_rules! file_io_methods {
            ($name:expr, $method:ident) => {
                methods.add_async_method_mut(
                    $name,
                    |_, mut this, buffer: AstraBufferMut| async move {
                        let mut bytes = buffer.lock().await;
                        match this.$method(&mut *bytes).await {
                            Ok(result) => Ok(result),
                            Err(e) => Err(e.into_lua_err()),
                        }
                    },
                );
            };
        }

        // methods.add_async_method_mut("", |_, mut this, buffer: AstraBufferMut| async move {
        //     let mut bytes = buffer.0.lock().await;
        //     match this.0.read(&mut *bytes).await {
        //         Ok(result) => Ok(result),
        //         Err(e) => Err(e.into_lua_err()),
        //     }
        // });

        file_io_methods!("read", read);
        file_io_methods!("read_buf", read_buf);
        file_io_methods!("read_exact", read_exact);

        file_io_methods!("write", write);
        file_io_methods!("write_buf", write_all_buf);
    }
}

#[derive(Debug, Clone)]
struct AstraFileMetadata(std::fs::Metadata);
super::macros::impl_deref!(AstraFileMetadata, std::fs::Metadata);
impl UserData for AstraFileMetadata {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        macro_rules! file_metadata_methods {
            ($name:expr, $method:ident) => {
                methods.add_method($name, |_, this, ()| match this.$method() {
                    Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                        Ok(result) => Ok(result.as_secs()),
                        Err(e) => Err(e.into_lua_err()),
                    },
                    Err(e) => Err(e.into_lua_err()),
                });
            };
            ($name:expr, $wrap_type:ident, $method:ident) => {
                methods.add_method($name, |_, this, ()| Ok($wrap_type(this.$method())));
            };
        }

        file_metadata_methods!("last_accessed", accessed);
        file_metadata_methods!("last_modified", modified);
        file_metadata_methods!("created_at", created);
        file_metadata_methods!("file_type", AstraFileType, file_type);
        file_metadata_methods!("file_permissions", AstraFilePermissions, permissions);
    }
}

#[derive(Debug, Clone)]
struct AstraFilePermissions(std::fs::Permissions);
super::macros::impl_deref!(AstraFilePermissions, std::fs::Permissions);
impl UserData for AstraFilePermissions {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("is_readonly", |_, this, ()| Ok(this.readonly()));
        methods.add_method_mut("set_readonly", |_, this, mode: bool| {
            this.set_readonly(mode);
            Ok(())
        });
    }
}

#[derive(Debug, Clone)]
struct AstraFileType(std::fs::FileType);
super::macros::impl_deref!(AstraFileType, std::fs::FileType);
impl UserData for AstraFileType {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("is_file", |_, this, ()| Ok(this.is_file()));
        methods.add_method("is_dir", |_, this, ()| Ok(this.is_dir()));
        methods.add_method("is_symlink", |_, this, ()| Ok(this.is_symlink()));
    }
}

#[derive(Debug)]
struct AstraDirEntry(tokio::fs::DirEntry);
super::macros::impl_deref!(AstraDirEntry, tokio::fs::DirEntry);
impl UserData for AstraDirEntry {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("file_name", |_, this, ()| {
            match this.file_name().into_string() {
                Ok(file_name) => Ok(file_name),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            }
        });
        methods.add_async_method("file_type", |_, this, ()| async move {
            match this.file_type().await {
                Ok(file_type) => Ok(AstraFileType(file_type)),
                Err(e) => Err(e.into_lua_err()),
            }
        });
        methods.add_method("path", |_, this, ()| match this.path().to_str() {
            Some(path) => Ok(path.to_string()),
            None => Err(mlua::Error::runtime("Could not get the path")),
        });
    }
}
