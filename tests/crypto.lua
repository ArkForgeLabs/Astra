local crypto = require("crypto")
require("test")

---@param test Test
return function(test)
  local describe, it, expect = test.describe, test.it, test.expect

  describe("CryptoHash", function()
    local test_string = "Hello, World!"

    local hash_algos = {
      { name = "sha2_256", length = 64 },
      { name = "sha3_256", length = 64 },
      { name = "sha2_512", length = 128 },
      { name = "sha3_512", length = 128 },
    }
    for _, algo in ipairs(hash_algos) do
      it(algo.name, function()
        local result = crypto.hash(algo.name, test_string)
        expect(result).to.be.a("string")
        expect(#result).to.equal(algo.length)
      end)
    end

    it("invalid_hash_type", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = crypto.hash("invalid_type", test_string)
      expect(result).to.be.a("string")
      expect(#result).to.equal(0)
    end)

    it("empty_string", function()
      local result = crypto.hash("sha2_256", "")
      expect(result).to.be.a("string")
      expect(#result).to.equal(64)
    end)
  end)

  describe("CryptoBase64", function()
    local test_string = "Hello, World!"

    it("encode", function()
      local result = crypto.base64.encode(test_string)
      expect(result).to.be.a("string")
    end)

    it("decode", function()
      local encoded = "SGVsbG8sIFdvcmxkIQ=="
      local result = crypto.base64.decode(encoded)
      expect(result).to.be.a("string")
      expect(result).to.equal(test_string)
    end)

    it("encode_decode_roundtrip", function()
      local encoded = crypto.base64.encode(test_string)
      local decoded = crypto.base64.decode(encoded)
      expect(decoded).to.equal(test_string)
    end)

    it("encode_urlsafe", function()
      local result = crypto.base64.encode_urlsafe(test_string)
      expect(result).to.be.a("string")
    end)

    it("decode_urlsafe", function()
      local encoded = "SGVsbG8sIFdvcmxkIQ=="
      local result = crypto.base64.decode_urlsafe(encoded)
      expect(result).to.be.a("string")
      expect(result).to.equal(test_string)
    end)

    it("invalid_decode", function()
      expect(function()
        crypto.base64.decode("invalid_base64!!!")
      end).to.fail()
    end)
  end)
end
