local database = require("database")
local fs = require("fs")
require("test")

---@param test Test
return function(test)
  local describe, it, expect = test.describe, test.it, test.expect

  local function expect_closed_fails(method, ...)
    local closed = database.new("sqlite", ":memory:")
    closed:close()
    local args = { ... }
    expect(function()
      closed[method](closed, unpack(args))
    end).to.fail()
  end

  -------------------------------------------------------------------------------
  -- Constructor
  -------------------------------------------------------------------------------
  describe("Constructor", function()
    it("connects to sqlite with memory url", function()
      local db = database.new("sqlite", ":memory:")
      expect(db).to.exist()
      db:close()
    end)

    it("connects to sqlite with file path", function()
      pcall(fs.create_dir, "tests/_tmp")
      local db_path = "tests/_tmp/test_astra.db"
      local db = database.new("sqlite", db_path)
      expect(db).to.exist()
      db:close()
      fs.remove(db_path)
    end)

    it("accepts max_connections option", function()
      local db = database.new("sqlite", ":memory:", { max_connections = 5 })
      expect(db).to.exist()
      db:close()
    end)

    it("fails with invalid database type", function()
      expect(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        return database.new("mysql", ":memory:")
      end).to.fail()
    end)

    it("fails with invalid url", function()
      expect(function()
        return database.new("sqlite", "://bad")
      end).to.fail()
    end)
  end)

  -------------------------------------------------------------------------------
  -- Execute
  -------------------------------------------------------------------------------
  describe("Execute", function()
    local db
    test.before(function()
      db = database.new("sqlite", ":memory:")
      db:execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)")
    end)
    test.after(function()
      db:close()
    end)

    it("creates a table", function()
      local row = db:query_one("SELECT name FROM sqlite_master WHERE type='table' AND name='t'")
      expect(row).to.be.a("table")
      expect(row.name).to.equal("t")
    end)

    it("inserts a row", function()
      db:execute("INSERT INTO t (name) VALUES ('hello')")
    end)

    it("inserts with typed parameters", function()
      db:execute("CREATE TABLE t2 (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, score REAL)")
      db:execute("INSERT INTO t2 (name, value, score) VALUES (?, ?, ?)", { "test", 42, 3.14 })
    end)

    it("updates rows", function()
      db:execute("INSERT INTO t (name) VALUES ('hello')")
      db:execute("UPDATE t SET name = 'updated' WHERE id = ?", { 1 })
    end)

    it("deletes rows", function()
      db:execute("INSERT INTO t (name) VALUES ('hello')")
      db:execute("DELETE FROM t WHERE id = ?", { 1 })
    end)

    it("fails on closed connection", function()
      expect_closed_fails("execute", "SELECT 1")
    end)
  end)

  -------------------------------------------------------------------------------
  -- Query One
  -------------------------------------------------------------------------------
  describe("Query One", function()
    local db
    test.before(function()
      db = database.new("sqlite", ":memory:")
      db:execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, score REAL)")
      db:execute("INSERT INTO t (name, value, score) VALUES ('alpha', 10, 1.5)")
      db:execute("INSERT INTO t (name, value, score) VALUES ('beta', 20, 2.5)")
    end)
    test.after(function()
      db:close()
    end)

    it("returns a single row by id", function()
      local row = db:query_one("SELECT * FROM t WHERE id = ?", { 1 })
      expect(row).to.be.a("table")
      expect(row.name).to.equal("alpha")
      expect(row.value).to.equal(10)
    end)

    it("returns nil for nonexistent id", function()
      local row = db:query_one("SELECT * FROM t WHERE id = ?", { 999 })
      expect(row).to.equal(nil)
    end)

    it("returns row with typed columns", function()
      local row = db:query_one("SELECT * FROM t WHERE id = ?", { 2 })
      expect(row.name).to.be.a("string")
      expect(row.name).to.equal("beta")
      expect(row.value).to.be.a("number")
      expect(row.score).to.be.a("number")
    end)

    it("fails on closed connection", function()
      expect_closed_fails("query_one", "SELECT 1")
    end)
  end)

  -------------------------------------------------------------------------------
  -- Query All
  -------------------------------------------------------------------------------
  describe("Query All", function()
    local db
    test.before(function()
      db = database.new("sqlite", ":memory:")
      db:execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)")
      db:execute("INSERT INTO t (name, value) VALUES ('a', 1)")
      db:execute("INSERT INTO t (name, value) VALUES ('b', 2)")
      db:execute("INSERT INTO t (name, value) VALUES ('c', 3)")
    end)
    test.after(function()
      db:close()
    end)

    it("returns all rows", function()
      local rows = db:query_all("SELECT * FROM t ORDER BY id")
      expect(#rows).to.equal(3)
      expect(rows[1].name).to.equal("a")
      expect(rows[2].name).to.equal("b")
      expect(rows[3].name).to.equal("c")
    end)

    it("returns empty array for no match", function()
      local rows = db:query_all("SELECT * FROM t WHERE value > ?", { 100 })
      expect(#rows).to.equal(0)
    end)

    it("returns rows with multiple columns", function()
      local rows = db:query_all("SELECT * FROM t ORDER BY id")
      expect(rows[1].id).to.equal(1)
      expect(rows[1].name).to.equal("a")
      expect(rows[1].value).to.equal(1)
    end)

    it("fails on closed connection", function()
      expect_closed_fails("query_all", "SELECT 1")
    end)
  end)

  -------------------------------------------------------------------------------
  -- Pragma Queries
  -------------------------------------------------------------------------------
  describe("Pragma Queries", function()
    local db
    test.before(function()
      db = database.new("sqlite", ":memory:")
    end)
    test.after(function()
      db:close()
    end)

    it("query_pragma_int returns integer value", function()
      local result = db:query_pragma_int("PRAGMA user_version")
      expect(result).to.be.a("number")
      expect(result).to.equal(0)
    end)

    it("query_pragma_text returns string value", function()
      local result = db:query_pragma_text("SELECT 'hello' AS val")
      expect(result).to.be.a("string")
      expect(result).to.equal("hello")
    end)

    it("fails on closed connection", function()
      expect_closed_fails("query_pragma_int", "PRAGMA user_version")
      expect_closed_fails("query_pragma_text", "SELECT 'hello'")
    end)
  end)

  -------------------------------------------------------------------------------
  -- Close
  -------------------------------------------------------------------------------
  describe("Close", function()
    it("closes the connection", function()
      local db = database.new("sqlite", ":memory:")
      db:close()
      expect(function()
        db:execute("SELECT 1")
      end).to.fail()
    end)
  end)
end
