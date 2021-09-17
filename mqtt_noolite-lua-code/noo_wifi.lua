local noo_wifi = {}

-- WIFI setup
function noo_wifi.setup(name, pass, whenConnected)

    wifi.setmode(wifi.STATION)
    wifi.sta.config(name, pass)


    -- station_cfg={}
    -- station_cfg.ssid=name
    -- station_cfg.pwd=pass
    -- station_cfg.save=true
    -- wifi.sta.config(station_cfg)

    wifi.sta.connect()
    
    tmr.alarm(0, 1000, 1, function() 
            if wifi.sta.getip() == nil then 
                print("IP unavaiable, Waiting...")                                 
            else 
                tmr.stop(0)
                print("Config done, IP is "..wifi.sta.getip())
                print("mac : "..wifi.sta.getmac())
                whenConnected()
            end 
    end)
end
return noo_wifi
