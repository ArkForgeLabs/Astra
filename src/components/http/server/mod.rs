mod configs;
mod cookie;
mod requests;
mod responses;
mod routes;
mod websocket;

pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
    // Register function for running the server
    lua.globals().set(
        "astra_internal__start_server",
        lua.create_async_function(|_, server: mlua::Table| async move {
            let mut hostname = "127.0.0.1".to_string();
            if let Ok(new_hostname) = server.get("hostname") {
                hostname = new_hostname;
            }

            let mut port = 8080;
            if let Ok(new_port) = server.get("port") {
                port = new_port;
            }

            let listener_address: String = format!("{hostname}:{port}");

            #[allow(clippy::expect_used)]
            let listener = tokio::net::TcpListener::bind(listener_address.clone())
                .await
                .expect("Could not create a TCP listener");

            println!("🚀 Listening at: http://{listener_address}");

            #[allow(clippy::expect_used)]
            axum::serve(
                listener,
                crate::components::http::server::routes::load_routes(server).into_make_service(),
            )
            .await
            .expect("Could not start the HTTP server");

            Ok(())
        })?,
    )?;

    Ok(())
}
