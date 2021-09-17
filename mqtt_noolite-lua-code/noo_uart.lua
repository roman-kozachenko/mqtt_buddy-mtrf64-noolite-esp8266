local noo_uart = {}

-- use alternate pins GPIO13 and GPIO15 and setup serial port
function noo_uart.setup(onComplete)
    uart.alt(1)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)    
    onComplete()
end

return noo_uart
