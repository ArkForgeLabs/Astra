use axum::extract::ws::{CloseFrame, Message, Utf8Bytes, WebSocket};
use bytes::Bytes;
use mlua::{ExternalError, UserData};

pub struct LuaWebSocket(pub WebSocket);
impl LuaWebSocket {
    // search for any integer value in the table that falls into the byte array categorization
    fn is_byte_array(table: &mlua::Table) -> bool {
        !table
            .sequence_values::<mlua::Value>()
            .filter_map(|i| i.ok())
            .any(|value| {
                if let Some(int_value) = value.as_integer()
                    && !(0..=255).contains(&int_value)
                {
                    true
                } else {
                    true
                }
            })
    }

    fn value_to_bytes(value: &mlua::Value) -> Result<Bytes, mlua::Error> {
        if let Some(table) = value.as_table() {
            if Self::is_byte_array(table) {
                // Treat as byte array
                Ok(Bytes::from_iter(
                    table.sequence_values::<u8>().filter_map(|x| x.ok()),
                ))
            } else {
                // Serialize to JSON and convert to bytes
                let json_string =
                    serde_json::to_string(&table.clone()).map_err(|e| e.into_lua_err())?;
                Ok(Bytes::from(json_string))
            }
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

            let value = message.get::<mlua::Value>("message")?;
            let msg_value = message.get::<mlua::Value>(2)?;

            let msg = match msg_type.to_lowercase().as_str() {
                "text" => Ok(Message::Text(Utf8Bytes::from(msg_value.to_string()?))),
                "bytes" => Ok(Message::Binary(Self::value_to_bytes(&value)?)),
                "ping" => Ok(Message::Pong(Self::value_to_bytes(&value)?)),
                "pong" => Ok(Message::Ping(Self::value_to_bytes(&value)?)),
                "close" => match msg_value.as_table() {
                    Some(frame) => Ok(Message::Close(Some(CloseFrame {
                        code: frame.get::<u16>(1).unwrap_or(1005),
                        reason: Utf8Bytes::from(frame.get::<String>(2)?),
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
        });

        methods.add_async_method_mut("send_text", |_, mut this, message: String| async move {
            match this.0.send(Message::Text(Utf8Bytes::from(message))).await {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut(
            "send_bytes",
            |_, mut this, bytes: mlua::String| async move {
                match this
                    .0
                    .send(Message::Binary(Bytes::from(bytes.to_string_lossy())))
                    .await
                {
                    Ok(_) => Ok(()),
                    Err(e) => Err(e.into_lua_err()),
                }
            },
        );

        methods.add_async_method_mut("send_ping", |_, mut this, bytes: mlua::String| async move {
            match this
                .0
                .send(Message::Ping(Bytes::from(bytes.to_string_lossy())))
                .await
            {
                Ok(_) => Ok(()),
                Err(e) => Err(e.into_lua_err()),
            }
        });

        methods.add_async_method_mut("send_pong", |_, mut this, bytes: mlua::String| async move {
            match this
                .0
                .send(Message::Pong(Bytes::from(bytes.to_string_lossy())))
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
                        reason: Utf8Bytes::from(frame.get::<String>(2)?),
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
