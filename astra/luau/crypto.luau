--!nocheck
--!nolint

type HashType = "sha2_256" | "sha3_256" | "sha2_512" | "sha3_512"

local crypto = {}

--- Hashes a given string according to the provided hash type.
function crypto.hash(hash_type: HashType, input: string): string
  return astra_internal__hash(hash_type, input)
end

crypto.base64 = {}

--- Encodes the given input as Base64
function crypto.base64.encode(input: string): string
  return astra_internal__base64_encode(input)
end

--- Encodes the given input as Base64 but URL safe
function crypto.base64.encode_urlsafe(input: string): string
  return astra_internal__base64_encode_urlsafe(input)
end

--- Decodes the given input as Base64
function crypto.base64.decode(input: string): string
  return astra_internal__base64_decode(input)
end

--- Decodes the given input as Base64 but URL safe
function crypto.base64.decode_urlsafe(input: string): string
  return astra_internal__base64_decode_urlsafe(input)
end

return crypto
