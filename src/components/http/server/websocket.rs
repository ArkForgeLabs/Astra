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
            let key = message.get::<String>("type").unwrap();
            let value = message.get::<mlua::Value>("message").unwrap();

            let msg = match key.to_lowercase().as_str() {
                "text" => Ok(Message::Text(Utf8Bytes::from(value.to_string().unwrap()))),
                "bytes" => Ok(Message::Binary(value_to_bytes(&value).unwrap())),
                "ping" => Ok(Message::Pong(value_to_bytes(&value).unwrap())),
                "pong" => Ok(Message::Ping(value_to_bytes(&value).unwrap())),
                "close" => match value.as_table() {
                    Some(frame) => Ok(Message::Close(Some(CloseFrame {
                        code: frame.get::<u16>("code").unwrap(),
                        reason: Utf8Bytes::from(frame.get::<String>("reason").unwrap()),
                    }))),
                    None => Ok(Message::Close(None)),
                },
                _ => Err(mlua::Error::runtime("invalid message type")),
            }
            .unwrap();

            Ok(this.0.send(msg).await.unwrap())
        });

        methods.add_async_method_mut("send_text", |_, mut this, message: String| async move {
            Ok(this
                .0
                .send(Message::Text(Utf8Bytes::from(message)))
                .await
                .unwrap())
        });

        methods.add_async_method_mut(
            "send_binary",
            |_, mut this, bytes: mlua::Value| async move {
                Ok(this
                    .0
                    .send(Message::Binary(value_to_bytes(&bytes).unwrap()))
                    .await
                    .unwrap())
            },
        );

        methods.add_async_method_mut("send_ping", |_, mut this, bytes: mlua::Value| async move {
            Ok(this
                .0
                .send(Message::Ping(value_to_bytes(&bytes).unwrap()))
                .await
                .unwrap())
        });

        methods.add_async_method_mut("send_pong", |_, mut this, bytes: mlua::Value| async move {
            Ok(this
                .0
                .send(Message::Pong(value_to_bytes(&bytes).unwrap()))
                .await
                .unwrap())
        });

        methods.add_async_method_mut(
            "send_close",
            |_, mut this, close_frame: Option<mlua::Table>| async move {
                let close_frame = match close_frame {
                    Some(frame) => Some(CloseFrame {
                        code: frame.get::<u16>("code").unwrap(),
                        reason: Utf8Bytes::from(frame.get::<String>("reason").unwrap()),
                    }),
                    None => None,
                };

                Ok(this.0.send(Message::Close(close_frame)).await.unwrap())
            },
        );
    }
}

fn value_to_bytes(value: &mlua::Value) -> Result<Bytes, mlua::Error> {
    if value.is_table() {
        Ok(Bytes::from_iter(
            value
                .as_table()
                .unwrap()
                .sequence_values::<u8>()
                .map(|x| x.expect("expected bytes")),
        ))
    } else if value.is_string() {
        Ok(Bytes::from(
            value
                .to_string()
                .expect("cannot convert given string to bytes"),
        ))
    } else {
        Err(mlua::Error::runtime("type cannot be accepted as bytes"))
    }
}
