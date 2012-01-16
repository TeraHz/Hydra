#include "I2CRelay.h"
#include <Wire.h>
#include <inttypes.h>
#include "mcp23xx.h"
#include "WConstants.h"  //all things wiring / arduino
extern MCP23XX relay_mcp;

byte ledstate = B11111111;

I2CRelay::I2CRelay() 
{

}

void
I2CRelay::init(){
}

void
I2CRelay::enable(uint8_t n){
  ledstate &= ~(1 << n);
  relay_mcp.set(MCP_REG_GPIO, ledstate);
}

void
I2CRelay::disable(uint8_t n){
  ledstate |= (1 << n);
  relay_mcp.set(MCP_REG_GPIO, ledstate);
}

void
I2CRelay::toggle(uint8_t n){
  ledstate ^= (1 << n);
  relay_mcp.set(MCP_REG_GPIO, ledstate);
}

void
I2CRelay::on( void ){
  ledstate = B11111111;
  relay_mcp.set(MCP_REG_GPIO, ledstate);
}

void
I2CRelay::off( void ){
  ledstate = B11111111;
  relay_mcp.set(MCP_REG_GPIO, ledstate);
}
