use crate::LUA;
use minijinja::{ErrorKind::UndefinedError, path_loader};
use mlua::{ExternalError, FromLua, LuaSerdeExt, UserData};
use std::{path::PathBuf, sync::Arc};

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
pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    lua.globals().set(
        "astra_internal__new_templating_engine",
        lua.create_async_function(|_, dir: Option<String>| async {
            let mut engine = TemplatingEngine {
                env: minijinja::Environment::new(),
                templates: Vec::new(),
                exclusions: Vec::new(),
            };

            if let Some(dir) = dir {
                let matches = parse_glob_pattern(&dir).map_err(|e| e.into_lua_err())?;

                engine.env.set_loader(path_loader(&matches.base_path));
                engine.add_template_files(matches.results).await?;
            }

            Ok(engine)
        })?,
    )?;

    Ok(())
}
impl TemplatingEngine<'_> {
    pub async fn add_template_files(&mut self, matches: Vec<(String, String)>) -> mlua::Result<()> {
        for (name, path) in matches {
            // get the file source
            match tokio::fs::read_to_string(path.clone()).await {
                Ok(source) => {
                    self.templates.push(Template {
                        name: name.clone(),
                        path: Some(path),
                        source: source.clone(),
                    });

                    if let Err(e) = self.env.add_template_owned(name, source) {
                        return Err(e.into_lua_err());
                    }
                }
                Err(e) => return Err(e.into_lua_err()),
            }
        }

        Ok(())
    }

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
            |_, this, (name, path): (String, String)| {
                let source = std::fs::read_to_string(&path).map_err(|e| e.into_lua_err())?;
                this.env
                    .add_template_owned(name.clone(), source.clone())
                    .map_err(|e| e.into_lua_err())?;
                this.templates.push(Template {
                    name,
                    path: Some(path),
                    source,
                });

                Ok(())
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
                      let lua_value = LUA.to_value(&args).map_err(|e| minijinja::Error::new(UndefinedError,
                              format!("ERROR TEMPLATE FUNCTION - Could not convert arguments into Lua table: {e}")))?;

                      let function_result = func.call_async::<mlua::Value>(lua_value).await.map_err(|e| minijinja::Error::new(UndefinedError,
                              format!("ERROR TEMPLATE FUNCTION - Could not run the function: {e}")))?;

                      LUA.from_value::<minijinja::Value>(function_result).map_err(|e| minijinja::Error::new(UndefinedError,
                              format!("ERROR TEMPLATE FUNCTION - Could not convert the return type: {e}")))
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

struct GlobFileResults {
    base_path: PathBuf,
    results: Vec<(String, String)>,
}

fn parse_glob_pattern(pattern: &str) -> Result<GlobFileResults, mlua::Error> {
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
    let mut results = Vec::new();
    let globs = glob::glob(pattern).map_err(|e| e.into_lua_err())?;
    for entry in globs {
        let path = entry.map_err(|e| e.into_lua_err())?;
        let full_path = path.to_string_lossy().to_string();

        if let Ok(relative) = path.strip_prefix(&base_path) {
            results.push((relative.to_string_lossy().to_string(), full_path));
        } else {
            // Fallback to full path if prefix can't be stripped
            results.push((full_path.clone(), full_path));
        }
    }

    Ok(GlobFileResults { base_path, results })
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
