use crate::components::http::server::cookie::AstraHTTPCookie;
use axum::http::{HeaderMap, HeaderName, HeaderValue, StatusCode};

// ! Support more cookie types like signed and private
#[derive(Debug, Clone)]
pub enum CookieOperation<'a> {
    Add(AstraHTTPCookie<'a>),
    Remove { key: String },
}

#[derive(Debug, Clone)]
pub struct ResponseLua<'a> {
    pub status_code: StatusCode,
    pub headers: HeaderMap,
    pub cookie_operations: Vec<CookieOperation<'a>>,
    pub redirect: Option<String>,
}
impl Default for ResponseLua<'_> {
    fn default() -> Self {
        Self {
            status_code: StatusCode::OK,
            headers: HeaderMap::new(),
            cookie_operations: Vec::new(),
            redirect: None,
        }
    }
}
impl mlua::UserData for ResponseLua<'_> {
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

        methods.add_method_mut("redirect_to", |_, this, redirect_to: String| {
            this.redirect = Some(redirect_to);

            Ok(())
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

        methods.add_method("get_headers", |lua, this, ()| {
            let header_map = lua.create_table()?;

            for (key, value) in this.headers.iter() {
                header_map.set(key.as_str(), String::from_utf8_lossy(value.as_bytes()))?;
            }

            Ok(header_map)
        });

        methods.add_method_mut("set_cookie", |_, this, cookie: AstraHTTPCookie| {
            this.cookie_operations.push(CookieOperation::Add(cookie));

            Ok(())
        });

        methods.add_method_mut("remove_cookie", |_, this, key: String| {
            this.cookie_operations.push(CookieOperation::Remove { key });

            Ok(())
        });
    }
}
