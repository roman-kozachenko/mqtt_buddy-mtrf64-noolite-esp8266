local creds = require("credentials");
local parserModule = require("parsers")
local commands = require("byte_commands")
local db = require("storage")

local LAST_ACTION

local noo_mqtt = {}
local mclient = mqtt.Client("MQTT_BUDDY_ESP", 120, creds.MQTT_USER,
                            creds.MQTT_PASS)

noo_mqtt.client = mclient

function noo_mqtt.log(message) mclient:publish("mqtt_buddy/sys", message, 0, 0) end

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

function processSwitchCommands(data, writer)
    if data == 'switch' then
        writer(commands.switch)
    elseif data == 'on' then
        writer(commands.on)
    elseif data == 'off' then
        writer(commands.off)
    elseif data == 'state' then
        writer(commands.state)
    end
end

function noo_mqtt.getLastAction() return LAST_ACTION end

function noo_mqtt.writeChannelState(channel, state)
    mclient:publish("noolite/state/" .. channel, state, 0, 0)
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

            processSwitchCommands(data, function(cmd)
                uart.write(0, cmd(8, channel, id1, id2, id3, id4))
            end)

        elseif action == 'chan_switch' then
            processSwitchCommands(data, function(cmd)
                uart.write(0, cmd(0, channel, 0, 0, 0, 0))
            end)
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
