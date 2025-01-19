use std::str::FromStr;

use crate::common::BodyLua;
use mlua::UserData;
use reqwest::Client;

#[allow(clippy::upper_case_acronyms)]
#[allow(dead_code)]
#[derive(Debug, Clone, Copy, serde::Deserialize)]
pub enum HTTPRequestMethod {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
    HEAD,
}
#[derive(Debug, Clone, mlua::FromLua)]
pub struct HTTPClientRequestOptions {
    pub method: HTTPRequestMethod,
    pub headers: Option<mlua::Table>,
    pub body: Option<mlua::Value>,
    pub form: Option<mlua::Table>,
}

#[derive(Debug)]
pub struct HTTPClientRequest {
    pub status_code: u16,
    pub headers: std::collections::HashMap<String, String>,
    pub remote_address: Option<String>,
    pub body: BodyLua,
}
impl crate::utils::LuaUtils for HTTPClientRequest {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_async_function(
            |lua,
             (url, options, callback): (
                String,
                Option<HTTPClientRequestOptions>,
                Option<mlua::Function>,
            )| async move {
                let request = Self::prepare_http_request(&lua, url, options).await;
                Self::execute_request(request, callback).await;

                Ok(())
            },
        )?;
        lua.globals().set("http_request", function)
    }
}
impl HTTPClientRequest {
    pub async fn prepare_http_request(
        _lua: &mlua::Lua,
        url: String,
        options: Option<HTTPClientRequestOptions>,
    ) -> reqwest::RequestBuilder {
        if let Some(options) = options {
            let mut client = match options.method {
                HTTPRequestMethod::POST => Client::new().post(url),
                HTTPRequestMethod::PATCH => Client::new().patch(url),
                HTTPRequestMethod::PUT => Client::new().put(url),
                HTTPRequestMethod::DELETE => Client::new().delete(url),
                HTTPRequestMethod::HEAD => Client::new().head(url),
                _ => Client::new().get(url),
            };

            if let Some(body) = options.body {
                if let mlua::Value::Table(_) = body {
                    client = client.json(&body);
                } else if let Ok(body_string) = body.to_string() {
                    client = client.body(body_string);
                }
            }

            if let Some(form) = options.form {
                client = client.form(&form);
            }

            if let Some(headers) = options.headers {
                let mut header_map = reqwest::header::HeaderMap::new();
                for (key, value) in headers.pairs::<String, String>().filter_map(|i| match i {
                    Ok(i) => Some(i),
                    Err(_) => None,
                }) {
                    if let Ok(header_key) = reqwest::header::HeaderName::from_str(key.as_str()) {
                        if let Ok(header_value) =
                            reqwest::header::HeaderValue::from_bytes(value.as_bytes())
                        {
                            header_map.insert(header_key, header_value);
                        }
                    }
                }

                client = client.headers(header_map);
            }
            client
        } else {
            Client::new().get(url)
        }
    }

    async fn execute_request(client: reqwest::RequestBuilder, callback: Option<mlua::Function>) {
        let response = match client.send().await {
            Ok(response) => {
                let status_code = response.status().as_u16();
                let remote_address = response.remote_addr().map(|i| i.to_string());
                let headers = response
                    .headers()
                    .iter()
                    .map(|(key, value)| {
                        (
                            key.to_string(),
                            String::from_utf8_lossy(value.as_bytes()).to_string(),
                        )
                    })
                    .collect::<std::collections::HashMap<String, String>>();

                match response.bytes().await {
                    Ok(bytes) => Ok(HTTPClientRequest {
                        body: BodyLua::new(bytes),
                        status_code,
                        headers,
                        remote_address,
                    }),

                    Err(e) => Err(mlua::Error::runtime(format!(
                        "Error executing the HTTP Request body: {e}"
                    ))),
                }
            }
            Err(e) => Err(mlua::Error::runtime(format!(
                "Error executing the HTTP Request: {e}"
            ))),
        };

        if let Some(callback) = callback {
            if let Err(e) = callback.call::<()>(response) {
                eprintln!("Error running the HTTP Request callback: {e}");
            }
        }
    }
}
impl UserData for HTTPClientRequest {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("body", |_, this, ()| Ok(this.body.clone()));
        methods.add_method("status_code", |_, this, ()| Ok(this.status_code));
        methods.add_method("headers", |_, this, ()| Ok(this.headers.clone()));
        methods.add_method("remote_address", |_, this, ()| {
            Ok(this.remote_address.clone())
        });
    }
}
