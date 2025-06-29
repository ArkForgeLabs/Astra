---@meta

Astra.crypto = {}

---Hashes a given string according to the provided hash type.
---@param hash_type "sha2_256"|"sha3_256"|"sha2_512"|"sha3_512"
---@param input string The input to be hashed
---@return string
function Astra.crypto.hash(hash_type, input) end

Astra.crypto.base64 = {}

---Encodes the given input as Base64
---@param input string The input to be encoded
---@return string
function Astra.crypto.base64.encode(input) end

---Encodes the given input as Base64 but URL safe
---@param input string The input to be encoded
---@return string
function Astra.crypto.base64.encode_urlsafe(input) end

---Decodes the given input as Base64
---@param input string The input to be decoded
---@return string
function Astra.crypto.base64.decode(input) end

---Decodes the given input as Base64 but URL safe
---@param input string The input to be decoded
---@return string
function Astra.crypto.base64.decode_urlsafe(input) end
