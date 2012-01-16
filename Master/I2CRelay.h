#ifndef I2CRELAY_H
#define I2CRELAY_H

#include <inttypes.h>
#include "mcp23xx.h"


// the Relay i2c device address
#define RELAY_MCP_DEV_ADDR      0xA6


class I2CRelay {

public:

  I2CRelay();
  void enable( uint8_t );
  void disable( uint8_t );
  void toggle( uint8_t );
  void on( void );
  void off( void );
  void init( void );
  

private:
  uint8_t dataPlusMask;
  uint8_t myInputKeysMask;

  
};

#endif
