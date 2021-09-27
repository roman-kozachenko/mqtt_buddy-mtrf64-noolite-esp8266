local creds = require("credentials");
local parserModule = require("parsers")
local commands = require("byte_commands")
local db = require("storage")

local LAST_ACTION

local noo_mqtt = {}
local mclient = mqtt.Client("MQTT_BUDDY_ESP", 120, creds.MQTT_USER,
                            creds.MQTT_PASS)

noo_mqtt.client = mclient

function noo_mqtt.log(message)
    mclient:publish("mqtt_buddy/sys", message, 0, 0)
end

function noo_mqtt.register_myself()
    print('start register_myself')
    mclient:subscribe("mqtt_buddy/noolight/#", 0, function(conn)
        print("subscribed to MQTT server")
        log('subscribed to MQTT server');
    end)
end

function handle_mqtt_connection_error(client, reason)
    tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, reconnect)
end

function noo_mqtt.reconnect()
    print('reconnect mqtt')
    mclient:connect(creds.MQTT_SERVER, creds.MQTT_SERVER_PORT, 0,
                    function(conn) register_myself() end,
                    handle_mqtt_connection_error)
end

mclient:on("connect", function(client) print("connected MQTT server") end)
mclient:on("offline", function(client) reconnect() end)
mclient:on("message", function(client, topic, data)
    channel, action = parserModule.split_topic(topic)
    LAST_ACTION = action
    log("recieved: action: " .. action .. " channel:" .. channel)
    if tonumber(channel) ~= nil then
        if action == 'bind' then
            uart.write(0, commands.bind(channel))
        elseif action == 'unbind' then
            uart.write(0, commands.unbind(channel))
        elseif action:match("^%d+-%d+-%d+-%d+") ~= nil then
            id1, id2, id3, id4 = parserModule.split_address(action)
            LAST_ACTION = 'addr_switch'
            if data == 'switch' then
                uart.write(0, commands.switch(8, channel, id1, id2, id3, id4))
            elseif data == 'on' then
                uart.write(0, commands.on(8, channel, id1, id2, id3, id4))
            elseif data == 'off' then
                uart.write(0, commands.off(8, channel, id1, id2, id3, id4))
            elseif data == 'state' then
                uart.write(0, commands.state(8, channel, id1, id2, id3, id4))
            end
        elseif action == 'chan_switch' then
            if data == 'switch' then
                uart.write(0, commands.switch(0, channel, 0, 0, 0, 0))
            elseif data == 'on' then
                uart.write(0, commands.on(0, channel, 0, 0, 0, 0))
            elseif data == 'off' then
                uart.write(0, commands.off(0, channel, 0, 0, 0, 0))
            elseif data == 'state' then
                uart.write(0, commands.state(0, channel, 0, 0, 0, 0))
            end
        elseif action == 'devices' and data == 'GET' then
            devices = db.get_devices(channel)
            if devices then
                log(devices)
            else
                log('no devices bound')
            end
        elseif action == 'ping' then
            log('pong')
        end
    end
end)

return noo_mqtt
