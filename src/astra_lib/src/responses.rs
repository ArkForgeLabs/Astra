use axum::http::{HeaderMap, HeaderName, HeaderValue, StatusCode};

use crate::common::LUA;

#[derive(Debug, Clone)]
pub struct ResponseLua {
    pub status_code: StatusCode,
    pub headers: HeaderMap,
}
impl ResponseLua {
    pub fn new() -> Self {
        Self {
            status_code: StatusCode::OK,
            headers: HeaderMap::new(),
        }
    }
}
impl mlua::UserData for ResponseLua {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("set_status_code", |_, this, status_code: u16| {
            match StatusCode::from_u16(status_code) {
                Ok(status_code) => {
                    this.status_code = status_code;
                    Ok(())
                }
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not set the response HTTP status code: {e:#?}"
                ))),
            }
        });

        methods.add_method_mut(
            "set_header",
            |_, this, (header_key, header_value): (String, String)| match HeaderName::from_lowercase(
                header_key.to_lowercase().as_bytes(),
            ) {
                Ok(header_key) => match HeaderValue::from_str(&header_value) {
                    Ok(header_value) => {
                        this.headers.insert(header_key, header_value);

                        Ok(())
                    }
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "Could not set the header (value): {e:#?}"
                    ))),
                },
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not set the header (key): {e:#?}"
                ))),
            },
        );

        methods.add_method_mut("remove_header", |_, this, header_key: String| {
            match HeaderName::from_lowercase(header_key.to_lowercase().as_bytes()) {
                Ok(header_key) => {
                    this.headers.remove(header_key);

                    Ok(())
                }
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not set the header (key): {e:#?}"
                ))),
            }
        });

        methods.add_method("get_headers", |_, this, ()| {
            let header_map = LUA.create_table()?;

            for (key, value) in this.headers.iter() {
                header_map.set(key.as_str(), String::from_utf8_lossy(value.as_bytes()))?;
            }

            Ok(header_map)
        });
    }
}
