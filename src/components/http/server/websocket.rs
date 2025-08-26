use axum::extract::ws::{Message, WebSocket};
use mlua::UserData;

pub struct LuaWebSocket(pub WebSocket);
impl UserData for LuaWebSocket {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method_mut("recv", |lua, mut this, ()| async move {
            match this.0.recv().await {
                Some(msg) => match msg {
                    Ok(msg) => {
                        let recv = lua.create_table()?;
                        match msg {
                            Message::Text(utf8_bytes) => {
                                recv.set("type", "Text")?;
                                recv.set("value", utf8_bytes.to_string())?;
                            }
                            Message::Binary(bytes) => {
                                recv.set("type", "Binary")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Ping(bytes) => {
                                recv.set("type", "Ping")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Pong(bytes) => {
                                recv.set("type", "Pong")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Close(close_frame) => match close_frame {
                                Some(frame) => {
                                    recv.set("type", "Close")?;
                                    let close_frame = lua.create_table()?;
                                    close_frame.set("code", frame.code)?;
                                    close_frame.set("reason", frame.reason.to_string())?;
                                    recv.set("value", close_frame)?;
                                }
                                None => {
                                    recv.set("type", "Close")?;
                                    recv.set("value", mlua::Value::Nil)?;
                                }
                            },
                        };

                        Ok(recv)
                    }
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "failed to receive a frame: {e}",
                    ))),
                },
                None => Err(mlua::Error::runtime("No message received!")),
            }
        });
    }
}
