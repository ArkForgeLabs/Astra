use crate::LUA;
use minijinja::ErrorKind::UndefinedError;
use mlua::{ExternalError, FromLua, LuaSerdeExt, UserData};
use std::sync::Arc;

/// Will include the name, path, and source
#[derive(Debug, Clone, FromLua)]
struct Template {
    name: String,
    path: Option<String>,
    source: String,
}

#[derive(Debug, Clone, FromLua)]
pub struct TemplatingEngine<'a> {
    pub env: minijinja::Environment<'a>,
    templates: Vec<Template>,
    pub exclusions: Vec<Arc<str>>,
}
impl TemplatingEngine<'static> {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        lua.globals().set(
            "astra_internal__new_templating_engine",
            lua.create_async_function(|_, dir: Option<String>| async {
                let mut engine = Self {
                    env: minijinja::Environment::new(),
                    templates: Vec::new(),
                    exclusions: Vec::new(),
                };

                // ? For loading other files too
                // ? env.set_loader(path_loader("examples/templates"));

                if let Some(dir) = dir {
                    match parse_glob_pattern(&dir) {
                        Ok(matches) => {
                            for (name, path) in matches {
                                // get the file source
                                match tokio::fs::read_to_string(path.clone()).await {
                                    Ok(source) => {
                                        engine.templates.push(Template {
                                            name: name.clone(),
                                            path: Some(path),
                                            source: source.clone(),
                                        });

                                        if let Err(e) = engine.env.add_template_owned(name, source)
                                        {
                                            return Err(e.into_lua_err());
                                        }
                                    }
                                    Err(e) => return Err(e.into_lua_err()),
                                }
                            }
                        }
                        Err(e) => return Err(e.into_lua_err()),
                    }
                }

                Ok(engine)
            })?,
        )?;

        Ok(())
    }
}
impl TemplatingEngine<'_> {
    pub fn reload_templates(&mut self) -> mlua::Result<()> {
        for i in self.templates.iter() {
            let source = if let Some(source) = i
                .path
                .clone()
                .and_then(|path| std::fs::read_to_string(path).ok())
            {
                source
            } else {
                i.source.clone()
            };

            if let Err(e) = self.env.add_template_owned(i.name.clone(), source) {
                return Err(e.into_lua_err());
            }
        }

        Ok(())
    }
}
impl UserData for TemplatingEngine<'_> {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut(
            "add_template",
            |_, this, (name, template): (String, String)| match this
                .env
                .add_template_owned(name.clone(), template.clone())
            {
                Ok(()) => {
                    this.templates.push(Template {
                        name,
                        path: None,
                        source: template,
                    });

                    Ok(())
                }
                Err(e) => Err(mlua::Error::runtime(format!(
                    "TEMPLATING ERROR - Could not add a template: {e}"
                ))),
            },
        );
        methods.add_method_mut(
            "add_template_file",
            |_, this, (name, path): (String, String)| match std::fs::read_to_string(&path) {
                Ok(source) => match this.env.add_template_owned(name.clone(), source.clone()) {
                    Ok(()) => {
                        this.templates.push(Template {
                            name,
                            path: Some(path),
                            source,
                        });

                        Ok(())
                    }
                    Err(e) => Err(e.into_lua_err()),
                },
                Err(e) => Err(e.into_lua_err()),
            },
        );
        methods.add_method_mut("remove_template", |_, this, name: String| {
            this.env.remove_template(&name.clone());

            this.templates = this
                .templates
                .iter()
                .filter(|template| template.name != name)
                .cloned()
                .collect::<Vec<_>>();

            Ok(())
        });
        methods.add_method("get_template_names", |_, this, _: ()| {
            Ok(this
                .templates
                .iter()
                .map(|template| template.name.clone())
                .collect::<Vec<_>>())
        });
        methods.add_method_mut("exclude_templates", |_, this, names: Vec<String>| {
            for i in names {
                this.templates = this
                    .templates
                    .iter()
                    .filter(|template| template.name != i)
                    .cloned()
                    .collect::<Vec<_>>();
                this.exclusions.push(i.into());
            }

            Ok(())
        });
        methods.add_method_mut("reload_templates", |_, this, _: ()| this.reload_templates());
        methods.add_method_mut(
            "add_function",
            |_, this, (name, func): (String, mlua::Function)| {
                let function = move |args: minijinja::Value|
                                                                            -> Result<minijinja::Value, minijinja::Error> {
                    futures::executor::block_on(async {
                        match LUA.to_value(&args) {
                            Ok(val) =>  match func.call_async::<mlua::Value>(val).await {
                                Ok(val) =>  match LUA.from_value::<minijinja::Value>(val) {
                                    Ok(val) => Ok(val),
                                    Err(e) =>
                                        Err(minijinja::Error::new(UndefinedError,
                                                format!("ERROR TEMPLATE FUNCTION - Could not convert the return type: {e}"))),
                                },
                                Err(e) =>
                                    Err(minijinja::Error::new(UndefinedError,
                                            format!("ERROR TEMPLATE FUNCTION - Could not run the function: {e}"))),
                            },
                            Err(e) =>
                                Err(minijinja::Error::new(UndefinedError,
                                        format!("ERROR TEMPLATE FUNCTION - Could not convert arguments into Lua table: {e}"))),
                        }
                    })
                };

                // have to leak the name
                let static_name: &'static str = Box::leak(name.into_boxed_str());
                this.env
                    .add_function(static_name, function);
                Ok(())
            },
        );

        methods.add_method(
            "render",
            |lua, this, (name, context): (String, Option<mlua::Table>)| match this
                .env
                .get_template(&name)
            {
                Ok(result) => {
                    match result.render(if let Some(context) = context {
                        lua.from_value::<minijinja::Value>(lua.to_value(&context)?)?
                    } else {
                        minijinja::Value::UNDEFINED
                    }) {
                        Ok(result) => Ok(result),
                        Err(e) => Err(e.into_lua_err()),
                    }
                }
                Err(e) => Err(e.into_lua_err()),
            },
        );
    }
}

fn parse_glob_pattern(pattern: &str) -> Result<Vec<(String, String)>, mlua::Error> {
    // Convert glob pattern to Path
    let pattern_path = std::path::Path::new(pattern);

    // Determine base directory by finding the part before the first wildcard
    let mut base_path = std::path::PathBuf::new();
    for component in pattern_path.components() {
        if let std::path::Component::Normal(os_str) = component {
            let part = os_str.to_string_lossy();
            if part.contains('*') || part.contains('?') || part.contains('[') {
                break;
            }
            base_path.push(part.as_ref());
        } else {
            base_path.push(component);
        }
    }

    // Perform the actual glob matching
    let mut result = Vec::new();
    match glob::glob(pattern) {
        Ok(globs) => {
            for entry in globs {
                match entry {
                    Ok(path) => {
                        let full_path = path.to_string_lossy().to_string();
                        if let Ok(relative) = path.strip_prefix(&base_path) {
                            result.push((relative.to_string_lossy().to_string(), full_path));
                        } else {
                            // Fallback to full path if prefix can't be stripped
                            result.push((full_path.clone(), full_path));
                        }
                    }
                    Err(e) => return Err(e.into_lua_err()),
                }
            }
            Ok(result)
        }
        Err(e) => Err(e.into_lua_err()),
    }
}

// ============================================================== //
// ========================= Markdown =========================== //
// ============================================================== //

pub fn markdown_support(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__new_markdown_ast",
        lua.create_function(|lua, input: String| {
            match markdown::to_mdast(&input, &markdown::ParseOptions::gfm()) {
                Ok(result) => match serde_value::to_value(result) {
                    Ok(result) => lua.to_value(&result),
                    Err(e) => Err(e.into_lua_err()),
                },
                Err(e) => Err(e.to_string().into_lua_err()),
            }
        })?,
    )?;

    lua.globals().set(
        "astra_internal__new_markdown_html",
        lua.create_function(|_, input: String| {
            match markdown::to_html_with_options(&input, &markdown::Options::gfm()) {
                Ok(result) => Ok(result),
                Err(e) => Err(e.to_string().into_lua_err()),
            }
        })?,
    )?;

    Ok(())
}
