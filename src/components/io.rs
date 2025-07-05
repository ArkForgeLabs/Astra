use crate::SCRIPT_PATH;
use mlua::UserData;

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<&'static str> {
    let lua_globals = lua.globals();

    lua_globals.set(
        "astra_internal__get_metadata",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::metadata(path).await {
                Ok(result) => Ok(AstraFileMetadata(result)),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__read_file_bytes",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::read(path).await {
                Ok(result) => Ok(result),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__read_file_string",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::read_to_string(path).await {
                Ok(result) => Ok(result),
                Err(e) => Err(mlua::Error::runtime(e)),
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
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__get_current_dir",
        lua.create_function(|_, ()| match std::env::current_dir() {
            Ok(result) => Ok(result),
            Err(e) => Err(mlua::Error::runtime(e)),
        })?,
    )?;

    lua_globals.set(
        "astra_internal__get_separator",
        lua.create_function(|_, ()| Ok(std::path::MAIN_SEPARATOR_STR))?,
    )?;

    lua_globals.set(
        "astra_internal__exists",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::try_exists(path).await {
                Ok(result) => Ok(result),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__change_dir",
        lua.create_function(|_, path: String| match std::env::set_current_dir(path) {
            Ok(_) => Ok(()),
            Err(e) => Err(mlua::Error::runtime(e)),
        })?,
    )?;

    lua_globals.set(
        "astra_internal__create_dir",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::create_dir(path).await {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__create_dir_all",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::create_dir_all(path).await {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::remove_file(path).await {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove_dir",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::remove_dir(path).await {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__remove_dir_all",
        lua.create_async_function(|_, path: String| async {
            match tokio::fs::remove_dir_all(path).await {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        })?,
    )?;

    lua_globals.set(
        "astra_internal__get_script_path",
        lua.create_function(|_, ()| Ok(SCRIPT_PATH.get().cloned()))?,
    )?;

    Ok(include_str!("io.lua"))
}

struct AstraFileMetadata(std::fs::Metadata);
impl UserData for AstraFileMetadata {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("last_accessed", |_, this, ()| match this.0.accessed() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            },
            Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
        });

        methods.add_method("created_at", |_, this, ()| match this.0.created() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            },
            Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
        });

        methods.add_method("last_modified", |_, this, ()| match this.0.modified() {
            Ok(file_name) => match file_name.duration_since(std::time::UNIX_EPOCH) {
                Ok(result) => Ok(result.as_secs()),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            },
            Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
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
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            }
        });
        methods.add_method("path", |_, this, ()| match this.0.path().to_str() {
            Some(path) => Ok(path.to_string()),
            None => Err(mlua::Error::runtime("Could not get the path")),
        });
    }
}
