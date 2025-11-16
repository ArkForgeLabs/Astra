use bytes::Bytes;
use futures::{SinkExt, TryStreamExt};
use mlua::{ExternalError, UserData};
use reqwest_websocket::{CloseCode, Message, WebSocket};

pub struct AstraWebSocket(pub WebSocket);
impl AstraWebSocket {
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
impl UserData for AstraWebSocket {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_async_method_mut("recv", |lua, mut this, ()| async move {
            match this.0.try_next().await {
                Ok(msg) => match msg {
                    Some(msg) => {
                        let recv = lua.create_table()?;
                        match msg {
                            Message::Text(utf8_bytes) => {
                                recv.set("type", "text")?;
                                recv.set("value", utf8_bytes.to_string())?;
                            }
                            Message::Binary(bytes) => {
                                recv.set("type", "bytes")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Ping(bytes) => {
                                recv.set("type", "ping")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Pong(bytes) => {
                                recv.set("type", "pong")?;
                                recv.set("value", bytes.to_vec())?;
                            }
                            Message::Close { code, reason } => {
                                recv.set("type", "close")?;
                                let close_frame = lua.create_table()?;
                                close_frame.set("code", code.to_string())?;
                                close_frame.set("reason", reason)?;
                                recv.set("value", close_frame)?;
                            }
                        };

                        Ok(recv)
                    }
                    None => Err(mlua::Error::runtime("failed to receive a frame")),
                },
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut(
            "send",
            |_, mut this, (message_type, message): (String, mlua::Value)| async move {
                let msg = match message_type.to_lowercase().as_str() {
                    "text" => Ok(Message::Text(
                        if let Some(table_message) = message.as_table() {
                            serde_json::to_string(&table_message.clone())
                                .map_err(|e| e.into_lua_err())?
                        } else if let Some(string_message) = message.as_string() {
                            string_message.to_string_lossy()
                        } else {
                            message.to_string()?
                        },
                    )),
                    "bytes" => Ok(Message::Binary(Self::value_to_bytes(&message)?)),
                    "ping" => Ok(Message::Pong(Self::value_to_bytes(&message)?)),
                    "pong" => Ok(Message::Ping(Self::value_to_bytes(&message)?)),
                    "close" => match message {
                        mlua::Value::Integer(close_code) => Ok(Message::Close {
                            code: CloseCode::from(u16::try_from(close_code).unwrap_or(1006)),
                            reason: String::new(),
                        }),
                        mlua::Value::Table(table) => Ok(Message::Close {
                            code: CloseCode::from(table.get::<u16>(1).unwrap_or(1005)),
                            reason: table.get::<String>(2).unwrap_or("".to_string()),
                        }),
                        _ => Ok(Message::Close {
                            code: CloseCode::Normal,
                            reason: String::new(),
                        }),
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
            match this.0.send(Message::Text(message)).await {
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
            |_, mut this, close_frame: Option<mlua::Value>| async move {
                let close_frame: Message = match close_frame {
                    Some(frame) => match frame {
                        mlua::Value::Integer(close_code) => Message::Close {
                            code: CloseCode::from(u16::try_from(close_code).unwrap_or(1006)),
                            reason: String::new(),
                        },
                        mlua::Value::Table(table) => Message::Close {
                            code: CloseCode::from(table.get::<u16>(1).unwrap_or(1005)),
                            reason: table.get::<String>(2).unwrap_or("".to_string()),
                        },
                        _ => Message::Close {
                            code: CloseCode::Normal,
                            reason: String::new(),
                        },
                    },
                    None => Message::Close {
                        code: CloseCode::Normal,
                        reason: String::new(),
                    },
                };

                match this.0.send(close_frame).await {
                    Ok(_) => Ok(()),
                    Err(e) => Err(e.into_lua_err()),
                }
            },
        );
    }
}
