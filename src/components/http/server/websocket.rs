use axum::extract::ws::{CloseFrame, Message, Utf8Bytes, WebSocket};
use bytes::Bytes;
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

        methods.add_async_method_mut("send", |_, mut this, message: mlua::Table| async move {
            let msg_type = match message.get::<String>(1) {
                Ok(val) => val,
                Err(e) => {
                    return Err(mlua::Error::runtime(format!(
                        "message type is not a string: {e}"
                    )));
                }
            };

            let msg_value = match message.get::<mlua::Value>(2) {
                Ok(val) => val,
                Err(e) => {
                    return Err(mlua::Error::runtime(format!(
                        "message is not a valid lua value: {e}"
                    )));
                }
            };

            let msg = match msg_type.to_lowercase().as_str() {
                "text" => match msg_value.to_string() {
                    Ok(val) => Ok(Message::Text(Utf8Bytes::from(val))),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "could not convert the value to a string: {e}"
                    ))),
                },
                "bytes" => match msg_value.to_string() {
                    Ok(val) => Ok(Message::Binary(Bytes::from(val))),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "could not convert the value to a string: {e}"
                    ))),
                },
                "ping" => match msg_value.to_string() {
                    Ok(val) => Ok(Message::Ping(Bytes::from(val))),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "could not convert the value to a string: {e}"
                    ))),
                },
                "pong" => match msg_value.to_string() {
                    Ok(val) => Ok(Message::Ping(Bytes::from(val))),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "could not convert the value to a string: {e}"
                    ))),
                },
                "close" => match msg_value.as_table() {
                    Some(frame) => Ok(Message::Close(Some(CloseFrame {
                        code: match frame.get::<u16>(1) {
                            Ok(code) => code,
                            Err(_) => 1005,
                        },
                        reason: match frame.get::<String>(2) {
                            Ok(reason) => Utf8Bytes::from(reason),
                            Err(_) => Utf8Bytes::from_static(""),
                        },
                    }))),
                    None => Ok(Message::Close(None)),
                },
                _ => Err(mlua::Error::runtime("invalid message type")),
            };

            match msg {
                Ok(msg) => match this.0.send(msg).await {
                    Ok(passed) => Ok(passed),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "message could not be sent: {e}"
                    ))),
                },
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        });

        methods.add_async_method_mut("send_text", |_, mut this, message: String| async move {
            match this.0.send(Message::Text(Utf8Bytes::from(message))).await {
                Ok(passed) => Ok(passed),
                Err(e) => Err(mlua::Error::runtime(format!(
                    "message could not be sent: {e}"
                ))),
            }
        });

        methods.add_async_method_mut(
            "send_binary",
            |_, mut this, bytes: mlua::String| async move {
                match this
                    .0
                    .send(Message::Binary(Bytes::from(bytes.to_string_lossy())))
                    .await
                {
                    Ok(passed) => Ok(passed),
                    Err(e) => Err(mlua::Error::runtime(e)),
                }
            },
        );

        methods.add_async_method_mut("send_ping", |_, mut this, bytes: mlua::String| async move {
            match this
                .0
                .send(Message::Ping(Bytes::from(bytes.to_string_lossy())))
                .await
            {
                Ok(passed) => Ok(passed),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        });

        methods.add_async_method_mut("send_pong", |_, mut this, bytes: mlua::String| async move {
            match this
                .0
                .send(Message::Pong(Bytes::from(bytes.to_string_lossy())))
                .await
            {
                Ok(passed) => Ok(passed),
                Err(e) => Err(mlua::Error::runtime(e)),
            }
        });

        methods.add_async_method_mut(
            "send_close",
            |_, mut this, close_frame: Option<mlua::Table>| async move {
                let close_frame: Message = match close_frame {
                    Some(frame) => Message::Close(Some(CloseFrame {
                        code: match frame.get::<u16>(1) {
                            Ok(code) => code,
                            Err(_) => 1005,
                        },
                        reason: match frame.get::<String>(2) {
                            Ok(reason) => Utf8Bytes::from(reason),
                            Err(_) => Utf8Bytes::from_static(""),
                        },
                    })),
                    None => Message::Close(None),
                };

                match this.0.send(close_frame).await {
                    Ok(passed) => Ok(passed),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "message could not be sent: {e}"
                    ))),
                }
            },
        );
    }
}
