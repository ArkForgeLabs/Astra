# SQL Driver

If your server requires access to an SQL database such as PostgreSQL and SQLite, Astra provides utilities for basic connection and querying.

```lua
-- connect to your db
local db = require("astra.lua.database")("postgres", "postgres://astra_postgres:password@localhost/astr_database")

-- You can execute queries to the database along with optional parameters
db:execute([[
    CREATE TABLE IF NOT EXISTS test (id SERIAL PRIMARY KEY, name TEXT);

    INSERT INTO TABLE test(name) VALUES ('Astra');
]], {});

-- And finally query either one which returns a single result or
local result = db:query_one("SELECT * FROM test;", {});

-- query all from tables which returns an array as result
-- which also supports parameters for protection against SQL injection attacks
local name = "Tom"
local result = db:query_all("INSERT INTO test (name) VALUES ($1)", {name});

pprint(result)
```
