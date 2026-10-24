-- In-process sandbox/global semantics for the default (fully open) VM.
-- Restricted-VM flag gating is covered by tests/sandbox.rs (process-level,
-- since ALLOW_LIST is per-process).
require("test")
local utils = require("utils")

---@param test Test
return function(test)
  test.describe("Astra Globals", function()
    test.it("getenv returns values for existing variables", function()
      test.expect(getenv("PATH")).to.exist()
    end)

    test.it("getenv returns nil for missing variables (os.getenv idiom)", function()
      test.expect(getenv("ASTRA_TEST_DEFINITELY_UNSET_VAR_9127")).to_not.exist()
      test.expect(getenv("ASTRA_TEST_DEFINITELY_UNSET_VAR_9127") or "fallback").to.equal("fallback")
    end)

    test.it("setenv round-trips through getenv", function()
      setenv("ASTRA_TEST_ROUNDTRIP_VAR", "astra-value-42")
      test.expect(getenv("ASTRA_TEST_ROUNDTRIP_VAR")).to.equal("astra-value-42")
    end)

    test.it("loadfile returns nil plus a message for missing files", function()
      local chunk, err = loadfile("/astra-test-nonexistent.lua")
      test.expect(chunk).to_not.exist()
      test.expect(err).to.exist()
      test.expect(type(err)).to.be.a("string")
    end)

    test.it("dofile raises for missing files", function()
      local ok, err = pcall(dofile, "/astra-test-nonexistent.lua")
      test.expect(ok).to_not.equal(true)
      test.expect(err).to.exist()
    end)

    test.it("require loads embedded stdlib modules", function()
      local fs = require("fs")
      test.expect(fs).to.exist()
      test.expect(fs).to.be.a("table")
    end)

    test.it("require caches modules (same table identity)", function()
      local first = require("utils")
      local second = require("utils")
      test.expect(first).to.equal(second)
    end)

    test.it("require reports clean errors for missing modules", function()
      test.expect(function()
        require("astra_test_definitely_missing_module_9127")
      end).to.fail()
    end)
  end)
end
