---@meta

local crypto = {}

---Hashes a given string according to the provided hash type.
---@param hash_type "sha2_256"|"sha3_256"|"sha2_512"|"sha3_512"
---@param input string The input to be hashed
---@return string
function crypto.hash(hash_type, input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__hash(hash_type, input)
end

crypto.base64 = {}

---Encodes the given input as Base64
---@param input string The input to be encoded
---@return string
function crypto.base64.encode(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__base64_encode(input)
end

---Encodes the given input as Base64 but URL safe
---@param input string The input to be encoded
---@return string
function crypto.base64.encode_urlsafe(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__base64_encode_urlsafe(input)
end

---Decodes the given input as Base64
---@param input string The input to be decoded
---@return string
function crypto.base64.decode(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__base64_decode(input)
end

---Decodes the given input as Base64 but URL safe
---@param input string The input to be decoded
---@return string
function crypto.base64.decode_urlsafe(input)
  ---@diagnostic disable-next-line: undefined-global
  return astra_internal__base64_decode_urlsafe(input)
end

return crypto
