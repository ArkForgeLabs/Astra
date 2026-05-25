local chr, ord, str, int = string.char, string.byte, tostring, tonumber
if not table.unpack then table.unpack = unpack end
function greet(name)
    return "Hello, " .. tostring(name) .. "!"
end
return { greet = greet }
