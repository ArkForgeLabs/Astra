use axum::extract::ws::{CloseFrame, Message, Utf8Bytes, WebSocket};
use bytes::Bytes;
use mlua::{ExternalError, UserData};

pub struct LuaWebSocket(pub WebSocket);
impl LuaWebSocket {
    fn value_to_bytes(value: &mlua::Value) -> Result<Bytes, mlua::Error> {
        if let Some(table) = value.as_table() {
            Ok(Bytes::from_iter(
                table.sequence_values::<u8>().filter_map(|x| x.ok()),
            ))
        } else if value.is_string() {
            Ok(Bytes::from(value.to_string()?))
        } else {
            Err(mlua::Error::runtime("type cannot be accepted as bytes"))
        }
    }
}
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
                                recv.set("type", "Bytes")?;
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

        methods.add_async_method_mut(
            "send",
            |_, mut this, (message_type, message): (String, mlua::Value)| async move {
                let msg = match message_type.to_lowercase().as_str() {
                    "text" => Ok(Message::Text(Utf8Bytes::from(
                        if let Some(table_message) = message.as_table() {
                            serde_json::to_string(&table_message.clone())
                                .map_err(|e| e.into_lua_err())?
                        } else if let Some(string_message) = message.as_string() {
                            string_message.to_string_lossy()
                        } else {
                            message.to_string()?
                        },
                    ))),
                    "bytes" => Ok(Message::Binary(Self::value_to_bytes(&message)?)),
                    "ping" => Ok(Message::Pong(Self::value_to_bytes(&message)?)),
                    "pong" => Ok(Message::Ping(Self::value_to_bytes(&message)?)),
                    "close" => match message.as_table() {
                        Some(frame) => Ok(Message::Close(Some(CloseFrame {
                            code: frame.get::<u16>(1).unwrap_or(1005),
                            reason: Utf8Bytes::from(
                                frame.get::<String>(2).unwrap_or("".to_string()),
                            ),
                        }))),
                        None => Ok(Message::Close(None)),
                    },
                    _ => Err(mlua::Error::runtime("invalid message type")),
                };

                match msg {
                    Ok(msg) => match this.0.send(msg).await {
                        Ok(_) => Ok(()),
                        Err(e) => Err(e.into_lua_err()),
                    },
                    Err(e) => Err(e.into_lua_err()),
                }
            },
        );

        methods.add_async_method_mut("send_text", |_, mut this, message: String| async move {
            match this.0.send(Message::Text(Utf8Bytes::from(message))).await {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut("send_bytes", |_, mut this, bytes: mlua::Value| async move {
            match this
                .0
                .send(Message::Binary(Self::value_to_bytes(&bytes)?))
                .await
            {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut("send_ping", |_, mut this, bytes: mlua::Value| async move {
            match this
                .0
                .send(Message::Ping(Self::value_to_bytes(&bytes)?))
                .await
            {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut("send_pong", |_, mut this, bytes: mlua::Value| async move {
            match this
                .0
                .send(Message::Pong(Self::value_to_bytes(&bytes)?))
                .await
            {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut(
            "send_close",
            |_, mut this, close_frame: Option<mlua::Table>| async move {
                let close_frame: Message = match close_frame {
                    Some(frame) => Message::Close(Some(CloseFrame {
                        code: frame.get::<u16>(1).unwrap_or(1005),
                        reason: Utf8Bytes::from(frame.get::<String>(2).unwrap_or("".to_string())),
                    })),
                    None => Message::Close(None),
                };

                match this.0.send(close_frame).await {
                    Ok(_) => Ok(()),
                    Err(e) => Err(e.into_lua_err()),
                }
            },
        );
    }
}
