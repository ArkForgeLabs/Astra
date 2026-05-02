use crate::components::{AstraBuffer, astra_serde::sanetize_lua_input};
use mlua::{ExternalResult, LuaSerdeExt};
use reqwest::{Client, RequestBuilder};
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub enum HTTPClientRequestBodyTypes {
    String(String),
    Json(serde_json::Value),
    Bytes(Vec<u8>),
}

#[derive(Debug, Clone)]
pub struct HTTPClientRequest {
    pub url: String,
    pub method: String,
    pub headers: HashMap<String, String>,
    pub body: Option<HTTPClientRequestBodyTypes>,
    pub file: Option<String>,
    pub form: HashMap<String, String>,
}

impl HTTPClientRequest {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_function(|lua, details: mlua::Value| match details {
            mlua::Value::String(details) => Ok(Self {
                url: details.to_string_lossy(),
                method: "GET".to_string(),
                headers: HashMap::new(),
                body: None,
                file: None,
                form: HashMap::new(),
            }),
            mlua::Value::Table(details) => {
                let mut headers: HashMap<String, String> =
                    details.get("headers").unwrap_or(HashMap::new());
                let body = details.get::<mlua::Value>("body")?;
                let body = Self::body_parser(lua, &mut headers, body)?;

                Ok(Self {
                    url: details.get("url")?,
                    method: details
                        .get::<String>("method")
                        .map(|method| method.to_uppercase())
                        .unwrap_or("GET".to_string()),
                    headers,
                    body,
                    file: details.get::<String>("file").ok(),
                    form: details
                        .get::<HashMap<String, String>>("form")
                        .unwrap_or_default(),
                })
            }
            _ => Err(mlua::Error::runtime(
                "Bad argument, expected string or table",
            )),
        })?;
        lua.globals().set("astra_internal__http_request", function)
    }

    pub async fn request_builder(&self) -> mlua::Result<RequestBuilder> {
        let mut client = match self.method.to_uppercase().as_str() {
            "CONNECT" => Client::new().request(reqwest::Method::CONNECT, &self.url),
            "OPTIONS" => Client::new().request(reqwest::Method::OPTIONS, &self.url),
            "DELETE" => Client::new().request(reqwest::Method::DELETE, &self.url),
            "TRACE" => Client::new().request(reqwest::Method::TRACE, &self.url),
            "PATCH" => Client::new().request(reqwest::Method::PATCH, &self.url),
            "HEAD" => Client::new().request(reqwest::Method::HEAD, &self.url),
            "POST" => Client::new().request(reqwest::Method::POST, &self.url),
            "PUT" => Client::new().request(reqwest::Method::PUT, &self.url),
            "GET" => Client::new().request(reqwest::Method::GET, &self.url),
            _ => Client::new().request(
                reqwest::Method::from_bytes(self.method.to_uppercase().as_bytes())
                    .into_lua_err()?,
                &self.url,
            ),
        };

        if let Some(HTTPClientRequestBodyTypes::String(body)) = &self.body {
            client = client.body(body.clone())
        } else if let Some(HTTPClientRequestBodyTypes::Bytes(body)) = &self.body {
            client = client.body(body.clone())
        } else if let Some(HTTPClientRequestBodyTypes::Json(body)) = &self.body {
            client = client.json(&body)
        } else if let Some(file_body) = &self.file {
            let path = std::path::PathBuf::from(&file_body);
            let path_filename = path.clone();
            let file_form = reqwest::multipart::Form::new();

            let filename = path_filename
                .file_name()
                .and_then(|filename| filename.to_str())
                .unwrap_or("file.txt")
                .to_string();

            if let Ok(file_form) = file_form.file(filename, path).await {
                client = client.multipart(file_form)
            }
        }

        if !self.headers.is_empty() {
            for (key, value) in self.headers.iter() {
                client = client.header(key, value);
            }
        }
        if !self.form.is_empty() {
            client = client.form(&self.form);
        }

        Ok(client)
    }

    pub fn body_parser(
        lua: &mlua::Lua,
        headers: &mut HashMap<String, String>,
        body: mlua::Value,
    ) -> mlua::Result<Option<HTTPClientRequestBodyTypes>> {
        match body.clone() {
            mlua::Value::String(value) => {
                if !headers.contains_key("Content-Type") {
                    headers.insert("Content-Type".to_string(), "text/plain".to_string());
                }
                Ok(Some(HTTPClientRequestBodyTypes::String(
                    value.to_string_lossy(),
                )))
            }
            mlua::Value::Table(value) => {
                if crate::components::is_table_byte_array(&value)? {
                    return Ok(Some(HTTPClientRequestBodyTypes::Bytes(
                        lua.from_value::<Vec<u8>>(body.clone())?,
                    )));
                } else if crate::components::is_table_json(&value)? {
                    if !headers.contains_key("Content-Type") {
                        headers.insert("Content-Type".to_string(), "application/json".to_string());
                    }
                    return Ok(Some(HTTPClientRequestBodyTypes::Json(
                        lua.from_value::<serde_json::Value>(sanetize_lua_input(
                            lua,
                            body.clone(),
                        )?)?,
                    )));
                }
                Ok(None)
            }
            _ => Ok(None),
        }
    }

    pub fn headers_parser(header_map: &reqwest::header::HeaderMap) -> HashMap<String, String> {
        header_map
            .iter()
            .map(|(key, value)| {
                (
                    key.to_string(),
                    String::from_utf8_lossy(value.as_bytes()).to_string(),
                )
            })
            .collect::<std::collections::HashMap<String, String>>()
    }

    pub async fn response_to_http_client_response(
        response: reqwest::Response,
    ) -> super::HTTPClientResponse {
        super::HTTPClientResponse {
            remote_address: response.remote_addr().map(|i| i.to_string()),
            headers: Self::headers_parser(response.headers()),
            status_code: response.status().as_u16(),
            url: response.url().to_string(),
            body: if let Ok(bytes) = response.bytes().await {
                AstraBuffer::new(bytes)
            } else {
                AstraBuffer::new(bytes::Bytes::new())
            },
        }
    }
}
