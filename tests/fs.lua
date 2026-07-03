local fs = require("fs")
require("test")

---@param test Test
return function(test)
  test.paths.falsy = {
    test = function(value)
      local ok = (value == false)
      return ok, "expected " .. tostring(value) .. " to be falsy", "expected " .. tostring(value) .. " to not be falsy"
    end,
  }
  table.insert(test.paths.be, "falsy")

  test.paths.most = {
    test = function(value, max)
      return value <= max,
        "expected " .. tostring(value) .. " to be at most " .. tostring(max),
        "expected " .. tostring(value) .. " to not be at most " .. tostring(max)
    end,
  }
  table.insert(test.paths.be, "most")

  test.paths.at = {
    least = test.paths.least,
    most = test.paths.most,
  }
  table.insert(test.paths.be, "at")

  fs.create_dir("FS_TEST_DIR")
  test.describe("Filesystem Module", function()
    test.describe("Buffer Operations", function()
      test.it("creates buffer with capacity and verifies type", function()
        local buffer = fs.new_buffer(100)
        test.expect(buffer).to.be.truthy()
      end)

      test.it("creates buffer with small capacity and verifies type", function()
        local buffer = fs.new_buffer(10)
        test.expect(buffer).to.be.truthy()
      end)
    end)

    test.describe("File Operations", function()
      test.it("creates and writes file and reads content back", function()
        local content = "Hello, World!"
        fs.write_file("FS_TEST_DIR/test.txt", content)

        local read_content = fs.read_file("FS_TEST_DIR/test.txt")
        test.expect(read_content).to.equal(content)
      end)

      test.it("reads file as bytes and verifies length", function()
        local content = "Hello, World!"
        fs.write_file("FS_TEST_DIR/test.txt", content)

        local bytes = fs.read_file_bytes("FS_TEST_DIR/test.txt")
        test.expect(bytes).to.be.a("table")
        test.expect(#bytes).to.equal(#content)
        test.expect(bytes[1]).to.be.a("number")
        test.expect(bytes[1]).to.equal(string.byte("H"))
      end)

      test.it("handles file not found", function()
        local success, err = pcall(function()
          fs.read_file("FS_TEST_DIR/nonexistent.txt")
        end)
        test.expect(success).to.be.falsy()
      end)
    end)

    test.describe("Directory Operations", function()
      test.it("creates directory and verifies it exists", function()
        if fs.exists("FS_TEST_DIR/subdir") then
          fs.remove_dir("FS_TEST_DIR/subdir")
        end
        fs.create_dir("FS_TEST_DIR/subdir")
        test.expect(fs.exists("FS_TEST_DIR/subdir")).to.be.truthy()
      end)

      test.it("creates nested directories and verifies deepest", function()
        fs.create_dir_all("FS_TEST_DIR/a/b/c")
        test.expect(fs.exists("FS_TEST_DIR/a/b/c")).to.be.truthy()
      end)

      test.it("lists directory contents with expected entries", function()
        fs.write_file("FS_TEST_DIR/file1.txt", "content1")
        fs.write_file("FS_TEST_DIR/file2.txt", "content2")

        local entries = fs.read_dir("FS_TEST_DIR")
        test.expect(entries).to.be.a("table")
        test.expect(#entries).to.be.least(2)
      end)

      test.it("removes directory and verifies it no longer exists", function()
        fs.create_dir("FS_TEST_DIR/tmp")
        test.expect(fs.exists("FS_TEST_DIR/tmp")).to.be.truthy()

        fs.remove_dir("FS_TEST_DIR/tmp")
        test.expect(fs.exists("FS_TEST_DIR/tmp")).to.be.falsy()
      end)

      test.it("removes directory recursively with contents", function()
        fs.create_dir_all("FS_TEST_DIR/nested/a/b")
        fs.write_file("FS_TEST_DIR/nested/file.txt", "content")

        fs.remove_dir_all("FS_TEST_DIR/nested")
        test.expect(fs.exists("FS_TEST_DIR/nested")).to.be.falsy()
      end)
    end)

    test.describe("File Metadata", function()
      test.it("gets file metadata and verifies it exists", function()
        fs.write_file("FS_TEST_DIR/meta.txt", "content")

        local metadata = fs.get_metadata("FS_TEST_DIR/meta.txt")
        test.expect(metadata).to.be.truthy()
      end)

      test.it("checks file existence for existing and missing files", function()
        fs.write_file("FS_TEST_DIR/exists.txt", "content")

        test.expect(fs.exists("FS_TEST_DIR/exists.txt")).to.be.truthy()
        test.expect(fs.exists("FS_TEST_DIR/nonexistent.txt")).to.be.falsy()
      end)
    end)

    test.describe("Path Operations", function()
      test.it("gets current directory as non-empty string", function()
        local current_dir = fs.get_current_dir()
        test.expect(current_dir).to.be.a("string")
        test.expect(#current_dir > 0).to.be.truthy()
      end)

      test.it("gets path separator as single character", function()
        local separator = fs.get_separator()
        test.expect(separator).to.be.a("string")
        test.expect(#separator).to.equal(1)
      end)

      test.it("gets script path as non-empty string", function()
        local script_path = fs.get_script_path()
        test.expect(script_path).to.be.a("string")
        test.expect(#script_path > 0).to.be.truthy()
      end)

      test.it("changes directory and verifies new location", function()
        local original_dir = fs.get_current_dir()

        if fs.exists("FS_TEST_DIR/chdir_test") then
          fs.remove_dir_all("FS_TEST_DIR/chdir_test")
        end

        fs.create_dir("FS_TEST_DIR/chdir_test")
        fs.change_dir("FS_TEST_DIR/chdir_test")

        local new_dir = fs.get_current_dir()
        test.expect(new_dir).to.match("chdir_test$")

        fs.change_dir(original_dir)
      end)
    end)

    test.describe("File Permissions", function()
      test.it("gets file permissions metadata", function()
        fs.write_file("FS_TEST_DIR/permissions.txt", "content")

        local metadata = fs.get_metadata("FS_TEST_DIR/permissions.txt")
        test.expect(metadata).to.be.truthy()
      end)
    end)
  end)

  fs.remove_dir_all("FS_TEST_DIR")
end
