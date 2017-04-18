r = node.restart

pinCoin = 1
pinLcdCS = 2
pinLcdCLK = 5
pinLcdDAT = 7

PWD='defaultpwd'
dofile('secrets.lua')

timeLimit = 120
initialSecondsPerCoin = 3600
secondsPerCoin = initialSecondsPerCoin
resumePriceCounter = 0
freePlay = false
isTimeValid = false
isWifiConnected = false

function handleFirstTimeWifiConnected() 
    sntp.sync(nil, function()
        if (isTimeValid == false) then
            isTimeValid = true
        end
    end, nil, 1)
end

function localTime() 
    rtctime.epoch2cal(rtctime.get() + 8 * 3600)
end

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
            handleFirstTimeWifiConnected()
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
    if isTimeValid == false then
        return
    end
    timeLimit = timeLimit + secondsPerCoin
    if secondsPerCoin > (3600 / 8)  then
        secondsPerCoin = secondsPerCoin / 2
    end
    updateLcdStatusText()
end

function updateLcdStatusText() 
    lcdDotFlag[2] = 0
    if freePlay then
        updateLcd('FREE')
        return
    end
    if isTimeValid == false then
        updateLcd('----')
        return
    end
    lcdDotFlag[2] = 1
    updateLcd(string.format('%d%03d', (3600 / secondsPerCoin) % 10, (timeLimit / 60) % 1000))
end


gpio.mode(pinLcdCS, gpio.OUTPUT)
gpio.mode(pinLcdCLK, gpio.OUTPUT)
gpio.mode(pinLcdDAT, gpio.OUTPUT)
gpio.write(pinLcdCS, 1)


function ht1621SetCS(val)
	gpio.write(pinLcdCS, val)
end

function ht1621WriteBit(dat)
    gpio.write(pinLcdDAT, dat)
    gpio.write(pinLcdCLK, 0); tmr.delay(50)
    gpio.write(pinLcdCLK, 1); tmr.delay(50)
    gpio.write(pinLcdCLK, 0); tmr.delay(50)
end

function ht1621WriteByte(byte, len)
    for i = len - 1, 0, -1 do
        if (bit.isset(byte, i)) then
            ht1621WriteBit(1)
        else
            ht1621WriteBit(0)
        end
    end
end

function ht1621WriteCommand(cmd)
    ht1621SetCS(0)
    ht1621WriteBit(1)
    ht1621WriteBit(0)
    ht1621WriteBit(0)
    ht1621WriteByte(cmd, 8)
    ht1621WriteBit(0)
    ht1621SetCS(1)
    tmr.delay(50)
end

function ht1621WriteData(data, len)
    ht1621SetCS(0)
    ht1621WriteBit(1)
    ht1621WriteBit(0)
    ht1621WriteBit(1)
    ht1621WriteByte(0, 6)
    for i = 1, len do
        ht1621WriteByte(data[i], 8)
    end
    ht1621SetCS(1)
    tmr.delay(50)
end

font = {
    F = 0xe4,
    R = 0xEE,
    E = 0xe5,
    ['1'] = 0x0A,
    ['2'] = 0xad,
    ['3'] = 0x8f,
    ['4'] = 0x4e,
    ['5'] = 0xc7,
    ['6'] = 0xe7,
    ['7'] = 0xca,
    ['8'] = 0xef,
    ['9'] = 0xcf,
    ['0'] = 0xeb,
    ['-'] = 0x04,
    [' '] = 0x00
}

lcdBuf = {0, 0, 0, 0}
lcdDotFlag = {0, 0, 0, 0}

function updateLcd(str)
    local v
    for i = 1, 4 do
        v = font[string.sub(str, i, i)]
        if (v == nil) then
            v = 0
        end
        if (lcdDotFlag[i] > 0) then
            v = v + 0x10
        end
        lcdBuf[i] = v
        
    end
    ht1621WriteData(lcdBuf, 4)
end

ht1621WriteCommand(0x18);   	--RC 256K
ht1621WriteCommand(0x00);
ht1621WriteCommand(0x01);   	--turn on system oscilator 
ht1621WriteCommand(0x03);   	--turn on bias generator
ht1621WriteCommand(0x29);   	--1/3 bias 4 commons//    1/2 bias 3 commons//0x04

updateLcd('----')

