local crypto = require("crypto")
require("test")

---@param test Test
return function(test)
  local describe, it, expect = test.describe, test.it, test.expect

  describe("CryptoHash", function()
    local test_string = "Hello, World!"

    it("sha2_256 produces correct hash", function()
      local result = crypto.hash("sha2_256", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(64)
      expect(result).to.equal("dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
    end)

    it("sha3_256 produces correct hash", function()
      local result = crypto.hash("sha3_256", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(64)
    end)

    it("sha2_512 produces correct hash", function()
      local result = crypto.hash("sha2_512", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(128)
    end)

    it("sha3_512 produces correct hash", function()
      local result = crypto.hash("sha3_512", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(128)
    end)

    it("produces deterministic hashes", function()
      local a = crypto.hash("sha2_256", "test")
      local b = crypto.hash("sha2_256", "test")
      expect(a).to.equal(b)
    end)

    it("different inputs produce different hashes", function()
      local a = crypto.hash("sha2_256", "hello")
      local b = crypto.hash("sha2_256", "world")
      expect(a).to_not.equal(b)
    end)

    it("invalid_hash_type returns empty string", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = crypto.hash("invalid_type", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(0)
    end)

    it("empty_string produces valid hash", function()
      local result = crypto.hash("sha2_256", "")
      expect(result).to.be.a("string")
      expect(#result).to.equal(64)
    end)
  end)

  describe("CryptoBase64", function()
    local test_string = "Hello, World!"

    it("encode produces correct base64 string", function()
      local result = crypto.base64.encode(test_string)
      expect(result).to.be.a("string")
      expect(result).to.equal("SGVsbG8sIFdvcmxkIQ==")
    end)

    it("decode returns original string", function()
      local encoded = "SGVsbG8sIFdvcmxkIQ=="
      local result = crypto.base64.decode(encoded)
      expect(result).to.be.a("string")
      expect(result).to.equal(test_string)
    end)

    it("encode_decode_roundtrip preserves data", function()
      local encoded = crypto.base64.encode(test_string)
      local decoded = crypto.base64.decode(encoded)
      expect(decoded).to.equal(test_string)
    end)

    it("encode_urlsafe produces correct URL-safe base64", function()
      local result = crypto.base64.encode_urlsafe(test_string)
      expect(result).to.be.a("string")
      expect(result).to.equal("SGVsbG8sIFdvcmxkIQ==")
    end)

    it("encode_urlsafe roundtrip preserves data", function()
      local encoded = crypto.base64.encode_urlsafe(test_string)
      local decoded = crypto.base64.decode_urlsafe(encoded)
      expect(decoded).to.equal(test_string)
    end)

    it("decode_urlsafe decodes standard base64", function()
      local encoded = "SGVsbG8sIFdvcmxkIQ=="
      local result = crypto.base64.decode_urlsafe(encoded)
      expect(result).to.be.a("string")
      expect(result).to.equal(test_string)
    end)

    it("invalid_decode throws error", function()
      expect(function()
        crypto.base64.decode("invalid_base64!!!")
      end).to.fail()
    end)
  end)
end
