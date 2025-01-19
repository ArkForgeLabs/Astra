#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

// TODO: support different lua versions

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod common;
mod requests;
mod responses;
mod routes;
mod utils;

#[derive(Debug, Clone, Default)]
pub struct Astra {
    pub routes: Vec<routes::Route>,
}
impl Astra {
    pub fn run(&self) {
        #[allow(clippy::expect_used)]
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("Could not start the async runtime")
            .block_on(async {
                tracing_subscriber::registry()
                    .with(
                        tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(
                            |_| {
                                format!("{}=debug,tower_http=debug", env!("CARGO_CRATE_NAME"))
                                    .into()
                            },
                        ),
                    )
                    .with(tracing_subscriber::fmt::layer())
                    .init();

                common::init().await;

                let mut listener_address = "127.0.0.1:8080".to_string();

                if let Ok(settings) = common::LUA.globals().get::<mlua::Table>("Astra") {
                    if let Ok(hostname) = settings.get::<String>("hostname") {
                        if let Ok(port) = settings.get::<u16>("port") {
                            listener_address = format!("{hostname}:{port}");
                        }
                    }
                }

                #[allow(clippy::unwrap_used)]
                let listener = tokio::net::TcpListener::bind(listener_address.clone())
                    .await
                    .unwrap();

                println!("🚀 Listening at: http://{listener_address}");

                #[allow(clippy::unwrap_used)]
                axum::serve(listener, routes::load_routes()).await.unwrap();
            })
    }
}
