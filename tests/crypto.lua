local test = require("test")
local crypto = require("crypto")
local describe, it, expect = test.describe, test.it, test.expect

describe("CryptoHash", function()
    local test_string = "Hello, World!"

    it("sha2_256", function()
        local result = crypto.hash("sha2_256", test_string)
        expect(result).to.be.a("string")
        expect(#result).to.equal(64) -- SHA256 produces 64 hex characters
    end)

    it("sha3_256", function()
        local result = crypto.hash("sha3_256", test_string)
        expect(result).to.be.a("string")
        expect(#result).to.equal(64) -- SHA3-256 produces 64 hex characters
    end)

    it("sha2_512", function()
        local result = crypto.hash("sha2_512", test_string)
        expect(result).to.be.a("string")
        expect(#result).to.equal(128) -- SHA512 produces 128 hex characters
    end)

    it("sha3_512", function()
        local result = crypto.hash("sha3_512", test_string)
        expect(result).to.be.a("string")
        expect(#result).to.equal(128) -- SHA3-512 produces 128 hex characters
    end)

    it("invalid_hash_type", function()
        -- For now, invalid hash types return an empty string rather than failing
        local result = crypto.hash("invalid_type", test_string)
        expect(result).to.be.a("string")
        expect(result).to.equal(nil)
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
