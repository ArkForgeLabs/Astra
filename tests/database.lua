local database = require("database")

local db = database.new("postgres", "postgresql://postgres:yourpassword@localhost:5432/mydatabase")

db:execute("CREATE TABLE IF NOT EXISTS test(id INTEGER PRIMARY KEY, name TEXT);")
-- db:execute("INSERT INTO test(id, name) VALUES (1, 'foo'), (2, 'bar'), (3, 'baz');")

local result = db:query_all("SELECT * FROM test")
pprint(result)

db:close()
