use mlua::{ExternalError, LuaSerdeExt, UserData};

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    let lua_globals = lua.globals();

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
        "astra_internal__read_file_bytes",
        lua.create_async_function(|_, path: String| async { Ok(tokio::fs::read(path).await?) })?,
    )?;

    lua_globals.set(
        "astra_internal__read_file_string",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::read_to_string(path).await?)
        })?,
    )?;

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

    lua_globals.set(
        "astra_internal__exists",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::try_exists(path).await?)
        })?,
    )?;

    lua_globals.set(
        "astra_internal__change_dir",
        lua.create_function(|_, path: String| Ok(std::env::set_current_dir(path)?))?,
    )?;

    lua_globals.set(
        "astra_internal__create_dir",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::create_dir(path).await?)
        })?,
    )?;

    lua_globals.set(
        "astra_internal__create_dir_all",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::create_dir_all(path).await?)
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::remove_file(path).await?)
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove_dir",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::remove_dir(path).await?)
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove_dir_all",
        lua.create_async_function(|_, path: String| async {
            Ok(tokio::fs::remove_dir_all(path).await?)
        })?,
    )?;

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

struct AstraFileMetadata(std::fs::Metadata);
impl UserData for AstraFileMetadata {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("last_accessed", |_, this, ()| match this.0.accessed() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(e.into_lua_err()),
            },
            Err(e) => Err(e.into_lua_err()),
        });

        methods.add_method("created_at", |_, this, ()| match this.0.created() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(e.into_lua_err()),
            },
            Err(e) => Err(e.into_lua_err()),
        });

        methods.add_method("last_modified", |_, this, ()| match this.0.modified() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(e.into_lua_err()),
            },
            Err(e) => Err(e.into_lua_err()),
        });

        methods.add_method("file_type", |_, this, ()| {
            Ok(AstraFileType(this.0.file_type()))
        });

        methods.add_method("file_permissions", |_, this, ()| {
            Ok(AstraFilePermissions(this.0.permissions()))
        });
    }
}

struct AstraFilePermissions(std::fs::Permissions);
impl UserData for AstraFilePermissions {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("is_readonly", |_, this, ()| Ok(this.0.readonly()));
        methods.add_method_mut("set_readonly", |_, this, mode: bool| {
            this.0.set_readonly(mode);
            Ok(())
        });

        // ? These are unix only
        // methods.add_method("get_mode", |_, this, ()| Ok(this.0.mode()));
        // methods.add_method_mut("set_mode", |_, this, mode: u32| {
        //     this.0.set_mode(mode);
        //     Ok(())
        // });
    }
}

struct AstraFileType(std::fs::FileType);
impl UserData for AstraFileType {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("is_file", |_, this, ()| Ok(this.0.is_file()));
        methods.add_method("is_dir", |_, this, ()| Ok(this.0.is_dir()));
        methods.add_method("is_symlink", |_, this, ()| Ok(this.0.is_symlink()));
    }
}
struct AstraDirEntry(tokio::fs::DirEntry);
impl UserData for AstraDirEntry {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("file_name", |_, this, ()| {
            match this.0.file_name().into_string() {
                Ok(file_name) => Ok(file_name),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            }
        });
        methods.add_async_method("file_type", |_, this, ()| async move {
            match this.0.file_type().await {
                Ok(file_type) => Ok(AstraFileType(file_type)),
                Err(e) => Err(e.into_lua_err()),
            }
        });
        methods.add_method("path", |_, this, ()| match this.0.path().to_str() {
            Some(path) => Ok(path.to_string()),
            None => Err(mlua::Error::runtime("Could not get the path")),
        });
    }
}
