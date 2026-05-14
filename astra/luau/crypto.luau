--!strict

type HashType = "sha2_256" | "sha3_256" | "sha2_512" | "sha3_512"

local astra_internal__hash: (hash_type: HashType, input: string) -> string
local astra_internal__base64_encode: (input: string) -> string
local astra_internal__base64_encode_urlsafe: (input: string) -> string
local astra_internal__base64_decode: (input: string) -> string
local astra_internal__base64_decode_urlsafe: (input: string) -> string

local crypto: {
  hash: (hash_type: HashType, input: string) -> string,
  base64: {
    encode: (input: string) -> string,
    encode_urlsafe: (input: string) -> string,
    decode: (input: string) -> string,
    decode_urlsafe: (input: string) -> string,
  },
} = {
  hash = function(hash_type: HashType, input: string): string
    return astra_internal__hash(hash_type, input)
  end,
  base64 = {
    encode = function(input: string): string
      return astra_internal__base64_encode(input)
    end,
    encode_urlsafe = function(input: string): string
      return astra_internal__base64_encode_urlsafe(input)
    end,
    decode = function(input: string): string
      return astra_internal__base64_decode(input)
    end,
    decode_urlsafe = function(input: string): string
      return astra_internal__base64_decode_urlsafe(input)
    end,
  },
}

return crypto
