use crate::{LUA, RUNTIME_FLAGS};

async fn run_command_prerequisite(
    file_path: &str,
    stdlib_path: Option<String>,
    teal_compile_checks: Option<bool>,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;

    let stdlib_path = stdlib_path.unwrap_or("astra".to_string());
    let teal_compile_checks = teal_compile_checks.unwrap_or(true);

    if let Err(e) = RUNTIME_FLAGS.set(crate::RuntimeFlags {
        stdlib_path: std::path::PathBuf::from(stdlib_path.clone()),
        teal_compile_checks,
    }) {
        tracing::error!("Could not set the global STDLIB_PATH: {e:?}");
    }

    // Register Lua components.
    if let Err(e) = super::registration(lua, stdlib_path).await {
        tracing::error!("Error setting up the standard library: {e:?}");
    }

    // Handle extra arguments.
    if let Some(extra_args) = extra_args
        && let Ok(args) = lua.create_table()
    {
        if let Err(e) = args.set(0, file_path) {
            tracing::error!("Error adding arg to the args list: {e:?}");
        }

        for (index, value) in extra_args.into_iter().enumerate() {
            if let Err(e) = args.set((index + 1) as i32, value) {
                tracing::error!("Error adding arg to the args list: {e:?}");
            }
        }

        if let Err(e) = lua.globals().set("arg", args) {
            tracing::error!("Error setting the global variable ARGS: {e:?}");
        }
    }
}

/// Runs a Lua script.
pub async fn run_command(
    file_path: String,
    stdlib_path: Option<String>,
    teal_compile_checks: Option<bool>,
    extra_args: Option<Vec<String>>,
) {
    let lua = &LUA;

    run_command_prerequisite(&file_path, stdlib_path, teal_compile_checks, extra_args).await;

    // Load and execute the Lua script.
    #[allow(clippy::expect_used)]
    let user_file = std::fs::read_to_string(&file_path).expect("Couldn't read file");

    #[allow(clippy::expect_used)]
    lua.globals()
        .set("ASTRA_INTERNAL__CURRENT_SCRIPT", file_path.clone())
        .expect("Couldn't set the script path");

    if let Some(is_teal) = std::path::PathBuf::from(&file_path).extension()
        && is_teal == "tl"
    {
        // TODO: move this below
        #[allow(clippy::expect_used)]
        if let Err(e) = crate::components::execute_teal_code(lua, &file_path, &user_file).await {
            tracing::error!("{e:?}");
        };
    } else if let Err(e) = lua.load(user_file).set_name(file_path).exec_async().await {
        tracing::error!("{e}");
    }

    // TODO: JOIN ALL TASKS HERE, AND EXIT IN CASE OF ERROR

    // Wait for all Tokio tasks to finish.
    let metrics = tokio::runtime::Handle::current().metrics();
    loop {
        let alive_tasks = metrics.num_alive_tasks();
        if alive_tasks == 0 {
            break;
        }
    }
}
