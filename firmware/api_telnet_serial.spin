OBJ
  tcp : "driver_socket"
  
VAR
  long handle
  word listenport
  byte listening

PUB start(cs, sck, si, so, int, xtalout, macptr, ipconfigptr)

  return tcp.start(cs, sck, si, so, int, xtalout, macptr, ipconfigptr)

PUB stop

  tcp.stop

PUB connect(ip, remoteport, localport)

  listening := false
  close
  return (handle := tcp.connect(ip, remoteport, localport))

PUB listen(port)

  listenport := port
  listening := true
  close
  return (handle := tcp.listen(listenport))

PUB isConnected

  if handle=>0
    return tcp.isConnected(handle)
  return FALSE
PUB isEOF

  return tcp.isEOF(handle)

PUB resetBuffers

  if handle=>0
    tcp.resetBuffers(handle)

PUB waitConnectTimeout(ms) | t

  t := cnt
  repeat until isConnected or (((cnt - t) / (clkfreq / 1000)) > ms)
    if listening
      ifnot tcp.isValidHandle(handle)
        listen(listenport)

PUB close

  if handle=>0
    tcp.close(handle)
PUB closeAll

  tcp.closeAll

PUB rxflush

  repeat while rxcheck => 0

PUB rxcheck

  if listening
    if tcp.isEOF(handle)
      listen(listenport)

  return tcp.readByteNonBlocking(handle)

PUB rxtime(ms) : rxbyte | t
  rxbyte:=-1
  t := cnt
  if handle=>0
    repeat until (rxbyte := rxcheck) => 0 or (cnt - t) / (clkfreq / 1000) > ms

PUB rx : rxbyte

  repeat while (rxbyte := rxcheck) < 0

PUB txcheck(txbyte)

  if listening
    ifnot tcp.isValidHandle(handle)
      listen(listenport)

  return tcp.writeByteNonBlocking(handle, txbyte)
  
PUB tx(txbyte)

  repeat while isConnected and (txcheck(txbyte) < 0)

PUB txxml(txbyte)
  case txbyte
    "'": str(string("&apos;"))
    "&": str(string("&amp;"))
    other: tx(txbyte)
    

PUB txurl(txbyte)
  case txbyte
    "'","#","&",">","<",0..15:
      tx("%")
      hex(txbyte,2)
    other:
      tx(txbyte)

PUB str(stringptr)                

  repeat strsize(stringptr)
    tx(byte[stringptr++])    

PUB strurl(stringptr)                

  repeat strsize(stringptr)
    txurl(byte[stringptr++])    
PUB strxml(stringptr)                

  repeat strsize(stringptr)
    txxml(byte[stringptr++])    
PUB txip(ip_ptr)
  dec(byte[ip_ptr][3])
  tx(".")
  dec(byte[ip_ptr][2])
  tx(".")
  dec(byte[ip_ptr][1])
  tx(".")
  dec(byte[ip_ptr][0])
PUB txmimeheader(name,value)
  str(name)
  str(string(": "))
  str(value)
  str(string(13,10))
PUB dec(value) | i

'' Print a decimal number

  if value < 0
    -value
    tx("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      tx(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      tx("0")
    i /= 10

PUB readDec | i,char, retVal

  retVal:=0
  repeat 8
    case (char := rx)
      "0".."9":
        retVal:=retVal*10+char-"0"
      " ":
        if retVal<>0
          return retVal
      OTHER:
        return retVal
  return retVal 
PUB hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    tx(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PUB bin(value, digits)

'' Print a binary number

  value <<= 32 - digits
  repeat digits
    tx((value <-= 1) & 1 + "0")