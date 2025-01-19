use crate::common::LUA;
use axum::{
    body::Body,
    http::Request,
    response::IntoResponse,
    routing::{delete, get, options, patch, post, put, trace},
    Router,
};
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
}

pub async fn route(details: Route, request: Request<Body>) -> axum::response::Response {
    let request = {
        match LUA.create_userdata(crate::requests::RequestLua::new(request).await) {
            Ok(v) => Some(v),
            Err(e) => {
                eprintln!("Could not construct request: {e:#?}");

                None
            }
        }
    };
    let mut response: axum::http::Response<Body>;

    #[inline]
    fn handle_result(result: mlua::Result<mlua::Value>) -> axum::http::Response<Body> {
        match result {
            Ok(value) => match value {
                mlua::Value::String(plain) => plain.to_string_lossy().into_response(),
                mlua::Value::Table(_) => match LUA.from_value::<serde_json::Value>(value.clone()) {
                    Ok(result) => axum::Json(result).into_response(),
                    Err(e) => {
                        eprintln!("Result Parsing Error: {e}");

                        axum::http::StatusCode::INTERNAL_SERVER_ERROR.into_response()
                    }
                },
                _ => axum::http::StatusCode::OK.into_response(),
            },
            Err(e) => {
                eprintln!("Route Calling Error: {e}");

                axum::http::StatusCode::INTERNAL_SERVER_ERROR.into_response()
            }
        }
    }

    // if a response userdata can be created
    match LUA.create_userdata(crate::responses::ResponseLua::new()) {
        Ok(response_details) => {
            response = handle_result(
                details
                    .function
                    .call_async::<mlua::Value>((request, response_details.clone()))
                    .await,
            );

            if let Ok(response_details) = response_details.borrow::<crate::responses::ResponseLua>()
            {
                *response.status_mut() = response_details.status_code;

                for (key, value) in response_details.headers.iter() {
                    response.headers_mut().insert(key, value.clone());
                }
            }

            response
        }
        Err(e) => {
            eprintln!("Could not craft a response details userdata: {e:#?}");
            response = handle_result(details.function.call_async::<mlua::Value>(request).await);
            response
        }
    }
}

pub fn load_routes() -> Router {
    let mut router = Router::new();
    let mut routes = Vec::new();
    #[allow(clippy::unwrap_used)]
    LUA.globals()
        .get::<mlua::Table>("Astra")
        .unwrap()
        .for_each(|_key: mlua::Value, entry: mlua::Value| {
            if let Some(entry) = entry.as_table() {
                routes.push(crate::routes::Route {
                    path: LUA.from_value(entry.get("path")?)?,
                    static_dir: LUA.from_value(entry.get("static_dir")?)?,
                    static_file: LUA.from_value(entry.get("static_file")?)?,
                    method: LUA.from_value(entry.get("method")?)?,
                    function: entry.get::<mlua::Function>("func")?,
                });
            }

            Ok(())
        })
        .unwrap();

    for route_values in routes.clone() {
        let path = route_values.path.clone();
        let path = path.as_str();

        macro_rules! match_routes {
            ($route_function:expr) => {
                router.route(
                    path,
                    $route_function(|request: Request<Body>| route(route_values, request)),
                )
            };
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
                    router.nest_service(path, tower_http::services::ServeDir::new(serve_path))
                } else {
                    router
                }
            }
            Method::StaticFile => {
                if let Some(serve_path) = route_values.static_file {
                    router.nest_service(path, tower_http::services::ServeFile::new(serve_path))
                } else {
                    router
                }
            }
        }
    }

    #[cfg(feature = "compression")]
    if let Ok(should_compress) = crate::common::LUA
        .globals()
        .get::<mlua::Table>("Astra")
        .and_then(|setting| setting.get::<bool>("compression"))
    {
        if should_compress {
            router = router.layer(
                tower::ServiceBuilder::new()
                    .layer(tower_http::decompression::RequestDecompressionLayer::new())
                    .layer(tower_http::compression::CompressionLayer::new()),
            );
        }
    };

    router
}
