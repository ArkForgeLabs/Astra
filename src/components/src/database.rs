use mlua::{LuaSerdeExt, UserData};
use sqlx::{Pool, Postgres, Row, Sqlite, migrate::MigrateDatabase};

#[derive(Debug, Clone)]
pub enum DatabaseType {
    Sqlite(Pool<Sqlite>),
    Postgres(Pool<Postgres>),
}

#[derive(Debug, Clone)]
pub struct Database {
    pub db: DatabaseType,
}
impl crate::AstraComponent for Database {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
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
                            .connect(format!("sqlite:{}", url).as_str())
                            .await
                        {
                            Ok(pool) => Ok(Database {
                                db: DatabaseType::Sqlite(pool),
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
                            db: DatabaseType::Postgres(pool),
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
            .set("astra_inner__database_connect", database_constructor)?;

        Ok(())
    }
}
impl UserData for Database {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        macro_rules! parse_sql_fn {
            ($function_name:ident, $row_type:ty) => {
                fn $function_name(lua: &mlua::Lua, row: &$row_type) -> mlua::Result<mlua::Table> {
                    match lua.create_table() {
                        Ok(table) => {
                            macro_rules! push_value {
                                ($data_type:ty,$i:expr) => {{
                                    if let Ok(value) = row.try_get::<$data_type, usize>($i) {
                                        table.push(value)?;
                                        continue;
                                    } else if let Ok(value) =
                                        row.try_get::<Option<$data_type>, usize>($i)
                                    {
                                        table.push(value)?;
                                        continue;
                                    }
                                }};
                            }
                            macro_rules! push_value_lua_parsed {
                                ($data_type:ty,$i:expr) => {{
                                    if let Ok(value) = row.try_get::<$data_type, usize>($i) {
                                        table.push(lua.to_value(&value)?)?;
                                        continue;
                                    } else if let Ok(value) =
                                        row.try_get::<Option<$data_type>, usize>($i)
                                    {
                                        table.push(lua.to_value(&value)?)?;
                                        continue;
                                    }
                                }};
                            }

                            let row_length = row.len();

                            for i in 0..row_length {
                                push_value!(i64, i);
                                push_value!(i32, i);
                                push_value!(i16, i);
                                push_value!(i8, i);
                                push_value!(f32, i);
                                push_value!(f64, i);
                                push_value!(bool, i);
                                push_value!(String, i);
                                push_value!(Vec<u8>, i);
                                push_value_lua_parsed!(serde_json::Value, i);
                                push_value_lua_parsed!(chrono::DateTime<chrono::Utc>, i);
                                push_value_lua_parsed!(uuid::Uuid, i);
                            }

                            Ok(table)
                        }

                        Err(e) => {
                            eprintln!("SQLx table creation error: {e:#?}");
                            Err(mlua::Error::runtime("Could not create a table in Lua"))
                        }
                    }
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
                }
            },
        );

        methods.add_async_method(
            "query_one",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
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
                }
            },
        );

        methods.add_async_method(
            "query_all",
            |lua, this, (sql, parameters): (String, Option<mlua::Table>)| async move {
                match &this.db {
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
                }
            },
        );
    }
}
