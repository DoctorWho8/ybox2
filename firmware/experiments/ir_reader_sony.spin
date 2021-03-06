{{ ir_reader_nec.spin

  Bob Belleville

  This object receives input from an IR remote which
  uses the Sony 12, 15 or 20 bit formats and places valid
  keycodes into a FiFo buffer.  Keycodes can then be removed
  and used in an application.  This buffer is sized below
  by the _qsize CON.  Unless the application goes off
  for a very long time without calling fifo_get, 8 or
  16 bytes is more than enough.

  A single cog is used to watch for input.  A cog, a pin,
  and a single lock bit must be available for this object
  to function.

  basic use is to:
    import this object
    init(pin, 0 or deviceID, repeatDelay, markRepeat)
    key := fifo_get
    if key == -1
      there isn't any new key
    else
      use key to do some thing

  see ir_reader_demo.spin for one example

  to modify for another kind of remote protocol:
    replace get_code/and perhaps get_pair
    
  see readme.pdf for more documentaton

  2007/03/02 - derived ir_reader_nec.spin
  2007/03/03 - various changes

}}
 
CON

        _sml    = 75            'length of a valid start mark pulse
                                '  is at least this long
        _esl    = 45            'length of space at end of sequence
                                '  is at least this long
        _zth    = 27            'space less the _zth is 0 else 1
        _son    = 1000          'mark stuck on (shouldn't happen)
        _rdl    = 5_000_000     'if 80MHZ cnt between code is < _rdl then
                                '  the code is a repeat 
        _qsize  = 8             'must be a power of 2 (2,4,8,16,32,64,128,256 only)
        _qsm1   = _qsize-1      'mask 

VAR

        long    lastvalid       'last valid code
        word    deviceID        'valid input device or
                                '  zero for any
                                '  get using ir_view for example
        long    lastcnt         'CNT at end last valid char
        byte    repeatlag       'ignore this many before
                                '  putting repeats in queue
        byte    repeatmark      'set high bit of repeated keycodes
                                '  if requested                                
        byte    irpin           'which pin to use

                                'fifo for key codes                                
        byte    lock            'hub lock index
        byte    head            'head (put) index for fifo
        byte    tail            'tail (get) index for fifo
        byte    fifo[_qsize]    'buffer itself

        long    stack[20]       'for input cog
        
PUB init(pin, device, repeatdelay, markrepeat) | cog
{{
  pin         - port A input pin where IR receiver module is wired
  device      - 16 bit valid device code or 0 for any NEC device
  repeatdelay - number of repeated input codes to skip before
                adding last valid code to queue
  markrepeat  - true to set high bit of repeated key codes else
                not modified                

  returns cog number if running or -1 if failed              
}}
  irpin     := pin
  deviceID  := device
  repeatlag := repeatdelay
  if markrepeat
    repeatmark := $80
  else
    repeatmark~
  lastcnt := cnt                'used to find repeat codes
  dira[irpin]~                  'input from pin (0 clear = input)
  lock      := locknew          '!must have 1 lock available
  if lock == -1
    return -1
  fifo_flush                    'setup fifo
  lastvalid~                    'no last valid code
  cog := cognew(receive_ir,@stack)
  if cog == -1                  '!must have 1 cog available
    lockret(lock)               'clean up since cannot be used
    return -1
  return cog                    'all ok - off we go
  
PRI receive_ir | code, repeated
{{
  enqueue all valid keycodes
}}
  repeat
    code := get_code
                                'code is a repeat
    if code == $8000_0000 and lastvalid <> 0
      repeated++
      if repeated > repeatlag   'copy to queue after lag
        fifo_put((lastvalid>>16 & $FF) | repeatmark )
    else
      if deviceID               'accept only one device
        if deviceID <> code & $FFFF
          lastvalid~
          next                  'some other remote
      fifo_put(code>>16 & $FF)  'to buffer
      repeated~
      lastvalid := code
  
PRI get_code  | npairs, p, code
{
  wait for and return the next valid ir code
  return (in hex) either 00KKDDDD new code
                  or     80000000 repeat
  where DDDD is the 16 bit device ID
        KK   is the 8  bit key code                  
}
  repeat
    npairs~                     'count mark/space pairs
    code~                       'shift bits to code
    waitpeq(0,|<irpin,0)        'wait for a start burst
    p := get_pair               '  then get start pair
    if (p>>16 & $FFFF) < _sml   'tune this constant as needed
      next                      'glitch not a start code
    repeat                      'for each data and stop pair
      p := get_pair
      npairs++                  'count input bits as they come
      code>>=1                  'lsb sent first so shift right
      if p>>16 & $FFFF > _zth   'tune this constant as needed
        code|=$8000_0000        'shift in a 1
                                'check for stop pair
      if p & $FFFF > _esl       'tune this constant as needed
        case npairs             'validate and  reformat
          12 :                  '12 bit format 7 key 5 device
            code := code>>4 & $7F0000 | code>>27 & $FFFF
          15 :                  '15 bit format 7 key 8 device
            code := code>>1 & $7F0000 | code>>24 & $FFFF
          20 :                  '15 bit format 7 key 11 device
            code := code<<4 & $7F0000 | code>>19 & $FFFF
          other:
            quit                'not a valid code try again
                                'code is a repeat?
        if cnt - lastcnt < _rdl
          lastcnt := cnt
          return $8000_0000
        lastcnt := cnt
        return code
     
PRI get_pair | iron, iroff
{
  get a single bit as a count of mark time and
  space time returned as two words in one long
}
  iron~                         'counts mark time
  iroff~                        'counts space time
  repeat while ina[irpin]==0
    iron++
    if iron>_son                'tune as needed
      quit
  repeat while ina[irpin]==1
    iroff++
    if iroff>_esl               'tune as needed
      quit
  return iron<<16 | iroff

PUB get_lastvalid
''  return lastvalid keycode (may be 0 if not valid)
''  has format KKDDDD (key code & device code)
  return lastvalid
    
PUB fifo_flush
{{
  empty or initialize ir remote input
  first in first out queue
}}
  repeat while lockset(lock)
  head~
  tail~
  lockclr(lock)

PUB fifo_put(code) | len
{{
  if space is available insert code at head of
  fifo and return true
  else return false

  (left public but be careful this is usually
   only called by the input cog)
}}
  repeat while lockset(lock)
  len := head-tail              'needed to correct for 255->0
                                'tail could be at say 254 diff
                                'is neg and not the correct
                                'number of bytes in the queue
  if len < 0
    len += 256
  if len => _qsize
    lockclr(lock)
    return false
  fifo[head++ & _qsm1] := code
  lockclr(lock)
  return true

PUB fifo_get | code
{{
  return next available code
  or -1 if fifo empty
}}
  repeat while lockset(lock)
  if head == tail
    lockclr(lock)
    return -1
  code := fifo[tail++ & _qsm1]
  lockclr(lock)
  return code

PUB fifo_get_lastvalid
''  return lastvalid long to see device gode
  return lastvalid

PUB fifo_debug | ht
''  return fifo head and tail indexes in a long
  repeat while lockset(lock)
  ht := head<<16 | tail
  lockclr(lock)
  return ht