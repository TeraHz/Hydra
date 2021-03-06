/*
  DS1307.h - library for DS1307 rtc
*/

// ensure this library description is only included once
#ifndef DS1307_h
#define DS1307_h
#define DS1307_CLOCKHALT B10000000

// include types & constants of Wiring core API
#include <WConstants.h>

// include types & constants of Wire ic2 lib
#include <Wire.h>

#define DS1307_I2C_ADDRESS 0x68

// library interface description
class DS1307
{
  // user-accessible "public" interface
  public:
    DS1307();
    void setDate(byte, byte, byte,byte, byte, byte, byte);
    void getDate(byte *, byte *, byte *,byte *, byte *, byte *, byte *);
    boolean isRunning();

};

extern DS1307 RTC;

#endif
 

