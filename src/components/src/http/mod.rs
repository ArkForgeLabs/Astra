mod configs;
mod cookie;
mod requests;
mod responses;
mod routes;

pub async fn register_run_function(lua: &mlua::Lua) -> mlua::Result<()> {
    // Register function for running the server
    lua.globals().set(
        "astra_internal__start_server",
        lua.create_async_function(|lua, ()| async move {
            // default address
            let mut listener_address = "127.0.0.1:8080".to_string();

            if let Ok(settings) = lua.globals().get::<mlua::Table>("Astra") {
                let mut hostname = "127.0.0.1".to_string();
                if let Ok(new_hostname) = settings.get::<String>("hostname") {
                    hostname = new_hostname;
                }

                let mut port = 8080;
                if let Ok(new_port) = settings.get::<u16>("port") {
                    port = new_port;
                }

                listener_address = format!("{hostname}:{port}");
            }

            #[allow(clippy::unwrap_used)]
            let listener = tokio::net::TcpListener::bind(listener_address.clone())
                .await
                .unwrap();

            println!("🚀 Listening at: http://{listener_address}");

            #[allow(clippy::unwrap_used)]
            axum::serve(listener, crate::http::routes::load_routes(&lua))
                .await
                .unwrap();

            Ok(())
        })?,
    )?;

    Ok(())
}
