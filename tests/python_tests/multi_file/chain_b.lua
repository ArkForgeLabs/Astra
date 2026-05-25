local chr, ord, str, int = string.char, string.byte, tostring, tonumber
if not table.unpack then table.unpack = unpack end
function b_func()
    return "from B"
end
return { b_func = b_func }
