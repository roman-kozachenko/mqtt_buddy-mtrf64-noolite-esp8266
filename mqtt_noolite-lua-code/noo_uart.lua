local parserModule = require("parsers")

local noo_uart = {}

-- use alternate pins GPIO13 and GPIO15 and setup serial port
function noo_uart.setup(onComplete)
    uart.alt(1)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
    onComplete()
end

function noo_uart.start(log, getLastAction, writeChannelState)
    print('start connection to uart')

    uartModule.setup(function() log('uart setup complete') end)

    uart.on("data", 17, function(data)
        local rx_a = ''
        local rx_b = ''
        for i = 1, 17 do
            c = data:sub(i, i)
            if i < 9 then
                rx_a = rx_a .. string.byte(c) .. ':'
            elseif i >= 9 then
                rx_b = rx_b .. string.byte(c) .. ':'
            end
        end

        answer_code, channel, cmd = parserModule.split_rx_a(rx_a)
        data3, id1, id2, id3, id4 = parserModule.split_rx_b(rx_b)

        log('mtrf64> received RXa:' .. rx_a .. ' Rxb:' .. rx_b)
        log('answer_code:' .. answer_code)
        log('channel:' .. channel)
        log('cmd:' .. cmd)
        log('data3:' .. data3)

        local lastAction = getLastAction()

        -- answer_code=3 means bind success
        if answer_code == '3' then
            log("mqtt_buddy/sys",
                'mtrf64> BINDING. chan ' .. channel .. ' addr ' .. id1 .. ':' ..
                    id2 .. ':' .. id3 .. ':' .. id4)
            db.add_device(channel, id1, id2, id3, id4)
            log("mqtt_buddy/sys", 'mtrf64> BINDED')
            -- data 192 or 193 while unbinding means unbind success
            -- more specific we are interested in the 6th bit
            -- 11000001
            -- ^         service mode enabled
            --  ^        unbind seccess
            --        ^  device on/off (0/1)
        elseif lastAction == 'unbind' and (data3 == '192' or data3 == '193') then
            log("mqtt_buddy/sys",
                'mtrf64> UNBINDING> chan ' .. channel .. ' addr ' .. id1 .. ':' ..
                    id2 .. ':' .. id3 .. ':' .. id4)
            db.remove_device(channel, id1, id2, id3, id4)
            log("mqtt_buddy/sys", 'mtrf64> UNBINDED')
        elseif lastAction == 'state' then
            if (data3 == '1') then
                writeChannelState(channel, 'on')
            elseif (data3 == '0') then
                writeChannelState(channel, 'off')
            else
                log('unknown channel state:' .. data3)
            end
        end
    end, 0)

end

return noo_uart
