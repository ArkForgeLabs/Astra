#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

use clap::{Parser, command, crate_authors, crate_version};
use std::sync::LazyLock;
use tokio::sync::OnceCell;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod commands;
mod components;

/// Global Lua instance.
pub static LUA: LazyLock<mlua::Lua> = LazyLock::new(mlua::Lua::new);
/// Global script path.
pub static SCRIPT_PATH: OnceCell<std::path::PathBuf> = OnceCell::const_new();

/// Command-line interface for Astra.
#[derive(Parser)]
#[command(
    name = "Astra",
    bin_name = "astra",
    author = crate_authors!(),
    version = crate_version!(),
    about = r#"
    _    ____ _____ ____      _
   / \  / ___|_   _|  _ \    / \
  / _ \ \___ \ | | | |_) |  / _ \
 / ___ \ ___) || | |  _ <  / ___ \
/_/   \_\____/ |_| |_| \_\/_/   \_\

🔥 Blazingly Fast 🔥 web server runtime for Lua"#
)]
enum AstraCLI {
    #[command(arg_required_else_help = true, about = "Runs a Lua script")]
    Run {
        /// Path to the Lua script file.
        file_path: String,
        /// Path to the standard library folder
        #[arg(short, long)]
        stdlib_path: Option<String>,
        /// Extra arguments to pass to the script.
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        extra_args: Option<Vec<String>>,
    },
    #[command(
        about = "Exports the packages Lua bundle for import for IntelliSense",
        alias = "export"
    )]
    ExportBundle {
        /// Path to the export file.
        path: Option<String>,
    },
    #[command(about = "Updates to the latest version", alias = "update")]
    Upgrade {
        /// Custom user agent for requesting the updates
        user_agent: Option<String>,
    },
}

/// Initializes the Astra CLI.
#[tokio::main]
pub async fn main() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("{}=debug,tower_http=debug", env!("CARGO_CRATE_NAME")).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    match AstraCLI::parse() {
        AstraCLI::Run {
            file_path,
            stdlib_path,
            extra_args,
        } => commands::run_command(file_path, stdlib_path, extra_args).await,
        AstraCLI::ExportBundle { path } => commands::export_bundle_command(path).await,
        AstraCLI::Upgrade { user_agent } => {
            if let Err(e) = commands::upgrade_command(user_agent).await {
                eprintln!("Could not update to the latest version: {e}");
            }
        }
    }
}
