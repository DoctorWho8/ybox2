OBJ
'  tcp : "shove"
  tcp : "driver_socket"
  
VAR
  long _handle
  word listenport
  byte listening

PUB start(cs, sck, si, so, int, xtalout)
  _handle:=-1
  listening:=0
  listenport:=0
  return tcp.start(cs, sck, si, so, int, xtalout)

PUB stop
  tcp.stop

PUB handle
  return _handle

PUB connect(ip, remoteport, localport)
  listening := false
  close

  return (_handle := tcp.connect(ip, remoteport, localport))

PUB listen(port)
  listenport := port
  listening := true
  close
  _handle := tcp.listen(listenport)
  return _handle

PUB isConnected
  if _handle=>0
    return tcp.isConnected(_handle)
  return false

PUB isEOF
  return tcp.isEOF(_handle)

PUB waitConnectTimeout(ms) | t
  t := cnt
  repeat until isConnected or (((cnt - t) / (clkfreq / 1000)) > ms)
    if listening
      ifnot tcp.isValidHandle(_handle)
        listen(listenport)
  return isConnected
  
PUB close
  if _handle=>0
    \tcp.close(_handle)
    _handle:=-1

PUB closeAll
  listening:=0
  listenport:=0
  _handle:=-1
  \tcp.closeAll

PUB rxflush
  repeat while rxcheck => 0

PUB rxcheck
  if listening
    if tcp.isEOF(_handle)
      listen(listenport)
  return tcp.readByteNonBlocking(_handle)

{
PUB rxdata(ptr,len)
  if isConnected
    return tcp.readData(handle,ptr,len)
  return -1
}

PUB rxtime(ms) : rxbyte
  rxbyte:=-1
  if _handle=>0
    rxbyte:=tcp.readByteTimeout(_handle,ms)

PUB rx
  return tcp.readByte(_handle)

PUB txcheck(txbyte)
  if listening
    ifnot tcp.isValidHandle(_handle)
      listen(listenport)
  return tcp.writeByteNonBlocking(_handle, txbyte)
  
PUB tx(txbyte)
  repeat while isConnected and (txcheck(txbyte) < 0)

PUB txdata(ptr,len)
  if isConnected
    return tcp.writeData(handle,ptr,len)
  return -1

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
  txdata(stringptr,strsize(stringptr))

PUB strurl(stringptr)
  repeat strsize(stringptr)
    txurl(byte[stringptr++])

PUB strxml(stringptr) 
  repeat strsize(stringptr)
    txxml(byte[stringptr++])    

PUB txip(ip_ptr)
  dec(byte[ip_ptr][0])
  tx(".")
  dec(byte[ip_ptr][1])
  tx(".")
  dec(byte[ip_ptr][2])
  tx(".")
  dec(byte[ip_ptr][3])

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
