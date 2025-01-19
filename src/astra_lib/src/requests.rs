use crate::common::BodyLua;
use axum::{
    body::Body,
    extract::{FromRequest, Multipart, State},
    http::{request::Parts, Request},
};
use mlua::UserData;
use std::collections::HashMap;
use tokio::io::AsyncWriteExt;

// TODO: configure body size

#[derive(Debug)]
pub struct RequestLua {
    pub parts: Parts,
    pub bytes: Option<bytes::Bytes>,
}
impl RequestLua {
    pub async fn new(request: Request<Body>) -> Self {
        let (parts, body) = request.into_parts();
        let bytes = match axum::body::to_bytes(body, usize::MAX).await {
            Ok(bytes) => Some(bytes),

            Err(e) => {
                eprintln!("Error extracting body from request: {e:#?}");

                None
            }
        };

        Self { parts, bytes }
    }
}
unsafe impl Send for RequestLua {}
unsafe impl Sync for RequestLua {}

impl UserData for RequestLua {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("method", |_, this, ()| Ok(this.parts.method.to_string()));
        methods.add_method("uri", |_, this, ()| Ok(this.parts.uri.to_string()));
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
impl LuaMultipart {
    async fn save_file(&mut self, file_path: String) -> mlua::Result<()> {
        let mut file = tokio::fs::File::create(file_path).await?;

        while let Ok(Some(field)) = self.multipart.next_field().await {
            if let Ok(bytes) = field.bytes().await {
                if let Err(err) = file.write(&bytes).await {
                    return Err(mlua::Error::runtime(err));
                }
            }
        }

        Ok(())
    }
}
impl UserData for LuaMultipart {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method_mut("save_file", |_, mut this, file_path: String| async move {
            this.save_file(file_path).await
        });
    }
}
