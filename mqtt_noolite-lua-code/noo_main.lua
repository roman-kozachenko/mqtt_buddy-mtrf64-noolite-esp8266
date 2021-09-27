-- Require
noo_wifi = require("noo_wifi")
noo_uart = require("noo_uart")
creds = require("credentials")
noo_mqtt = require("noo_mqtt")

-- Setup
noo_wifi.setup(creds.SSID, creds.PASSWORD, function()
    print('start connection to mqtt')
    noo_mqtt.client:connect(creds.MQTT_SERVER, creds.MQTT_SERVER_PORT, 0,
                            function(conn)

        -- reconnect each hours to mqtt
        -- milisesonds N = 1000 milisesonds * 60 = minutes
        -- reconnect each hour
        tmr.alarm(5, 3600000, tmr.ALARM_AUTO, noo_mqtt.reconnect)

        noo_mqtt.register_myself()
        noo_uart.start(noo_mqtt.log, noo_mqtt.getLastAction)
    end)
end)
