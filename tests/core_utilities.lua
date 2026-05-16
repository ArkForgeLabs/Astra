require("test")
local utils = require("utils")

---@param test Test
return function(test)
  test.describe("Core Utilities", function()
    test.describe("uuid", function()
      test.it("generates valid UUID format", function()
        local uuid1 = utils.uuid()
        local uuid2 = utils.uuid()

        -- UUID should be a string with hex characters
        test.expect(uuid1).to.be.a("string")
        test.expect(uuid2).to.be.a("string")

        -- UUID should contain only hex characters and hyphens
        test.expect(uuid1).to.match("^[0-9a-f%-]+$")
        test.expect(uuid2).to.match("^[0-9a-f%-]+$")
      end)

      test.it("generates unique UUIDs", function()
        local uuid1 = utils.uuid()
        local uuid2 = utils.uuid()

        test.expect(uuid1).to_not.equal(uuid2)
      end)
    end)

    test.describe("Environment Variables", function()
      test.it("gets environment variables", function()
        -- Set a test variable first
        utils.env.set("TEST_VAR", "test_value")
        local value = utils.env.get("TEST_VAR")
        test.expect(value).to.equal("test_value")

        -- Clean up
        utils.env.set("TEST_VAR", "")
      end)

      test.it("sets environment variables", function()
        utils.env.set("TEST_VAR2", "new_value")
        local value = utils.env.get("TEST_VAR2")
        test.expect(value).to.equal("new_value")

        -- Clean up
        utils.env.set("TEST_VAR2", "")
      end)

      test.it("handles non-existent variables", function()
        local value = utils.env.get("NON_EXISTENT_VAR")
        test.expect(value).to.equal(nil)
      end)
    end)

    test.describe("Async Tasks", function()
      for _, name in ipairs({ "spawn_task", "spawn_timeout", "spawn_interval" }) do
        test.it(name .. " function exists", function()
          test.expect(utils[name]).to.be.a("function")
        end)
      end
    end)

    test.describe("Module Cache", function()
      test.it("invalidates module cache", function()
        -- This is harder to test directly, but we can verify the function exists
        -- and doesn't throw errors
        test.expect(utils.clean_require).to.be.a("function")

        -- Test with a valid path
        utils.clean_require("test_module")
        -- Should not throw an error
      end)
    end)
  end)
end
