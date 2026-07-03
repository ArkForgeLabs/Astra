require("test")
local utils = require("utils")

---@param test Test
return function(test)
  test.describe("Core Utilities", function()
    test.describe("uuid", function()
      test.it("generates valid UUID format", function()
        local uuid1 = utils.uuid()
        local uuid2 = utils.uuid()

        test.expect(uuid1).to.be.a("string")
        test.expect(uuid2).to.be.a("string")

        test.expect(#uuid1).to.equal(36)
        test.expect(#uuid2).to.equal(36)

        test.expect(uuid1).to.match("^[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+$")
        test.expect(uuid2).to.match("^[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+$")
      end)

      test.it("generates unique UUIDs", function()
        local uuid1 = utils.uuid()
        local uuid2 = utils.uuid()

        test.expect(uuid1).to_not.equal(uuid2)
      end)

      test.it("has correct segment structure", function()
        local uuid = utils.uuid()
        local segments = {}
        for segment in uuid:gmatch("[^%-]+") do
          table.insert(segments, segment)
        end
        test.expect(#segments).to.equal(5)
        test.expect(#segments[1]).to.equal(8)
        test.expect(#segments[2]).to.equal(4)
        test.expect(#segments[3]).to.equal(4)
        test.expect(#segments[4]).to.equal(4)
        test.expect(#segments[5]).to.equal(12)
      end)
    end)

    test.describe("Environment Variables", function()
      test.it("gets environment variables", function()
        utils.env.set("TEST_VAR", "test_value")
        local value = utils.env.get("TEST_VAR")
        test.expect(value).to.equal("test_value")
        utils.env.set("TEST_VAR", "")
      end)

      test.it("sets environment variables", function()
        utils.env.set("TEST_VAR2", "new_value")
        local value = utils.env.get("TEST_VAR2")
        test.expect(value).to.equal("new_value")
        utils.env.set("TEST_VAR2", "")
      end)

      test.it("handles non-existent variables", function()
        local value = utils.env.get("NON_EXISTENT_VAR_XYZ_123")
        test.expect(value).to.equal(nil)
      end)
    end)

    test.describe("Async Tasks", function()
      test.it("spawn_task function exists", function()
        test.expect(utils.spawn_task).to.be.a("function")
      end)

      test.it("spawn_timeout function exists", function()
        test.expect(utils.spawn_timeout).to.be.a("function")
      end)

      test.it("spawn_interval function exists", function()
        test.expect(utils.spawn_interval).to.be.a("function")
      end)
    end)

    test.describe("Module Cache", function()
      test.it("clean_require function exists and does not throw", function()
        test.expect(utils.clean_require).to.be.a("function")
        utils.clean_require("test_module")
      end)
    end)
  end)
end
