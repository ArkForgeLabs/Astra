use mlua::UserData;

pub struct LuaRegex {
    re: regex::Regex,
}
impl LuaRegex {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_function(|_, regex_string: String| {
            match regex::Regex::new(&regex_string) {
                Ok(re) => Ok(Self { re }),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not compile the regex: {e}"
                ))),
            }
        })?;
        lua.globals().set("astra_internal__regex", function)?;

        Ok(())
    }
}
impl UserData for LuaRegex {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("captures", |_, this, content: String| {
            let captures = this
                .re
                .captures_iter(&content)
                .map(|capture| {
                    capture
                        .iter()
                        .filter_map(|content| content.map(|content| content.as_str().to_string()))
                        .collect::<Vec<_>>()
                })
                .collect::<Vec<_>>();

            Ok(captures)
        });

        methods.add_method("is_match", |_, this, content: String| {
            Ok(this.re.is_match(&content))
        });

        methods.add_method(
            "replace",
            |_, this, (content, replace, limit): (String, String, Option<usize>)| {
                Ok(this
                    .re
                    .replacen(&content, limit.unwrap_or_default(), replace)
                    .to_string())
            },
        );
    }
}
