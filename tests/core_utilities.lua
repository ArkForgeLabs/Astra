require("test")
local astra = require("astra.lua.astra")

---@param test Test
return function(test)
  test.describe("Core Utilities", function()
    test.describe("uuid", function()
      test.it("generates valid UUID format", function()
        local uuid1 = uuid()
        local uuid2 = uuid()

        -- UUID should be a string with hex characters
        test.expect(uuid1).to.be.a("string")
        test.expect(uuid2).to.be.a("string")

        -- UUID should contain only hex characters and hyphens
        test.expect(uuid1).to.match("^[0-9a-f%-]+$")
        test.expect(uuid2).to.match("^[0-9a-f%-]+$")
      end)

      test.it("generates unique UUIDs", function()
        local uuid1 = uuid()
        local uuid2 = uuid()

        test.expect(uuid1).to_not.equal(uuid2)
      end)
    end)

    test.describe("string.split", function()
      test.it("splits string by separator", function()
        local result = string.split("hello world", " ")
        test.expect(result).to.equal({ "hello", "world" })
      end)

      test.it("handles multiple separators", function()
        local result = string.split("a,b,c", ",")
        test.expect(result).to.equal({ "a", "b", "c" })
      end)

      test.it("handles empty string", function()
        local result = string.split("", " ")
        test.expect(result).to.equal({})
      end)

      test.it("handles no separator found", function()
        local result = string.split("hello", " ")
        test.expect(result).to.equal({ "hello" })
      end)

      test.it("handles consecutive separators", function()
        local result = string.split("a,,b", ",")
        -- string.split removes empty strings from consecutive separators
        test.expect(result).to.equal({ "a", "b" })
      end)
    end)

    test.describe("Environment Variables", function()
      test.it("gets environment variables", function()
        -- Set a test variable first
        os.setenv("TEST_VAR", "test_value")
        local value = os.getenv("TEST_VAR")
        test.expect(value).to.equal("test_value")

        -- Clean up
        os.setenv("TEST_VAR", "")
      end)

      test.it("sets environment variables", function()
        os.setenv("TEST_VAR2", "new_value")
        local value = os.getenv("TEST_VAR2")
        test.expect(value).to.equal("new_value")

        -- Clean up
        os.setenv("TEST_VAR2", "")
      end)

      test.it("handles non-existent variables", function()
        local value = os.getenv("NON_EXISTENT_VAR")
        test.expect(value).to.equal(nil)
      end)
    end)

    test.describe("Async Tasks", function()
      for _, name in ipairs({ "spawn_task", "spawn_timeout", "spawn_interval" }) do
        test.it(name .. " function exists", function()
          test.expect(_G[name]).to.be.a("function")
        end)
      end
    end)

    test.describe("Module Cache", function()
      test.it("invalidates module cache", function()
        -- This is harder to test directly, but we can verify the function exists
        -- and doesn't throw errors
        test.expect(clean_require).to.be.a("function")

        -- Test with a valid path
        clean_require("test_module")
        -- Should not throw an error
      end)
    end)
  end)
end
