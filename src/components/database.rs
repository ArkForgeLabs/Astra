use mlua::{LuaSerdeExt, UserData};
use sqlx::{Pool, Postgres, Row, Sqlite, migrate::MigrateDatabase};

#[derive(Debug, Clone)]
pub enum DatabaseType {
    Sqlite(Pool<Sqlite>),
    Postgres(Pool<Postgres>),
}

#[derive(Debug, Clone)]
pub struct Database {
    pub db: Option<DatabaseType>,
}
impl Database {
    pub fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let database_constructor = lua.create_async_function(
            |_, (database_type, url, max_connections): (String, String, Option<u32>)| async move {
                let max_connections = max_connections.unwrap_or(10);

                // pre checkup
                if database_type == *"sqlite" {
                    match Sqlite::database_exists(url.as_str()).await {
                        Ok(exists) => {
                            if !exists {
                                match Sqlite::create_database(url.as_str()).await {
                                    Ok(()) => {}
                                    Err(e) => println!("Error creating the Sqlite DB: {e:#?}"),
                                }
                            }
                        }
                        Err(e) => println!("Error checking if the Sqlite DB exists: {e:#?}"),
                    }
                }

                match database_type.as_str() {
                    "sqlite" => {
                        match sqlx::sqlite::SqlitePoolOptions::new()
                            .max_connections(max_connections)
                            .connect(format!("sqlite:{url}").as_str())
                            .await
                        {
                            Ok(pool) => Ok(Database {
                                db: Some(DatabaseType::Sqlite(pool)),
                            }),
                            Err(e) => Err(mlua::Error::runtime(format!(
                                "Error connecting to Sqlite: {e:#?}"
                            ))),
                        }
                    }
                    "postgres" => match sqlx::postgres::PgPoolOptions::new()
                        .max_connections(max_connections)
                        .connect(url.as_str())
                        .await
                    {
                        Ok(pool) => Ok(Database {
                            db: Some(DatabaseType::Postgres(pool)),
                        }),
                        Err(e) => Err(mlua::Error::runtime(format!(
                            "Error connecting to Postgres: {e:#?}"
                        ))),
                    },
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
                fn $function_name(
                    lua: mlua::Lua,
                    sql: &str,
                    parameters: Option<mlua::Table>,
                ) -> $return_type {
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
            sqlx::query::Query<'_, sqlx::Postgres, sqlx::postgres::PgArguments>
        );
        query_builder_fn!(
            query_builder_sqlite,
            sqlx::query::Query<'_, sqlx::Sqlite, sqlx::sqlite::SqliteArguments>
        );

        methods.add_async_method(
            "execute",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
                    Some(db) => match &db {
                        DatabaseType::Sqlite(pool) => {
                            let query = query_builder_sqlite(lua.clone(), &sql, parameters);

                            match query.execute(pool).await {
                                Ok(_) => Ok(()),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                        DatabaseType::Postgres(pool) => {
                            let query = query_builder_postgres(lua.clone(), &sql, parameters);

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

        methods.add_async_method(
            "query_one",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
                    Some(db) => match &db {
                        DatabaseType::Sqlite(pool) => {
                            let query = query_builder_sqlite(lua.clone(), &sql, parameters);

                            match query.fetch_one(pool).await {
                                Ok(row) => Ok(parse_sql_to_lua_sqlite(&lua, &row)?),
                                Err(e) => Err(mlua::Error::runtime(format!(
                                    "Error executing the query: {e:#?}"
                                ))),
                            }
                        }
                        DatabaseType::Postgres(pool) => {
                            let query = query_builder_postgres(lua.clone(), &sql, parameters);

                            match query.fetch_one(pool).await {
                                Ok(row) => Ok(parse_sql_to_lua_postgres(&lua, &row)?),
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
                            let query = query_builder_sqlite(lua.clone(), &sql, parameters);

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
                            let query = query_builder_postgres(lua.clone(), &sql, parameters);

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
            this.db = None;

            Ok(())
        });
    }
}
