use crate::SCRIPT_PATH;
use mlua::UserData;

pub struct FileIO {}
impl crate::AstraComponent for FileIO {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let astra_io = lua.create_table()?;

        astra_io.set(
            "get_metadata",
            lua.create_function(|_, path: String| match std::fs::metadata(path) {
                Ok(result) => Ok(AstraFileMetadata(result)),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "read_dir",
            lua.create_function(|_, path: String| match std::fs::read_dir(path) {
                Ok(result) => Ok(result
                    .filter_map(|entry| {
                        if let Ok(entry) = entry {
                            Some(AstraDirEntry(entry))
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "get_current_dir",
            lua.create_function(|_, ()| match std::env::current_dir() {
                Ok(result) => Ok(result),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "exists",
            lua.create_function(|_, path: String| match std::fs::exists(path) {
                Ok(result) => Ok(result),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "change_dir",
            lua.create_function(|_, path: String| match std::env::set_current_dir(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "create_dir",
            lua.create_function(|_, path: String| match std::fs::create_dir(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "create_dir_all",
            lua.create_function(|_, path: String| match std::fs::create_dir_all(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "remove",
            lua.create_function(|_, path: String| match std::fs::remove_file(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "remove_dir",
            lua.create_function(|_, path: String| match std::fs::remove_dir(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "remove_dir_all",
            lua.create_function(|_, path: String| match std::fs::remove_dir_all(path) {
                Ok(_) => Ok(()),
                Err(e) => Err(mlua::Error::runtime(e)),
            })?,
        )?;

        astra_io.set(
            "get_script_path",
            lua.create_function(|_, ()| Ok(SCRIPT_PATH.get().cloned()))?,
        )?;

        lua.globals().set("AstraIO", astra_io)?;

        Ok(())
    }
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
struct AstraDirEntry(std::fs::DirEntry);
impl UserData for AstraDirEntry {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("file_name", |_, this, ()| {
            match this.0.file_name().into_string() {
                Ok(file_name) => Ok(file_name),
                Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
            }
        });
        methods.add_method("file_type", |_, this, ()| match this.0.file_type() {
            Ok(file_type) => Ok(AstraFileType(file_type)),
            Err(e) => Err(mlua::Error::runtime(format!("{e:?}"))),
        });
        methods.add_method("path", |_, this, ()| match this.0.path().to_str() {
            Some(path) => Ok(path.to_string()),
            None => Err(mlua::Error::runtime("Could not get the path")),
        });
    }
}
