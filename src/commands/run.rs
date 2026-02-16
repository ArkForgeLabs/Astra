use crate::{LUA, RUNTIME_FLAGS, components::database::DATABASE_POOLS};
use std::path::PathBuf;
use tracing::error;

/// Runs a Lua script.
pub async fn run_command(
    file_path: Option<String>,
    code: Option<String>,
    stdlib_path: Option<String>,
    check_teal_code: bool,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;
    let mut actual_path: String = "init.lua".to_string();

    let mut check_for_default_file = |file_path: String| -> String {
        actual_path = file_path.clone();
        let file_path = std::path::Path::new(&file_path);

        #[allow(clippy::expect_used)]
        if file_path.exists() && file_path.is_file() {
            std::fs::read_to_string(file_path).expect("Couldn't read file")
        } else if file_path.join("init.lua").exists() {
            actual_path = file_path.join("init.lua").to_string_lossy().to_string();
            std::fs::read_to_string(file_path.join("init.lua")).expect("Couldn't read file")
        } else if file_path.join("init.tl").exists() {
            actual_path = file_path.join("init.tl").to_string_lossy().to_string();
            std::fs::read_to_string(file_path.join("init.tl")).expect("Couldn't read file")
        } else {
            panic!("Could not find any file to run...");
        }
    };

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let (user_file, actual_path_str) = if let Some(code) = code {
        actual_path = "<commandline>".to_string();
        (code, actual_path.clone())
    } else {
        let file = if let Some(file_path) = file_path {
            check_for_default_file(file_path)
        } else {
            check_for_default_file(".".to_string())
        };
        (file, actual_path.clone())
    };

    run_command_prerequisite(&actual_path_str, stdlib_path, check_teal_code, extra_args).await;
    spawn_termination_task();

    // Remove the Shebang lines
    let user_file = user_file
        .lines()
        .filter(|line| !line.starts_with("#!"))
        .collect::<Vec<_>>()
        .join("\n");

    if actual_path_str == "<commandline>" {
        if let Err(e) = lua.load(user_file).set_name("<commandline>").exec_async().await {
            error!("{}", e);
        }
    } else if let Some(is_teal) = PathBuf::from(&actual_path_str).extension()
        && is_teal == "tl"
    {
        if let Err(e) = crate::components::load_teal(lua).await {
            error!("{}", e);
        }

        if let Err(e) = crate::components::execute_teal_code(lua, &actual_path_str, &user_file).await {
            error!("{}", e);
        }
    } else if let Err(e) = lua.load(user_file).set_name(actual_path_str).exec_async().await {
        error!("{}", e);
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
    file_path: &str,
    stdlib_path: Option<String>,
    check_teal_code: bool,
    extra_args: Option<Vec<String>>,
) {
    if let Err(e) = super::remove_old_runtime() {
        error!("{e:?}");
    }

    let lua = &LUA;

    let stdlib_path = stdlib_path.unwrap_or("astra".to_string());

    if let Err(e) = RUNTIME_FLAGS.set(crate::RuntimeFlags {
        stdlib_path: PathBuf::from(stdlib_path.clone()),
        check_teal_code,
    }) {
        error!("Could not set the global STDLIB_PATH: {e:?}");
    }

    // Register Lua components.
    if let Err(e) = super::registration(lua, stdlib_path).await {
        error!("Error setting up the standard library: {e:?}");
    }

    // Handle extra arguments.
    if let Some(extra_args) = extra_args
        && let Ok(args) = lua.create_table()
    {
        if let Err(e) = args.set(0, file_path) {
            error!("Error adding arg to the args list: {e:?}");
        }

        for (index, value) in extra_args.into_iter().enumerate() {
            if let Err(e) = args.set((index + 1) as i32, value) {
                error!("Error adding arg to the args list: {e:?}");
            }
        }

        if let Err(e) = lua.globals().set("arg", args) {
            error!("Error setting the global variable ARGS: {e:?}");
        }
    }

    #[allow(clippy::expect_used)]
    lua.globals()
        .set("ASTRA_INTERNAL__CURRENT_SCRIPT", file_path)
        .expect("Couldn't set the script path");
}

fn spawn_termination_task() {
    tokio::spawn(async {
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

        if let Ok(exit_function) = LUA.globals().get::<mlua::Function>("ASTRA_SHUTDOWN_CODE")
            && let Err(e) = exit_function.call_async::<()>(()).await
        {
            error!("{e}");
        }

        let database_pools = DATABASE_POOLS.lock().await.clone();
        for i in database_pools {
            match i {
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
