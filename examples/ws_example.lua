local server = Astra.http.server:new()

---@param socket WebSocket
local function handle_socket(socket)
    while true do
        local message, err = socket:recv()

        if not message then
            print("failed to receive a frame: ", err)
            break
        end
        if message.type == "text" then
            local text = message.data
            if text ~= "controversial take" then
                local _ok, _err = socket:send_text(string.format("I agree with you. '%s' seems reasonable.", text))
            else
                local _ok, _err = socket:send_text("I can't talk with you anymore. Bye.")
                local __ok, __err = socket:send_close({code=1008, reason="The take was too controversial"})
                break
            end
        end
        if message.type == "binary" then
            local byte = string.char(5) -- 0b101
            print("got", message.data)
            local _ok, _err = socket:send_binary(byte)
        end
    end
end

server:ws("/wspath", handle_socket)

server:run()
