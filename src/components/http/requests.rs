use crate::components::BodyLua;
use axum::{
    body::Body,
    extract::{FromRequest, FromRequestParts, Multipart, State},
    http::{Request, request::Parts},
};
use axum_extra::extract::CookieJar;
use mlua::{LuaSerdeExt, UserData};
use std::collections::HashMap;
use tokio::io::AsyncWriteExt;

// TODO: configure body size

#[derive(Debug)]
pub struct RequestLua {
    pub parts: Parts,
    pub bytes: Option<bytes::Bytes>,
    pub cookie: CookieJar,
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

        let cookie = match CookieJar::from_request_parts(&mut parts, &()).await {
            Ok(cookie) => cookie,
            Err(e) => {
                eprintln!("Could not get the cookie: {e}");
                CookieJar::new()
            }
        };

        Self {
            parts,
            bytes,
            cookie,
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
                Err(e) => Err(mlua::Error::runtime(format!(
                    "Could not parse queries: {e:?}"
                ))),
            }
        });
        methods.add_async_method("multipart", |_, this, ()| async move {
            match this.bytes.clone() {
                Some(bytes) => {
                    let state = State::<i32>::default();
                    let multipart_request =
                        Request::from_parts(this.parts.clone(), Body::from(bytes.clone()));

                    match Multipart::from_request(multipart_request, &state).await {
                        Ok(multipart) => Ok(LuaMultipart { multipart }),
                        Err(e) => Err(mlua::Error::runtime(e.body_text())),
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
        methods.add_async_method("get_cookie", |_, this, name: String| async move {
            // ! Move this to a dedicated Cookie Userdata
            match this
                .cookie
                .get(name.as_str())
                .and_then(|cookie| cookie.value_raw())
            {
                Some(value) => Ok(Some(value)),
                None => Ok(None),
            }
        });
        methods.add_async_method("body", |_, this, ()| async move {
            match this.bytes.clone() {
                Some(bytes) => Ok(BodyLua::new(bytes)),

                None => Ok(BodyLua::new(bytes::Bytes::new())),
            }
        });
    }
}

#[derive(Debug)]
pub struct LuaMultipart {
    pub multipart: Multipart,
}
impl UserData for LuaMultipart {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method_mut(
            "save_file",
            |_, mut this, file_path: Option<String>| async move {
                let mut file_path = if let Some(file_path) = file_path {
                    Some(tokio::fs::File::create(file_path).await?)
                } else {
                    None
                };

                while let Ok(Some(field)) = this.multipart.next_field().await {
                    if file_path.is_none() {
                        if let Some(filename) = field.file_name() {
                            file_path = Some(tokio::fs::File::create(filename).await?);
                        }
                    }

                    if let Some(ref mut file) = file_path {
                        if let Ok(bytes) = field.bytes().await {
                            if let Err(err) = file.write(&bytes).await {
                                return Err(mlua::Error::runtime(err));
                            }
                        }
                    }
                }

                Ok(())
            },
        );
    }
}
