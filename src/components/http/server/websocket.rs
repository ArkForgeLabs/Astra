use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket};
use bytes::Bytes;
use mlua::{FromLua, UserData};
use tokio::sync::Mutex;

#[derive(Clone, FromLua)]
pub struct LuaCloseFrame {
    pub code: u16,
    pub reason: String,
}

impl UserData for LuaCloseFrame {}

#[derive(Clone, FromLua)]
enum LuaMessage {
    Text(String),
    Binary(Bytes),
    Ping(Bytes),
    Pong(Bytes),
    Close(Option<LuaCloseFrame>),
}

impl UserData for LuaMessage {}

#[derive(Clone, FromLua)]
pub struct LuaWebSocket {
    socket: WebSocket,
}

impl LuaWebSocket {
    pub fn new(socket: WebSocket) -> Self {
        Self { socket }
    }
}

impl UserData for LuaWebSocket {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method_mut("recv", |_, mut this, ()| async move {
            match this.socket.recv().await {
                Some(msg) => match msg {
                    Ok(msg) => match msg {
                        Message::Text(utf8_bytes) => Ok(LuaMessage::Text(utf8_bytes.to_string())),
                        Message::Binary(bytes) => Ok(LuaMessage::Binary(bytes)),
                        Message::Ping(bytes) => Ok(LuaMessage::Ping(bytes)),
                        Message::Pong(bytes) => Ok(LuaMessage::Ping(bytes)),
                        Message::Close(close_frame) => match close_frame {
                            Some(frame) => Ok(LuaMessage::Close(Some(LuaCloseFrame {
                                code: frame.code,
                                reason: frame.reason.to_string(),
                            }))),
                            None => Ok(LuaMessage::Close(None)),
                        },
                    },
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "failed to receive a frame: {}",
                        e
                    ))),
                },
                None => Err(mlua::Error::runtime("No message received!")),
            }
        });
    }
}
