local chr, ord, str, int = string.char, string.byte, tostring, tonumber
if not table.unpack then table.unpack = unpack end
local chain_b = require('chain_b')
function a_func()
    return chain_b:b_func()
end
return { a_func = a_func, chain_b = chain_b }
