use crate::common::LUA;
use mlua::{LuaSerdeExt, UserData};
use sqlx::Row;

#[derive(Debug, Clone)]
pub struct Database {
    pub pool: sqlx::Pool<sqlx::Postgres>,
}
impl crate::utils::LuaUtils for Database {
    async fn register_to_lua(lua: &mlua::Lua) -> mlua::Result<()> {
        let database_constructor = lua.create_async_function(|_, url: String| async move {
            match sqlx::postgres::PgPoolOptions::new()
                .max_connections(5)
                .connect(url.as_str())
                .await
            {
                Ok(pool) => Ok(Database { pool }),
                Err(e) => {
                    eprintln!("Error connecting to PostgreSQL: {e:#?}");
                    Err(mlua::Error::runtime("Could not open a connection"))
                }
            }
        })?;
        lua.globals()
            .set("database_connect", database_constructor)?;

        Ok(())
    }
}
impl UserData for Database {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        fn parse_sql_to_lua(row: &sqlx::postgres::PgRow) -> mlua::Result<mlua::Table> {
            match LUA.create_table() {
                Ok(table) => {
                    macro_rules! push_value {
                        ($data_type:ty,$i:expr) => {{
                            if let Ok(value) = row.try_get::<$data_type, usize>($i) {
                                table.push(value)?;
                            } else if let Ok(value) = row.try_get::<Option<$data_type>, usize>($i) {
                                table.push(value)?;
                            }
                        }};
                    }
                    macro_rules! push_value_lua_parsed {
                        ($data_type:ty,$i:expr) => {{
                            if let Ok(value) = row.try_get::<$data_type, usize>($i) {
                                table.push(LUA.to_value(&value)?)?;
                            } else if let Ok(value) = row.try_get::<Option<$data_type>, usize>($i) {
                                table.push(LUA.to_value(&value)?)?;
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

        fn query_builder(
            sql: &str,
            parameters: mlua::Table,
        ) -> sqlx::query::Query<'_, sqlx::Postgres, sqlx::postgres::PgArguments> {
            // turn parameters into actual values
            let mut query = sqlx::query(sql);
            for param in parameters
                .sequence_values::<mlua::Value>()
                .filter_map(|value| match value {
                    Ok(value) => Some(value),
                    Err(_) => None,
                })
                .collect::<Vec<_>>()
            {
                match param {
                    mlua::Value::String(value) => query = query.bind(value.to_string_lossy()),
                    mlua::Value::Number(value) => query = query.bind(value),
                    mlua::Value::Integer(value) => query = query.bind(value),
                    mlua::Value::Boolean(value) => query = query.bind(value),
                    mlua::Value::Table(_) => {
                        if let Ok(json) = LUA.from_value::<serde_json::Value>(param.clone()) {
                            query = query.bind(json)
                        }
                    }

                    _ => {}
                }
            }

            query
        }

        methods.add_async_method(
            "execute",
            |_, this, (sql, parameters): (String, mlua::Table)| async move {
                let query = query_builder(&sql, parameters);
                match query.execute(&this.pool).await {
                    Ok(_) => Ok(()),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "Error executing the query: {e:#?}"
                    ))),
                }
            },
        );

        methods.add_async_method(
            "query_one",
            |_, this, (sql, parameters): (String, mlua::Table)| async move {
                let query = query_builder(&sql, parameters);

                match query.fetch_one(&this.pool).await {
                    Ok(row) => Ok(parse_sql_to_lua(&row)?),
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "Error executing the query: {e:#?}"
                    ))),
                }
            },
        );

        methods.add_async_method(
            "query_all",
            |_, this, (sql, parameters): (String, mlua::Table)| async move {
                let query = query_builder(&sql, parameters);

                match query.fetch_all(&this.pool).await {
                    Ok(rows) => {
                        let mut vec = Vec::new();

                        for row in rows {
                            let sql_row_lua = parse_sql_to_lua(&row)?;
                            vec.push(sql_row_lua);
                        }

                        Ok(vec)
                    }
                    Err(e) => Err(mlua::Error::runtime(format!(
                        "Error executing the query: {e:#?}"
                    ))),
                }
            },
        );
    }
}
