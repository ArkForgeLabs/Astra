use crate::components::BodyLua;
use mlua::{LuaSerdeExt, UserData};
use reqwest::{Client, RequestBuilder};
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct HTTPClientRequest {
    pub url: String,
    pub method: String,
    pub headers: HashMap<String, String>,
    pub body: Option<String>,
    pub body_json: Option<serde_json::Value>,
    pub body_file: Option<String>,
    pub form: HashMap<String, String>,
}
impl HTTPClientRequest {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let function = lua.create_function(|_, url: String| {
            Ok(Self {
                url,
                method: "GET".to_string(),
                headers: HashMap::new(),
                body: None,
                body_json: None,
                body_file: None,
                form: HashMap::new(),
            })
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

        client = if let Some(body) = &self.body {
            client.body(body.clone())
        } else if let Some(body) = &self.body_json {
            client.json(&body)
        } else if let Some(body) = &self.body_file {
            let path = std::path::PathBuf::from(body);
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
            BodyLua::new(bytes)
        } else {
            BodyLua::new(bytes::Bytes::new())
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
            request.body = Some(body);

            Ok(request)
        });

        methods.add_method_mut("set_json", |lua, this, body: mlua::Value| {
            let mut request = this.clone();
            request.body_json = lua.from_value::<serde_json::Value>(body).ok();

            Ok(request)
        });

        methods.add_method_mut("set_file", |_, this, file_path: String| {
            let mut request = this.clone();
            request.body_file = Some(file_path);

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
                                println!("Error running a task: {e}");
                            }
                        }
                        Err(e) => eprintln!("HTTP Request did not execute successfully: {e}"),
                    };
                });

                Ok(())
            },
        );
    }
}

pub struct HTTPClientResponse {
    pub url: String,
    pub status_code: u16,
    pub remote_address: Option<String>,
    pub body: BodyLua,
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
