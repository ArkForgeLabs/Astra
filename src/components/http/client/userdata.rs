use crate::components::AstraBuffer;
use futures::StreamExt;
use mlua::{ExternalError, UserData};
use reqwest_websocket::Upgrade;
use std::collections::HashMap;

impl UserData for super::HTTPClientRequest {
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
        methods.add_method_mut("set_form", |_, this, form: HashMap<String, String>| {
            let mut request = this.clone();
            request.form = form;
            Ok(request)
        });
        methods.add_method_mut("set_body", |lua, this, body: mlua::Value| {
            let mut request = this.clone();
            request.body = Self::body_parser(lua, &mut request.headers, body)?;
            if !request.headers.contains_key("Content-Type") {
                request
                    .headers
                    .insert("Content-Type".to_string(), "text/plain".to_string());
            }
            Ok(request)
        });
        methods.add_method_mut("set_file", |_, this, file_path: String| {
            let mut request = this.clone();
            request.file = Some(file_path);
            Ok(request)
        });
        methods.add_async_method("execute", |_, this, ()| async move {
            let request = this.request_builder().await?;
            match request.send().await {
                Ok(response) => Ok(Self::response_to_http_client_response(response).await),
                Err(e) => Err(e.into_lua_err()),
            }
        });
        methods.add_async_method(
            "execute_streaming",
            |_, this, callback: mlua::Function| async move {
                tokio::spawn(async move {
                    let request = this.request_builder().await?;
                    let response = match request.send().await {
                        Ok(response) => response,
                        Err(e) => {
                            tracing::error!("HTTP Request did not execute successfully: {e}");
                            return mlua::Result::Ok(());
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
                        return Ok(());
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

                    Ok(())
                });
                Ok(())
            },
        );
        methods.add_async_method(
            "execute_websocket",
            |lua, this, callback: mlua::Function| async move {
                tokio::spawn(async move {
                    let request = this.request_builder().await?;
                    let request = request.upgrade();
                    if let Ok(response) = request.send().await
                        && let Ok(response) = response.into_websocket().await
                    {
                        if let Err(e) = callback
                            .call_async::<()>(lua.create_userdata(super::AstraWebSocket(response)))
                            .await
                        {
                            tracing::error!("Error running a task: {e}")
                        }
                    } else {
                        tracing::error!("Websocket request did not execute successfully");
                    };

                    mlua::Result::Ok(())
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
