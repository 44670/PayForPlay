r = node.restart


pinCoin = 1
pinLcdCS = 2
pinLcdCLK = 5
pinLcdDAT = 7
pinLcdSDA = 5
pinLcdSCL = 7

i2c.setup(0, pinLcdSDA, pinLcdSCL, i2c.SLOW)
lcd = dofile("lcd1602.lua")(0x3f)
lcd:put(lcd:locate(0, 0), "Hello")
lcd:light(true)


PWD='defaultpwd'
dofile('secrets.lua')

timeLimit = 120
initialSecondsPerCoin = 3600
secondsPerCoin = initialSecondsPerCoin
resumePriceCounter = 0
freePlay = false
isWifiConnected = false


srv=net.createServer(net.TCP) 
srv:listen(90,function(conn) 
    local ret = timeLimit
    if freePlay then
        ret = -1
    end
    conn:send(string.format("%d", ret))
    conn:close()
end)

srvAdmin=net.createServer(net.TCP) 
srvAdmin:listen(91,function(conn) 
    conn:on("sent", function(conn)
        conn:close()
    end)
    conn:on("receive",function(conn,payload) 
        local ret = 'error'
        if string.sub(payload, 1, string.len(PWD)) == PWD then
            local cmd = string.sub(payload, string.len(PWD) + 1)
            if cmd == 'free' then
                freePlay = true
                ret = 'ok'
            else
                if cmd == 'nofree' then
                    freePlay = false
                    ret = 'ok'
                end  
            end
        end
        conn:send(ret)
    end)
end)

tmr.create():alarm(1000, tmr.ALARM_AUTO, function() 
    if isWifiConnected == false then
        if wifi.sta.getip() ~= nil then
            isWifiConnected = true
        end
    end
    if timeLimit > 0 then
        timeLimit = timeLimit - 1
        resumePriceCounter = 0
    else
        if secondsPerCoin ~= initialSecondsPerCoin then
            resumePriceCounter = resumePriceCounter + 1
            if resumePriceCounter > 1200 then
                secondsPerCoin = initialSecondsPerCoin
            end
        end
    end
    updateLcdStatusText()
end)

coinTimer = tmr.create()
gpio.mode(pinCoin, gpio.INT, gpio.PULLUP)
gpio.trig(pinCoin, 'down', function()
    coinTimer:alarm(10, tmr.ALARM_SINGLE, function() 
        if (gpio.read(pinCoin) == 0) then
            handleCoinSignal()
        end
    end)
end)

function handleCoinSignal() 
    if freePlay then
        return
    end
    timeLimit = timeLimit + secondsPerCoin
    if secondsPerCoin > (3600 / 8)  then
        secondsPerCoin = secondsPerCoin / 2
    end
    updateLcdStatusText()
end


function updateLcdStatusText() 
    if freePlay then
        lcd:put(lcd:locate(0, 0), "FREE PLAY!!!    ", lcd:locate(1, 0), "    FREE PLAY!!!")
        return
    end
    lcd:put(lcd:locate(0, 0), string.format('Price:%2dmin/coin ', secondsPerCoin / 60 % 99), 
        lcd:locate(1, 0), string.format('Time :%4dmin   ', timeLimit / 60 % 9999))
end

