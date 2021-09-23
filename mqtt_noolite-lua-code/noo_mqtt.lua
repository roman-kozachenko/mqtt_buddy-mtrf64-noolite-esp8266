-- Require
wifiModule = require("noo_wifi")
parserModule = require("parsers")
uartModule = require("noo_uart")
commands = require("byte_commands")
db = require("storage")

-- Credentials
SSID = "Damavik 178"
PASSWORD = "6775069a"
MQTT_SERVER = "192.168.0.67"
MQTT_SERVER_PORT = 1883
MQTT_USER = ""
MQTT_PASS = ""

local LAST_ACTION

m = mqtt.Client("MQTT_BUDDY_ESP", 120, MQTT_USER, MQTT_PASS)

function logToMqtt(message)
    m:publish("mqtt_buddy/sys",message, 0, 0)
end
-- mqtt
function register_myself()  
    print('start register_myself')
    m:subscribe("mqtt_buddy/noolight/#", 0, function(conn) 
    print ("subscribed to MQTT server")
    logToMqtt( 'subscribed to MQTT server');
    end)
end

function handle_mqtt_connection_error(client, reason)
    tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, reconnect_mqtt)
  end

function reconnect_mqtt()
    print('reconnect mqtt')
    m:connect(MQTT_SERVER, MQTT_SERVER_PORT, 0, function(conn) register_myself() end, handle_mqtt_connection_error) 
end


m:on("connect", function(client) print ("connected MQTT server") end)
m:on("offline", function(client) reconnect_mqtt() end)
m:on("message", function(client, topic, data)
    channel, action = parserModule.split_topic(topic)
    LAST_ACTION = action
    logToMqtt("recieved: action: " .. action .. " channel:" .. channel)
    if tonumber(channel) ~= nil then
        if action == 'bind' then uart.write(0, commands.bind(channel))
        elseif action == 'unbind' then uart.write(0, commands.unbind(channel))
        elseif action:match("^%d+-%d+-%d+-%d+") ~= nil then
            id1, id2, id3, id4 = parserModule.split_address(action)
            LAST_ACTION = 'addr_switch'
            if data == 'switch' then uart.write(0, commands.switch(8, channel, id1, id2, id3, id4))
            elseif data == 'on' then uart.write(0, commands.on(8, channel, id1, id2, id3, id4))
            elseif data == 'off' then uart.write(0, commands.off(8, channel, id1, id2, id3, id4))
            elseif data == 'state' then uart.write(0, commands.state(8, channel, id1, id2, id3, id4))
            end
        elseif action == 'chan_switch' then
            if data == 'switch' then uart.write(0, commands.switch(0, channel, 0, 0, 0, 0))
            elseif data == 'on' then uart.write(0, commands.on(0, channel, 0, 0, 0, 0))
            elseif data == 'off' then uart.write(0, commands.off(0, channel, 0, 0, 0, 0))
            elseif data == 'state' then uart.write(0, commands.state(0, channel, 0, 0, 0, 0))
            end
        elseif action == 'devices' and data == 'GET' then
            devices = db.get_devices(channel)
            if devices then logToMqtt(devices) else logToMqtt('no devices bound') end
        elseif action == 'ping' then
            logToMqtt('pong')
        end
    end
end)


function setupUart()
    print('start connection to uart')

    uartModule.setup(function () logToMqtt('uart setup complete') end)

    uart.on("data", 17,
        function(data)
            local rx_a = ''
            local rx_b = ''
            for i = 1, 17 do
                c = data:sub(i, i)
                if i < 9 then
                    rx_a = rx_a..string.byte(c)..':'
                elseif i >= 9 then
                    rx_b = rx_b..string.byte(c)..':'
                end
            end
            
            answer_code, channel, cmd = parserModule.split_rx_a(rx_a)
            data3, id1, id2, id3, id4 = parserModule.split_rx_b(rx_b)

            m:publish("mqtt_buddy/sys", 'mtrf64> received RX '..rx_a..rx_b, 0, 0)

            -- answer_code=3 means bind success
            if answer_code == '3' then  
                m:publish("mqtt_buddy/sys", 'mtrf64> BINDING. chan '..channel..' addr '..id1..':'..id2..':'..id3..':'..id4, 0, 0)
                db.add_device(channel, id1, id2, id3, id4)
                m:publish("mqtt_buddy/sys", 'mtrf64> BINDED', 0, 0)
            -- data 192 or 193 while unbinding means unbind success
            -- more specific we are interested in the 6th bit
            -- 11000001
            -- ^         service mode enabled
            --  ^        unbind seccess
            --        ^  device on/off (0/1)
            elseif LAST_ACTION == 'unbind' and (data3 == '192' or data3 == '193') then
                m:publish("mqtt_buddy/sys", 'mtrf64> UNBINDING> chan '..channel..' addr '..id1..':'..id2..':'..id3..':'..id4, 0, 0)
                db.remove_device(channel, id1, id2, id3, id4)
                m:publish("mqtt_buddy/sys", 'mtrf64> UNBINDED', 0, 0)
            end
    end, 0)

end

-- Setup
wifiModule.setup(SSID, PASSWORD, function() 
    print('start connection to mqtt')
    m:connect(MQTT_SERVER, MQTT_SERVER_PORT, 0, function(conn) 
        register_myself()
        setupUart()
     end) 
    
end)


-- reconnect each hours to mqtt
-- milisesonds N = 1000 milisesonds * 60 = minutes
-- reconnect each hour
tmr.alarm(5, 3600000, tmr.ALARM_AUTO, function() reconnect_mqtt() end)
