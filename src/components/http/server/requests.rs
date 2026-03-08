use super::cookie::AstraHTTPCookie;
use crate::components::AstraBuffer;
use axum::{
    body::Body,
    extract::{ConnectInfo, FromRequest, FromRequestParts, Multipart, RawPathParams},
    http::{Request, request::Parts},
};
use axum_extra::extract::{CookieJar, cookie::Cookie};
use mlua::{ExternalError, LuaSerdeExt, UserData};
use std::collections::HashMap;
use tokio::io::AsyncWriteExt;

#[derive(Debug)]
pub struct RequestLua {
    pub parts: Parts,
    pub bytes: Option<bytes::Bytes>,
    pub cookie_jar: CookieJar,
}
impl RequestLua {
    pub async fn new(request: Request<Body>) -> Self {
        let (mut parts, body) = request.into_parts();
        let bytes = match axum::body::to_bytes(body, usize::MAX).await {
            Ok(bytes) => Some(bytes),

            Err(e) => {
                eprintln!("Error extracting body from request: {e:#?}");

                None
            }
        };

        let cookie_jar = match CookieJar::from_request_parts(&mut parts, &()).await {
            Ok(cookie) => cookie,
            Err(e) => {
                eprintln!("Could not get the cookie: {e}");
                CookieJar::new()
            }
        };

        Self {
            parts,
            bytes,
            cookie_jar,
        }
    }
}
unsafe impl Send for RequestLua {}
unsafe impl Sync for RequestLua {}

impl UserData for RequestLua {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("method", |_, this, ()| Ok(this.parts.method.to_string()));
        methods.add_method("uri", |_, this, ()| Ok(this.parts.uri.to_string()));
        methods.add_method("queries", |lua, this, ()| {
            match axum::extract::Query::<serde_json::Value>::try_from_uri(&this.parts.uri) {
                Ok(queries) => lua.to_value(&queries.clone().take()),
                Err(e) => Err(e.into_lua_err()),
            }
        });
        methods.add_async_method("params", |lua, this, ()| async move {
            let raw_path_params = RawPathParams::from_request_parts(&mut this.parts.clone(), &())
                .await
                .map_err(|e| e.into_lua_err())?;

            let params_table = lua.create_table()?;

            for (key, value) in &raw_path_params {
                if let Ok(value) = value.parse::<i32>() {
                    params_table.set(key, value)?;
                } else if let Ok(value) = value.parse::<f32>() {
                    params_table.set(key, value)?;
                } else {
                    params_table.set(key, value)?;
                }
            }

            Ok(params_table)
        });
        methods.add_async_method("ip_address", |_, this, ()| async move {
            let connect_info = ConnectInfo::<std::net::SocketAddr>::from_request_parts(
                &mut this.parts.clone(),
                &(),
            )
            .await
            .map_err(|e| e.into_lua_err())?;

            Ok(AstraSocketAddr(connect_info.ip()))
        });
        methods.add_async_method("form", |lua, this, ()| async move {
            match &this.bytes {
                Some(bytes) => {
                    let request =
                        Request::from_parts(this.parts.clone(), Body::from(bytes.clone()));

                    match axum::Form::<Vec<Vec<serde_value::Value>>>::from_request(request, &())
                        .await
                    {
                        Ok(form) => {
                            let key_value = lua.create_table()?;

                            for i in form.0 {
                                let key = i.first().and_then(|key| {
                                    key.clone().deserialize_into::<'_, String>().ok()
                                });
                                if key.is_none() {
                                    continue;
                                }

                                if i.len() >= 2 {
                                    let value = i.get(1);
                                    if value.is_none() {
                                        continue;
                                    }

                                    key_value.set(key.clone(), lua.to_value(&value)?)?;
                                } else {
                                    key_value.raw_push(key)?;
                                }
                            }

                            Ok(key_value)
                        }
                        Err(e) => Err(e.into_lua_err()),
                    }
                }

                None => Err(mlua::Error::runtime("No bytes found")),
            }
        });
        methods.add_async_method("multipart", |_, this, ()| async move {
            match &this.bytes {
                Some(bytes) => {
                    let multipart_request =
                        Request::from_parts(this.parts.clone(), Body::from(bytes.clone()));

                    match Multipart::from_request(multipart_request, &()).await {
                        Ok(multipart) => AstraMultipart::new(multipart).await,
                        Err(e) => Err(e.into_lua_err()),
                    }
                }

                None => Err(mlua::Error::runtime("No bytes found")),
            }
        });
        methods.add_method("headers", |_, this, ()| {
            Ok(this
                .parts
                .headers
                .iter()
                .map(|(key, value)| (key.to_string(), value.to_str().unwrap_or("").to_string()))
                .collect::<HashMap<String, String>>())
        });
        methods.add_method("get_cookie", |_, this, name: String| {
            Ok(this
                .cookie_jar
                .get(name.as_str())
                .map(|cookie| AstraHTTPCookie(cookie.clone())))
        });
        methods.add_method("new_cookie", |_, _, (name, value): (String, String)| {
            Ok(AstraHTTPCookie(Cookie::new(name, value)))
        });
        // ! Create new cookie
        methods.add_method("body", |_, this, ()| match this.bytes.clone() {
            Some(bytes) => Ok(AstraBuffer::new(bytes)),
            None => Ok(AstraBuffer::new(bytes::Bytes::new())),
        });
    }
}

#[derive(Debug, Clone)]
pub struct AstraSocketAddr(std::net::IpAddr);
impl UserData for AstraSocketAddr {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("address", |_, this, ()| Ok(this.0.to_string()));
        methods.add_method("to_canonical", |_, this, ()| {
            Ok(AstraSocketAddr(this.0.to_canonical()))
        });
        methods.add_method("is_ipv4", |_, this, ()| Ok(this.0.is_ipv4()));
        methods.add_method("is_ipv6", |_, this, ()| Ok(this.0.is_ipv6()));
        methods.add_method("is_loopback", |_, this, ()| Ok(this.0.is_loopback()));
        methods.add_method("is_multicast", |_, this, ()| Ok(this.0.is_multicast()));
    }
}

#[derive(Debug, Clone)]
pub struct AstraMultipartField {
    pub name: String,
    pub data: bytes::Bytes,
    pub file_name: Option<String>,
    pub content_type: Option<String>,
    pub headers: HashMap<String, String>,
}
impl UserData for AstraMultipartField {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("name", |_, this, ()| Ok(this.name.clone()));
        methods.add_method("file_name", |_, this, ()| Ok(this.file_name.clone()));
        methods.add_method("content_type", |_, this, ()| Ok(this.content_type.clone()));
        methods.add_method("headers", |_, this, ()| Ok(this.headers.clone()));
        methods.add_method("text", |_, this, ()| {
            String::from_utf8(this.data.to_vec().clone()).map_err(|e| e.into_lua_err())
        });
        methods.add_method("bytes", |_, this, ()| Ok(this.data.to_vec()));
    }
}

#[derive(Debug)]
pub struct AstraMultipart {
    fields: Vec<AstraMultipartField>,
}
impl AstraMultipart {
    async fn new(mut multipart: Multipart) -> mlua::Result<Self> {
        let mut fields = Vec::new();

        while let Ok(Some(field)) = multipart.next_field().await {
            let name = field.name().unwrap_or("").to_string();
            let filename = field.file_name().map(|s| s.to_string());
            let content_type = field.content_type().map(|s| s.to_string());

            let mut headers = HashMap::new();
            for (key, value) in field.headers() {
                headers.insert(
                    key.as_str().to_string(),
                    value.to_str().unwrap_or("").to_string(),
                );
            }

            // Read field data
            let bytes = field.bytes().await.map_err(|e| e.into_lua_err())?;

            fields.push(AstraMultipartField {
                name,
                data: bytes,
                file_name: filename,
                content_type,
                headers,
            });
        }

        Ok(Self { fields })
    }
}
impl UserData for AstraMultipart {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("fields", |lua, this, ()| {
            let fields_table = lua.create_table()?;
            for (i, field) in this.fields.iter().enumerate() {
                fields_table.set(i + 1, field.clone())?;
            }
            Ok(fields_table)
        });

        methods.add_method("get_field", |_, this, name: String| {
            for field in &this.fields {
                if field.name == name {
                    return Ok(Some(field.clone()));
                }
            }
            Ok(None)
        });

        methods.add_async_method_mut("file_name", |lua, this, _: ()| async move {
            let mut file_name = Ok(mlua::Value::Nil);

            for field in &this.fields {
                if let Some(filename) = &field.file_name {
                    file_name = lua.to_value(&filename);
                    break;
                }
            }

            file_name
        });

        methods.add_async_method_mut(
            "save_file",
            |_, this, file_path: Option<String>| async move {
                let mut file_path = if let Some(file_path) = file_path {
                    Some(tokio::fs::File::create(file_path).await?)
                } else {
                    None
                };

                for field in &this.fields {
                    if file_path.is_none()
                        && let Some(filename) = &field.file_name
                    {
                        file_path = Some(tokio::fs::File::create(filename).await?);
                    }
                    if let Some(ref mut file) = file_path
                        && let bytes = &field.data
                        && let Err(err) = file.write(bytes).await
                    {
                        return Err(err.into_lua_err());
                    }
                }

                Ok(())
            },
        );
    }
}
