use std::sync::{Arc, Mutex};

use axum::extract::ws::WebSocket;
use mlua::{FromLua, UserData};

#[derive(Clone, FromLua)]
pub struct AstraWebSocket {
    socket: Arc<Mutex<WebSocket>>,
}

impl AstraWebSocket {
    pub fn new(socket: Arc<Mutex<WebSocket>>) -> Self {
        Self { socket }
    }
}

impl UserData for AstraWebSocket {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method("recv", |_, this, ()| async move {
            let socket = this.socket.lock().unwrap();
            while let Some(msg) = socket.recv().await {
                let msg = if let Ok(msg) = msg {
                    msg
                } else {
                    return;
                };

                if socket.send(msg).await.is_err() {
                    return;
                }
            }

            Ok(())
        });
    }
}
