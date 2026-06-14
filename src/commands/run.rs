use crate::{LUA, RUNTIME_FLAGS, components::database::DATABASE_POOLS};
use std::path::PathBuf;
use tracing::error;

/// Runs a Lua script.
pub async fn run_command(
    file_path: Option<String>,
    code: Option<String>,
    stdlib_path: Option<String>,
    extra_args: Option<Vec<String>>,
) {
    #[allow(clippy::expect_used)]
    let lua = LUA.get().expect("Could not get access to the global VM");

    let mut actual_path: String = "init.lua".to_string();

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let (user_file, actual_path_str) = if let Some(code) = code {
        actual_path = "<commandline>".to_string();
        (code, actual_path.clone())
    } else {
        let file = if let Some(file_path) = file_path {
            check_for_default_file(&mut actual_path, file_path)
        } else {
            check_for_default_file(&mut actual_path, ".".to_string())
        };
        (file, actual_path.clone())
    };

    run_command_prerequisite(lua, &actual_path_str, stdlib_path, extra_args).await;
    spawn_termination_task();

    // Remove the Shebang lines
    let user_file = user_file
        .lines()
        .filter(|line| !line.starts_with("#!"))
        .collect::<Vec<_>>()
        .join("\n");

    #[allow(unused_mut)]
    let mut content_to_run = lua.load(user_file).set_name(format!("@{actual_path_str}"));
    #[cfg(feature = "luau")]
    {
        content_to_run =
            content_to_run.set_compiler(mlua::Compiler::new().set_optimization_level(2));
    }
    if let Err(e) = content_to_run.exec_async().await {
        eprintln!("{}", e)
    }

    // Wait for all Tokio tasks to finish.
    let metrics = tokio::runtime::Handle::current().metrics();
    loop {
        let alive_tasks = metrics.num_alive_tasks();
        if alive_tasks == 1 {
            break;
        }
    }
}

async fn run_command_prerequisite(
    lua: &mlua::Lua,
    file_path: &str,
    stdlib_path: Option<String>,
    extra_args: Option<Vec<String>>,
) {
    if let Err(e) = super::remove_old_runtime() {
        error!("{e:?}");
    }

    let stdlib_path = stdlib_path.unwrap_or("astra".to_string());

    if let Err(e) = RUNTIME_FLAGS.set(crate::RuntimeFlags {
        stdlib_path: PathBuf::from(stdlib_path.clone()),
    }) {
        error!("Could not set the global STDLIB_PATH: {e:?}");
    }

    // Register Lua components.
    if let Err(e) = super::registration(lua, file_path).await {
        error!("Error setting up the standard library: {e:?}");
    }

    // Handle extra arguments.
    if let Ok(args) = lua.create_table() {
        if let Err(e) = args.set(1, file_path) {
            error!("Error adding arg to the args list: {e:?}");
        }

        if let Some(extra_args) = extra_args {
            for (index, value) in extra_args.into_iter().enumerate() {
                if let Err(e) = args.set((index + 2) as i32, value) {
                    error!("Error adding arg to the args list: {e:?}");
                }
            }
        }

        if let Err(e) = lua.globals().set("arg", args) {
            error!("Error setting the global variable ARGS: {e:?}");
        }
    }
}

fn check_for_default_file(actual_path: &mut String, file_path: String) -> String {
    actual_path.clone_from(&file_path);
    let result;
    let file_path = std::path::Path::new(&file_path);

    #[allow(clippy::expect_used)]
    if file_path.exists() && file_path.is_file() {
        result = std::fs::read_to_string(file_path).expect("Couldn't read file");
    } else if file_path.join("init.lua").exists() {
        actual_path.clone_from(&file_path.join("init.lua").to_string_lossy().to_string());
        result = std::fs::read_to_string(file_path.join("init.lua")).expect("Couldn't read file");
    } else if file_path.join("init.luau").exists() {
        actual_path.clone_from(&file_path.join("init.luau").to_string_lossy().to_string());
        result = std::fs::read_to_string(file_path.join("init.luau")).expect("Couldn't read file");
    } else {
        panic!("Could not find any file to run...");
    }

    result
}

fn spawn_termination_task() {
    tokio::spawn(async move {
        let sigint = tokio::signal::ctrl_c();

        #[cfg(unix)]
        if let Ok(mut sigterm) =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            && let Ok(mut sigquit) =
                tokio::signal::unix::signal(tokio::signal::unix::SignalKind::quit())
        {
            tokio::select! {
                _ = sigterm.recv() => {}
                _ = sigquit.recv() => {}
                _ = sigint => {}
            }
        }

        #[cfg(not(unix))]
        {
            tokio::select! {
                _ = sigint => {}
            }
        }

        let database_pools = DATABASE_POOLS.lock().await.clone();
        for (_id, db_type) in database_pools {
            match db_type {
                crate::components::database::DatabaseType::Postgres(pool) => pool.close().await,
                crate::components::database::DatabaseType::Sqlite(pool) => pool.close().await,
            }
        }

        std::process::exit(
            #[cfg(unix)]
            0,
            #[cfg(not(unix))]
            256,
        );
    });
}
