use mlua::{ExternalError, LuaSerdeExt, UserData};
use sqlx::{Pool, Postgres, Row, Sqlite, migrate::MigrateDatabase};
use std::sync::atomic::AtomicU64;
use std::{str::FromStr, sync::LazyLock};
use tokio::sync::Mutex;

#[derive(Debug, Clone, serde::Deserialize)]
struct AstraSQLConnectionOption {
    max_connections: Option<u32>,
    extensions: Vec<String>,
    extensions_with_entrypoint: Vec<(String, String)>,
    is_immutable: bool,
    other_options: Vec<(String, String)>,
}

static NEXT_DB_ID: AtomicU64 = AtomicU64::new(1);
pub static DATABASE_POOLS: LazyLock<Mutex<Vec<(u64, DatabaseType)>>> =
    LazyLock::new(|| Mutex::new(Vec::new()));

#[derive(Debug, Clone)]
pub enum DatabaseType {
    Sqlite(Pool<Sqlite>),
    Postgres(Pool<Postgres>),
}

#[derive(Debug, Clone)]
pub struct Database {
    pub id: u64,
    pub db: Option<DatabaseType>,
}
impl Database {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let database_constructor = lua.create_async_function(
            |lua,
             (database_type, url, connection_options): (
                String,
                String,
                mlua::Value,
            )| async move {
                let connection_options = lua.from_value::<AstraSQLConnectionOption>(connection_options)?;
                let max_connections = connection_options.max_connections.unwrap_or(10);

                if database_type == *"sqlite" {
                    match Sqlite::database_exists(url.as_str()).await {
                        Ok(true) => {}
                        Ok(false) => {
                            Sqlite::create_database(url.as_str()).await
                                .map_err(|e| mlua::Error::runtime(format!("Error creating Sqlite DB: {e:#?}")))?;
                        }
                        Err(e) => {
                            return Err(mlua::Error::runtime(format!("Error checking Sqlite DB exists: {e:#?}")));
                        }
                    }
                }

                match database_type.as_str() {
                    "sqlite" => {
                        match sqlx::sqlite::SqliteConnectOptions::from_str(
                            format!("sqlite:{url}").as_str(),
                        ) {
                            Ok(options) => {
                                let mut options = options.create_if_missing(true);

                                for i in connection_options.extensions {
                                    options = unsafe {options.extension(i)}
                                }
                                for (name, entry_point) in
                                    connection_options.extensions_with_entrypoint
                                {
                                    options = unsafe {options.extension_with_entrypoint(name, entry_point)}
                                }
                                options = options.immutable(connection_options.is_immutable);

                                match sqlx::sqlite::SqlitePoolOptions::new()
                                    .max_connections(max_connections)
                                    .connect_with(options)
                                    .await
                                {
                                    Ok(pool) => {
                                        let db_id = NEXT_DB_ID.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                        let pool = DatabaseType::Sqlite(pool);

                                        let mut database_pools = DATABASE_POOLS.lock().await;
                                        database_pools.push((db_id, pool.clone()));

                                        Ok(Database { id: db_id, db: Some(pool) })
                                    }
                                    Err(e) => Err(mlua::Error::runtime(format!(
                                        "Error connecting to Sqlite: {e:#?}"
                                    ))),
                                }
                            }
                            Err(e) => Err(e.into_lua_err()),
                        }
                    }
                    "postgres" => {
                        //
                        match sqlx::postgres::PgConnectOptions::from_str(url.as_str()) {
                            Ok(options) => {
                                match sqlx::postgres::PgPoolOptions::new()
                                    .max_connections(max_connections)
                                    .connect_with(options.options(connection_options.other_options))
                                    .await
                                {
                                    Ok(pool) => {
                                        let db_id = NEXT_DB_ID.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                        let pool = DatabaseType::Postgres(pool);

                                        let mut database_pools = DATABASE_POOLS.lock().await;
                                        database_pools.push((db_id, pool.clone()));

                                        Ok(Database { id: db_id, db: Some(pool) })
                                    }
                                    Err(e) => Err(mlua::Error::runtime(format!(
                                        "Error connecting to Postgres: {e:#?}"
                                    ))),
                                }
                            }
                            Err(e) => Err(e.into_lua_err()),
                        }
                    }
                    _ => Err(mlua::Error::runtime(
                        "Could not recognize the database type",
                    )),
                }
            },
        )?;
        lua.globals()
            .set("astra_internal__database_connect", database_constructor)?;

        Ok(())
    }
}
fn validate_params(lua: &mlua::Lua, parameters: Option<&mlua::Table>) -> mlua::Result<()> {
    if let Some(table) = parameters {
        for val in table.sequence_values::<mlua::Value>() {
            let val = val?;
            match val {
                mlua::Value::String(_)
                | mlua::Value::Number(_)
                | mlua::Value::Integer(_)
                | mlua::Value::Boolean(_) => continue,
                mlua::Value::Table(_) => {
                    if lua.from_value::<serde_json::Value>(val).is_err() {
                        return Err(mlua::Error::runtime(
                            "Unsupported table parameter: cannot serialize to JSON",
                        ));
                    }
                }
                _ => {
                    return Err(mlua::Error::runtime(format!(
                        "Unsupported parameter type: {}",
                        val.type_name()
                    )));
                }
            }
        }
    }
    Ok(())
}

impl UserData for Database {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        macro_rules! parse_sql_fn {
            ($function_name:ident, $row_type:ty) => {
                fn $function_name(lua: &mlua::Lua, row: &$row_type) -> mlua::Result<mlua::Table> {
                    use sqlx::Column;

                    let table = lua.create_table()?;

                    macro_rules! try_set_value {
                        ($i:expr, $key:expr, $ty:ty) => {
                            if let Ok(v) = row.try_get::<$ty, _>($i) {
                                table.set($key, v)?;
                                continue;
                            } else if let Ok(v) = row.try_get::<Option<$ty>, _>($i) {
                                table.set($key, v)?;
                                continue;
                            }
                        };
                    }

                    macro_rules! try_set_lua_value {
                        ($i:expr, $key:expr, $ty:ty) => {
                            if let Ok(v) = row.try_get::<$ty, _>($i) {
                                table.set($key, lua.to_value(&v)?)?;
                                continue;
                            } else if let Ok(v) = row.try_get::<Option<$ty>, _>($i) {
                                table.set($key, lua.to_value(&v)?)?;
                                continue;
                            }
                        };
                    }

                    for i in 0..row.len() {
                        let key = row.column(i).name();

                        try_set_value!(i, key, i64);
                        try_set_value!(i, key, i32);
                        try_set_value!(i, key, i16);
                        try_set_value!(i, key, i8);
                        try_set_value!(i, key, f32);
                        try_set_value!(i, key, f64);
                        try_set_value!(i, key, bool);
                        try_set_value!(i, key, String);
                        try_set_value!(i, key, Vec<u8>);

                        try_set_lua_value!(i, key, serde_json::Value);
                        try_set_lua_value!(i, key, chrono::DateTime<chrono::Utc>);
                        try_set_lua_value!(i, key, uuid::Uuid);

                        // fallback if all fail
                        table.set(key, mlua::Value::Nil)?;
                    }

                    Ok(table)
                }
            };
        }
        // This is because of the duplicated code that would break or
        // become too complicated if traits are introduced.
        //
        // Maybe one day a better solution will be introduced.
        parse_sql_fn!(parse_sql_to_lua_postgres, sqlx::postgres::PgRow);
        parse_sql_fn!(parse_sql_to_lua_sqlite, sqlx::sqlite::SqliteRow);

        macro_rules! query_builder_fn {
            ($function_name:ident, $return_type:ty) => {
                #[allow(mismatched_lifetime_syntaxes)]
                fn $function_name(
                    lua: mlua::Lua,
                    sql: String,
                    parameters: Option<mlua::Table>,
                ) -> $return_type {
                    let sql: &'static str = sql.leak();
                    let mut query = sqlx::query(sql);

                    match parameters {
                        Some(param_values) => {
                            // turn parameters into actual values
                            for param in param_values
                                .sequence_values::<mlua::Value>()
                                .filter_map(|value| match value {
                                    Ok(value) => Some(value),
                                    Err(_) => None,
                                })
                                .collect::<Vec<_>>()
                            {
                                match param {
                                    mlua::Value::String(value) => {
                                        query = query.bind(value.to_string_lossy())
                                    }
                                    mlua::Value::Number(value) => query = query.bind(value),
                                    mlua::Value::Integer(value) => query = query.bind(value),
                                    mlua::Value::Boolean(value) => query = query.bind(value),
                                    mlua::Value::Table(_) => {
                                        if let Ok(json) =
                                            lua.from_value::<serde_json::Value>(param.clone())
                                        {
                                            query = query.bind(json)
                                        }
                                    }

                                    _ => {}
                                }
                            }
                        }
                        None => {}
                    };

                    query
                }
            };
        }
        query_builder_fn!(
            query_builder_postgres,
            sqlx::query::Query<'static, sqlx::Postgres, sqlx::postgres::PgArguments>
        );
        query_builder_fn!(
            query_builder_sqlite,
            sqlx::query::Query<'static, sqlx::Sqlite, sqlx::sqlite::SqliteArguments>
        );

        methods.add_async_method(
            "execute",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
                    Some(db) => match &db {
                        DatabaseType::Sqlite(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_sqlite(lua.clone(), sql, parameters);

                            match query.execute(pool).await {
                                Ok(_) => Ok(()),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                        DatabaseType::Postgres(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_postgres(lua.clone(), sql, parameters);

                            match query.execute(pool).await {
                                Ok(_) => Ok(()),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                    },
                    None => Err(mlua::Error::runtime("The connection is closed")),
                }
            },
        );

        macro_rules! query_pragma {
            ($type:ty, $lua:ident, $sql:ident, $db:ident) => {
                match &$db {
                    DatabaseType::Sqlite(pool) => {
                        let sql: &'static str = $sql.leak();
                        match sqlx::query_scalar::<_, $type>(sql)
                            .fetch_optional(pool)
                            .await
                        {
                            Ok(row) => {
                                if let Some(row) = row {
                                    $lua.to_value(&row)
                                } else {
                                    Ok(mlua::Value::Nil)
                                }
                            }
                            Err(e) => Err(e.into_lua_err()),
                        }
                    }
                    DatabaseType::Postgres(pool) => {
                        let sql: &'static str = $sql.leak();
                        match sqlx::query_scalar::<_, $type>(sql)
                            .fetch_optional(pool)
                            .await
                        {
                            Ok(row) => {
                                if let Some(row) = row {
                                    $lua.to_value(&row)
                                } else {
                                    Ok(mlua::Value::Nil)
                                }
                            }
                            Err(e) => Err(e.into_lua_err()),
                        }
                    }
                }
            };
        }

        methods.add_async_method("query_pragma_int", |lua, this, sql: String| async move {
            match &this.db {
                Some(db) => query_pragma!(i32, lua, sql, db), // returns NULL not nil
                None => Err(mlua::Error::runtime("The connection is closed")),
            }
        });

        methods.add_async_method("query_pragma_text", |lua, this, sql: String| async move {
            match &this.db {
                Some(db) => query_pragma!(String, lua, sql, db),
                None => Err(mlua::Error::runtime("The connection is closed")),
            }
        });

        methods.add_async_method(
            "query_one",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
                    Some(db) => match &db {
                        DatabaseType::Sqlite(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_sqlite(lua.clone(), sql, parameters);

                            match query.fetch_optional(pool).await {
                                Ok(Some(row)) => {
                                    Ok(mlua::Value::Table(parse_sql_to_lua_sqlite(&lua, &row)?))
                                }
                                Ok(None) => Ok(mlua::Value::Nil),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                        DatabaseType::Postgres(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_postgres(lua.clone(), sql, parameters);

                            match query.fetch_optional(pool).await {
                                Ok(Some(row)) => {
                                    Ok(mlua::Value::Table(parse_sql_to_lua_postgres(&lua, &row)?))
                                }
                                Ok(None) => Ok(mlua::Value::Nil),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                    },
                    None => Err(mlua::Error::runtime("The connection is closed")),
                }
            },
        );

        methods.add_async_method(
            "query_all",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
                    Some(db) => match &db {
                        DatabaseType::Sqlite(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_sqlite(lua.clone(), sql, parameters);

                            match query.fetch_all(pool).await {
                                Ok(rows) => {
                                    let mut vec = Vec::new();

                                    for row in rows {
                                        let sql_row_lua = parse_sql_to_lua_sqlite(&lua, &row)?;
                                        vec.push(sql_row_lua);
                                    }

                                    Ok(vec)
                                }
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                        DatabaseType::Postgres(pool) => {
                            if let Some(ref p) = parameters {
                                validate_params(&lua, Some(p))?;
                            }
                            let query = query_builder_postgres(lua.clone(), sql, parameters);

                            match query.fetch_all(pool).await {
                                Ok(rows) => {
                                    let mut vec = Vec::new();

                                    for row in rows {
                                        let sql_row_lua = parse_sql_to_lua_postgres(&lua, &row)?;
                                        vec.push(sql_row_lua);
                                    }

                                    Ok(vec)
                                }
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                    },
                    None => Err(mlua::Error::runtime("The connection is closed")),
                }
            },
        );

        methods.add_async_method_mut("close", |_, mut this, _: ()| async move {
            if let Some(db) = &this.db {
                match db {
                    DatabaseType::Sqlite(pool) => pool.close().await,
                    DatabaseType::Postgres(pool) => pool.close().await,
                };
            }

            let mut pools = DATABASE_POOLS.lock().await;
            pools.retain(|(id, _)| *id != this.id);
            drop(pools);

            this.db = None;

            Ok(())
        });
    }
}
