use crate::http::{
    configs::RouteConfiguration,
    requests::{self, RequestLua},
    responses::{self, CookieOperation},
    routes,
};
use axum::{
    Router,
    body::Body,
    extract::DefaultBodyLimit,
    http::Request,
    response::IntoResponse,
    routing::{delete, get, options, patch, post, put, trace},
};
use axum_extra::extract::{CookieJar, cookie::Cookie};
use mlua::LuaSerdeExt;

#[derive(Debug, Clone, Copy, mlua::FromLua, serde::Serialize, serde::Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum Method {
    Get,
    Post,
    Put,
    Delete,
    Options,
    Patch,
    Trace,
    StaticDir,
    StaticFile,
}
#[derive(Debug, Clone, mlua::FromLua, PartialEq)]
pub struct Route {
    pub path: String,
    pub static_dir: Option<String>,
    pub static_file: Option<String>,
    pub method: Method,
    pub function: mlua::Function,
    pub config: RouteConfiguration,
}

pub async fn route(
    lua: &mlua::Lua,
    details: Route,
    request: Request<Body>,
) -> Result<(CookieJar, axum::response::Response), axum::http::StatusCode> {
    let request = requests::RequestLua::new(request).await;
    // find a way to add keys here
    let cookie_jar = request.cookie_jar.clone();

    async fn route_inner(
        lua: &mlua::Lua,
        details: Route,
        cookie_jar: CookieJar,
        request: RequestLua,
    ) -> mlua::Result<(CookieJar, axum::response::Response)> {
        let request = lua.create_userdata(request)?;
        let response = lua.create_userdata(responses::ResponseLua::default())?;
        let mut cookie_jar = cookie_jar.clone();

        // if a response userdata can be created
        let result = details
            .function
            .call_async::<mlua::Value>((request, response.clone()))
            .await?;

        let mut resulting_response = match result {
            mlua::Value::String(plain) => plain.to_string_lossy().into_response(),
            mlua::Value::Table(_) => {
                axum::Json(lua.from_value::<serde_json::Value>(result.clone())?).into_response()
            }
            _ => axum::http::StatusCode::OK.into_response(),
        };

        let response_details = response.borrow::<responses::ResponseLua>()?;
        *resulting_response.status_mut() = response_details.status_code;

        for (key, value) in response_details.headers.iter() {
            resulting_response.headers_mut().insert(key, value.clone());
        }

        for cookie_operation in response_details.cookie_operations.clone().into_iter() {
            match cookie_operation {
                CookieOperation::Add(cookie) => {
                    cookie_jar = cookie_jar.clone().remove(cookie.0.clone());
                    cookie_jar = cookie_jar.clone().add(cookie.0);
                }
                CookieOperation::Remove { key } => {
                    cookie_jar = cookie_jar.clone().remove(Cookie::from(key));
                }
            };
        }

        Ok((cookie_jar, resulting_response))
    }

    match route_inner(lua, details, cookie_jar.clone(), request).await {
        Ok(response) => Ok((response.0, response.1)),
        Err(e) => {
            eprintln!("Error executing the route: {e}");

            Err(axum::http::StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

pub fn load_routes(lua: &mlua::Lua) -> Router {
    let mut router = Router::new();
    let mut routes = Vec::new();
    #[allow(clippy::unwrap_used)]
    lua.globals()
        .get::<mlua::Table>("Astra")
        .and_then(|settings| settings.get::<mlua::Table>("routes"))
        .unwrap()
        .for_each(|_key: mlua::Value, entry: mlua::Value| {
            if let Some(entry) = entry.as_table() {
                routes.push(routes::Route {
                    path: lua.from_value(entry.get("path")?)?,
                    static_dir: lua.from_value(entry.get("static_dir")?)?,
                    static_file: lua.from_value(entry.get("static_file")?)?,
                    method: lua.from_value(entry.get("method")?)?,
                    function: entry.get::<mlua::Function>("func")?,
                    config: lua.from_value(entry.get("config")?)?,
                });
            }

            Ok(())
        })
        .unwrap();

    for route_values in routes.clone() {
        let path = route_values.path.clone();
        let path = path.as_str();

        let config = route_values.config.clone();
        let body_limit = config.body_limit;

        macro_rules! match_routes {
            ($route_function:expr) => {{
                let mut route_function = $route_function(move |request: Request<Body>| {
                    route(&lua, route_values, request)
                });
                if let Some(body_limit) = body_limit {
                    route_function = route_function.layer(DefaultBodyLimit::max(body_limit))
                }

                router.route(path, route_function)
            }};
        }

        router = match route_values.method {
            Method::Get => match_routes!(get),
            Method::Post => match_routes!(post),
            Method::Put => match_routes!(put),
            Method::Delete => match_routes!(delete),
            Method::Options => match_routes!(options),
            Method::Patch => match_routes!(patch),
            Method::Trace => match_routes!(trace),
            Method::StaticDir => {
                if let Some(serve_path) = route_values.static_dir {
                    if path == "/" {
                        router.fallback_service(tower_http::services::ServeDir::new(serve_path))
                    } else {
                        router.nest_service(path, tower_http::services::ServeDir::new(serve_path))
                    }
                } else {
                    router
                }
            }
            Method::StaticFile => {
                if let Some(serve_path) = route_values.static_file {
                    if path == "/" {
                        router.fallback_service(tower_http::services::ServeFile::new(serve_path))
                    } else {
                        router.nest_service(path, tower_http::services::ServeFile::new(serve_path))
                    }
                } else {
                    router
                }
            }
        }
    }

    if let Ok(settings) = lua.globals().get::<mlua::Table>("Astra") {
        // if let Ok(default_body_limit) = settings.get::<usize>("default_body_limit") {
        //     router = router.layer(DefaultBodyLimit::max(default_body_limit));
        // };

        if let Ok(should_compress) = settings.get::<bool>("compression") {
            if should_compress {
                router = router.layer(
                    tower::ServiceBuilder::new()
                        .layer(tower_http::decompression::RequestDecompressionLayer::new())
                        .layer(tower_http::compression::CompressionLayer::new()),
                );
            }
        };
    }

    router
}
