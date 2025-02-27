#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod fileio;
mod requests;
mod responses;
mod routes;
mod startup;

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("{}=debug,tower_http=debug", env!("CARGO_CRATE_NAME")).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    startup::init().await;
}
