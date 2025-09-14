---@meta

local base64 = {}

local type astra_internal__base64_encode = function(input: string): string
---Encodes the given input as Base64
function base64.encode(input: string): string
	return astra_internal__base64_encode(input)
end

local type astra_internal__base64_encode_urlsafe = function(input: string): string
---Encodes the given input as Base64 but URL safe
function base64.encode_urlsafe(input: string): string
	return astra_internal__base64_encode_urlsafe(input)
end

local type astra_internal__base64_decode = function(input: string): string
---Decodes the given input as Base64
function base64.decode(input: string): string
	return astra_internal__base64_decode(input)
end

local type astra_internal__base64_decode_urlsafe = function(input: string): string
---Decodes the given input as Base64 but URL safe
function base64.decode_urlsafe(input: string): string
	return astra_internal__base64_decode_urlsafe(input)
end

local crypto = {
    base64 = base64
}

global enum HASH_TYPE
    "sha2_256" "sha3_256" "sha2_512" "sha3_512"
end
local type astra_internal__hash = function(hash_type: HASH_TYPE, input: string): string
---Hashes a given string according to the provided hash type.
function crypto.hash(hash_type: HASH_TYPE, input: string): string
	return astra_internal__hash(hash_type, input)
end

return crypto
