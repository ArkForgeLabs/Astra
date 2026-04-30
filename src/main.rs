#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]

use clap::{Parser, crate_authors, crate_version};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod commands;
mod components;

/// Global Lua instance.
pub static LUA: std::sync::OnceLock<mlua::Lua> = std::sync::OnceLock::new();

#[derive(Debug, Clone)]
pub struct RuntimeFlags {
    pub stdlib_path: std::path::PathBuf,
}
pub static RUNTIME_FLAGS: tokio::sync::OnceCell<RuntimeFlags> = tokio::sync::OnceCell::const_new();

/// Global standard libraries and type definitions from Astra
pub static ASTRA_STD_LIBS: std::sync::LazyLock<include_dir::Dir<'_>> =
    std::sync::LazyLock::new(|| include_dir::include_dir!("astra"));

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

🔥 Blazingly Fast 🔥 runtime environment for Lua"#
)]
enum AstraCLI {
    #[command(arg_required_else_help = true, about = "Runs a Lua script")]
    Run {
        /// Path to the Lua script file.
        file_path: Option<String>,
        /// Execute code directly from command line instead of a file.
        #[arg(short = 'e', long)]
        code: Option<String>,
        /// Path to the standard library folder
        #[arg(short, long)]
        stdlib_path: Option<String>,
        /// Enables safe mode by removing access to dangerous standard library and behaviors
        #[arg(short, long, action)]
        safe: bool,
        /// Extra arguments to pass to the script.
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        extra_args: Option<Vec<String>>,
    },
    #[command(
        about = "Exports the type definitions for language servers",
        alias = "export"
    )]
    ExportBundle {
        /// Export Teal configuration and type definitions
        #[arg(short, long, action)]
        teal_export: bool,
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
pub async fn main() -> std::io::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("{}=debug,tower_http=debug", env!("CARGO_CRATE_NAME")).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer().compact())
        .init();

    match AstraCLI::parse() {
        AstraCLI::Run {
            file_path,
            code,
            stdlib_path,
            safe,
            extra_args,
        } => {
            if safe {
                LUA.set(
                    mlua::Lua::new_with(
                        mlua::StdLib::ALL_SAFE,
                        mlua::LuaOptions::new()
                            .thread_pool_size(std::thread::available_parallelism()?.get()),
                    )
                    .expect("Could not start the safe runtime"),
                );
            } else {
                LUA.set(unsafe {
                    mlua::Lua::unsafe_new_with(
                        mlua::StdLib::ALL,
                        mlua::LuaOptions::new()
                            .thread_pool_size(std::thread::available_parallelism()?.get()),
                    )
                });
            }

            commands::run_command(file_path, code, stdlib_path, extra_args).await
        }
        AstraCLI::ExportBundle { teal_export, path } => {
            commands::export_bundle_command(teal_export, path).await?
        }
        AstraCLI::Upgrade { user_agent } => {
            if let Err(e) = commands::upgrade_command(user_agent).await {
                eprintln!("Could not update to the latest version: {e}");
            }
        }
    }

    Ok(())
}
