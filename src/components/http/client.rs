use crate::components::AstraBuffer;
use futures::StreamExt;
use mlua::{LuaSerdeExt, UserData};
use reqwest::{Client, RequestBuilder};
use std::collections::HashMap; // Add this for stream support

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
                let mut headers: HashMap<String, String> = details.get("headers")?;
                let body = details.get::<mlua::Value>("body")?;
                let body = match body.clone() {
                    mlua::Value::String(value) => {
                        if !headers.contains_key("Content-Type") {
                            headers.insert("Content-Type".to_string(), "text/plain".to_string());
                        }
                        Some(HTTPClientRequestBodyTypes::String(value.to_string_lossy()))
                    }
                    mlua::Value::Table(value) => {
                        if crate::components::is_table_json(&value)? {
                            if !headers.contains_key("Content-Type") {
                                headers.insert(
                                    "Content-Type".to_string(),
                                    "application/json".to_string(),
                                );
                            }
                            Some(HTTPClientRequestBodyTypes::Json(
                                lua.from_value::<serde_json::Value>(body.clone())?,
                            ))
                        } else if crate::components::is_table_byte_array(&value)? {
                            Some(HTTPClientRequestBodyTypes::Bytes(
                                lua.from_value::<Vec<u8>>(body.clone())?,
                            ))
                        } else {
                            None
                        }
                    }
                    _ => None,
                };
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

    pub async fn request_builder(&self) -> RequestBuilder {
        let mut client = match self.method.to_uppercase().as_str() {
            "POST" => Client::new().post(&self.url),
            "PATCH" => Client::new().patch(&self.url),
            "PUT" => Client::new().put(&self.url),
            "DELETE" => Client::new().delete(&self.url),
            "HEAD" => Client::new().head(&self.url),
            _ => Client::new().get(&self.url),
        };
        client = if let Some(HTTPClientRequestBodyTypes::String(body)) = &self.body {
            client.body(body.clone())
        } else if let Some(HTTPClientRequestBodyTypes::Bytes(body)) = &self.body {
            client.body(body.clone())
        } else if let Some(HTTPClientRequestBodyTypes::Json(body)) = &self.body {
            client.json(&body)
        } else if let Some(file_body) = &self.file {
            let path = std::path::PathBuf::from(&file_body);
            let path_filename = path.clone();
            let file_form = reqwest::multipart::Form::new();
            if let Ok(file_form) = file_form
                .file(
                    if let Some(filename) = path_filename
                        .file_name()
                        .and_then(|filename| filename.to_str())
                    {
                        filename.to_string()
                    } else {
                        "file.txt".to_string()
                    },
                    path,
                )
                .await
            {
                client.multipart(file_form)
            } else {
                client
            }
        } else {
            client
        };
        if !self.headers.is_empty() {
            for (key, value) in self.headers.iter() {
                client = client.header(key, value);
            }
        }
        if !self.form.is_empty() {
            client = client.form(&self.form);
        }
        client
    }

    pub async fn response_to_http_client_response(
        response: reqwest::Response,
    ) -> HTTPClientResponse {
        let url = response.url().to_string();
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
        let body = if let Ok(bytes) = response.bytes().await {
            AstraBuffer::new(bytes)
        } else {
            AstraBuffer::new(bytes::Bytes::new())
        };
        HTTPClientResponse {
            url,
            status_code,
            remote_address,
            body,
            headers,
        }
    }
}

impl UserData for HTTPClientRequest {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("set_method", |_, this, method: String| {
            let mut request = this.clone();
            request.method = method;
            Ok(request)
        });
        methods.add_method_mut("set_header", |_, this, (key, value): (String, String)| {
            let mut request = this.clone();
            request.headers.insert(key, value);
            Ok(request)
        });
        methods.add_method_mut(
            "set_headers",
            |_, this, headers: HashMap<String, String>| {
                let mut request = this.clone();
                request.headers = headers;
                Ok(request)
            },
        );
        methods.add_method_mut("set_form", |_, this, (key, value): (String, String)| {
            let mut request = this.clone();
            request.form.insert(key, value);
            Ok(request)
        });
        methods.add_method_mut("set_forms", |_, this, form: HashMap<String, String>| {
            let mut request = this.clone();
            request.form = form;
            Ok(request)
        });
        methods.add_method_mut("set_body", |_, this, body: String| {
            let mut request = this.clone();
            request.body = Some(HTTPClientRequestBodyTypes::String(body));
            if !request.headers.contains_key("Content-Type") {
                request
                    .headers
                    .insert("Content-Type".to_string(), "text/plain".to_string());
            }
            Ok(request)
        });
        methods.add_method_mut("set_bytes", |lua, this, body: mlua::Value| {
            let mut request = this.clone();
            request.body = Some(HTTPClientRequestBodyTypes::Bytes(
                lua.from_value::<Vec<u8>>(body)?,
            ));
            Ok(request)
        });
        methods.add_method_mut("set_json", |lua, this, body: mlua::Value| {
            let mut request = this.clone();
            request.body = Some(HTTPClientRequestBodyTypes::Json(
                lua.from_value::<serde_json::Value>(body)?,
            ));
            if !request.headers.contains_key("Content-Type") {
                request
                    .headers
                    .insert("Content-Type".to_string(), "application/json".to_string());
            }
            Ok(request)
        });
        methods.add_method_mut("set_file", |_, this, file_path: String| {
            let mut request = this.clone();
            request.file = Some(file_path);
            Ok(request)
        });
        methods.add_async_method("execute", |_, this, ()| async move {
            let request = this.request_builder().await;
            match request.send().await {
                Ok(response) => Ok(Self::response_to_http_client_response(response).await),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "HTTP Request did not execute successfully: {e}"
                ))),
            }
        });
        methods.add_async_method(
            "execute_task",
            |_, this, callback: mlua::Function| async move {
                tokio::spawn(async move {
                    let request = this.request_builder().await;
                    match request.send().await {
                        Ok(response) => {
                            if let Err(e) = callback
                                .call::<()>(Self::response_to_http_client_response(response).await)
                            {
                                tracing::error!("Error running a task: {e}");
                            }
                        }
                        Err(e) => tracing::error!("HTTP Request did not execute successfully: {e}"),
                    };
                });
                Ok(())
            },
        );
        // Add the new streaming method
        methods.add_async_method(
            "execute_streaming",
            |_, this, callback: mlua::Function| async move {
                tokio::spawn(async move {
                    // Build and send request
                    let response = match this.request_builder().await.send().await {
                        Ok(r) => r,
                        Err(e) => {
                            tracing::error!("HTTP Request did not execute successfully: {e}");
                            return;
                        }
                    };

                    // Create initial response with headers
                    let headers = response
                        .headers()
                        .iter()
                        .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or_default().to_string()))
                        .collect();

                    let initial_response = HTTPClientResponse {
                        url: response.url().to_string(),
                        status_code: response.status().as_u16(),
                        remote_address: response.remote_addr().map(|i| i.to_string()),
                        body: AstraBuffer::new(bytes::Bytes::new()),
                        headers,
                    };

                    // Initial callback
                    if let Err(e) = callback.call::<()>(initial_response.clone()) {
                        tracing::error!("Error running initial callback: {e}");
                        return;
                    }

                    // Process chunks
                    let mut stream = response.bytes_stream();
                    while let Some(chunk) = stream.next().await {
                        match chunk {
                            Ok(chunk) => {
                                let mut chunk_response = initial_response.clone();
                                chunk_response.body = AstraBuffer::new(chunk);
                                if let Err(e) = callback.call::<()>(chunk_response) {
                                    tracing::error!("Error running chunk callback: {e}");
                                    break;
                                }
                            }
                            Err(e) => {
                                tracing::error!("Error receiving chunk: {e}");
                                break;
                            }
                        }
                    }
                });
                Ok(())
            },
        );
    }
}

#[derive(Debug, Clone)]
pub struct HTTPClientResponse {
    pub url: String,
    pub status_code: u16,
    pub remote_address: Option<String>,
    pub body: AstraBuffer,
    pub headers: HashMap<String, String>,
}

impl UserData for HTTPClientResponse {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("url", |_, this, ()| Ok(this.url.clone()));
        methods.add_method("status_code", |_, this, ()| Ok(this.status_code));
        methods.add_method("remote_address", |_, this, ()| {
            Ok(this.remote_address.clone())
        });
        methods.add_method("body", |_, this, ()| Ok(this.body.clone()));
        methods.add_method("headers", |_, this, ()| Ok(this.headers.clone()));
    }
}
