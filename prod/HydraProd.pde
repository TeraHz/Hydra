#include <Wire.h>
#include <WProgram.h>

//local libs
#include "LCDi2c4bit.h"
#include "DS1307.h"
#include "mcp23xx.h"

#define PH_READ_PIN             3    //analog pin to poll PH
#define PWM_BACKLIGHT_PIN       6    // pwm-controlled LED backlight
#define SplashScrnTime        2          //  Splash Screen display time, seconds  

const char Title[]   = { "Hydra-THz" };
const char Version[] = {  "0.01" };

byte bluePins[] = {5, 9};            // pwm pins for blues
byte whitePins[] = {10, 11};         // pwm pins for whites

byte blueChannels =           2;    // how many PWMs for blues (count from above)
byte whiteChannels  =         2;    // how many PWMs for whites (count from above)

int blueStartMins =        620;  // minute to start blues. Change this to the number of minutes past
                                     //    midnight you want the blues to start.
                                     
int whiteStartMins =       640;  // minute to start whites. Same as above.
int bluePhotoPeriod =      780;  // photoperiod in minutes, blues. Change this to alter the total
                                    // photoperiod for blues.
                                     
int whitePhotoPeriod =     720;  // photoperiod in minutes, whites. Same as above.
int fadeDuration =          60;   // duration of the fade on and off for sunrise and sunset. Change
                                    //    this to alter how long the fade lasts.

byte moonLevel =             4;   // level of blues for moonlights
int moonDuration =          60;  // duration of moonlights
byte blueMax =               255;  // max intensity for blues. Change if you want to limit max intensity.
byte whiteMax =              255;  // max intensity for whites. Same as above.
int channelDelay =            0;    // this sets the delay in minutes between strings
                                   // of the same color for simulating directional light.
                                   // 0 means all will ramp up at the same time. 
                                   
byte backlight_min =          50;
byte backlight_max =          125;
byte lcd_in_use_flag = 0;
byte psecond = 0;
int minCounter = 0;
char strTime[20];
char tmp[20];
float PH = 0;
byte second = 00;
byte minute = 15;
byte hour = 22;
byte dayOfWeek = 4;
byte dayOfMonth = 11;
byte month = 8;
byte year = 10;


MCP23XX lcd_mcp = MCP23XX(LCD_MCP_DEV_ADDR);

LCDI2C4Bit lcd = LCDI2C4Bit(LCD_MCP_DEV_ADDR, LCD_PHYS_LINES, LCD_PHYS_ROWS, PWM_BACKLIGHT_PIN);

void setup() {
    init_components();
   
    
    signon_msg();
}

void loop() {
    
    if (lcd.backlight_admin == 0) {   // administratively set? (enable auto timeout; normal mode)
      if (lcd.backlight_currently_on == 1) {
        if ( (millis() - lcd.one_second_counter_ts) >= 1000) {
          lcd.seconds++;
          lcd.one_second_counter_ts = millis();  // reset ourself
        }

        if (lcd.seconds >= lcd.lcd_inactivity_timeout) {
          lcd.lcd_fade_backlight_off();  // this also sets 'backlight_currently_on to 0'
        }
      } // lcd.backlight_currently_on == 1
    } //lcd.backlight_admin == 0
    
  RTC.getDate(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year);

  if (psecond != second){
    Serial.println("tick");
    psecond = second;
    sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d",hour, minute, second, dayOfMonth, month, year);
    minCounter = hour * 60 + minute;
    run_sec();
  }
  delay(50);
  
}

void run_sec( void ){ // runs every second
    update_ph(2,0);
    update_clock(3,3);
    update_leds();
}


void update_clock(int x, int y){
  lcd.cursorTo(x,y);
  lcd.print(strTime);
}

void update_ph(int x, int y){
    lcd.cursorTo(x,y);
    lcd.print("Ph: ");
    getPH();
    lcd.print(PH);
    lcd.print(" ");

}

void getPH( void ){
  double sum = 0.0;
  int samples = 15;
  for (int i=0; i<=samples;i++){
    sum+=analogRead(PH_READ_PIN);
    delay(20);
  }
  PH = sum/15/50;
}

void update_leds( void ){
  int i;
  byte ledVal;
  byte percent;
  char ledValBuf[20];
  for (i = 0; i < blueChannels; i++){
      ledVal = setLed(minCounter, bluePins[i], blueStartMins + channelDelay*i, bluePhotoPeriod, fadeDuration, blueMax);
      percent = (int)(ledVal/2.55);
      sprintf(ledValBuf,"PWM%02d: %02d",bluePins[i], percent);
      lcd.cursorTo(0, i*10);
      lcd.print(ledValBuf);
  }
  for (i = 0; i < whiteChannels; i++){
      ledVal = setLed(minCounter, whitePins[i], whiteStartMins + channelDelay*i, whitePhotoPeriod, fadeDuration, whiteMax);
      percent = (int)(ledVal/2.55);
      sprintf(ledValBuf,"PWM%02d: %02d",whitePins[i], percent);
      lcd.cursorTo(1, i*10);
      lcd.print(ledValBuf);
  }
}


byte setLed(int mins,    // current time in minutes
            byte ledPin,  // pin for this channel of LEDs
            int start,   // start time for this channel of LEDs
            int period,  // photoperiod for this channel of LEDs
            int fade,    // fade duration for this channel of LEDs
            byte ledMax   // max value for this channel
            )  {
              byte ledVal = 0;
  if (mins <= start || mins > start + period)  {
    ledVal = 0;
  }
  if (mins > start && mins <= start + fade)  {
    ledVal =  map(mins - start, 0, fade, 0, ledMax);
  }
    if (mins > start + fade && mins <= start + period - fade)  {
      ledVal = ledMax;
  }
    if (mins > start + period - fade && mins <= start + period)  {
      ledVal = map(mins - start + period - fade, 0, fade, ledMax, 0);
  }
      analogWrite(ledPin, ledVal);
      return ledVal;  
}


void  signon_msg( void ) {  
  long start_time = millis();


  lcd.clear();
  lcd.lcd_fade_backlight_on();
  lcd.backLight(backlight_max);   // full bright

  lcd.send_string(Title,   LCD_CURS_POS_L1_HOME);
  lcd.send_string(Version, LCD_CURS_POS_L2_HOME);

  delay(SplashScrnTime*1000);
  lcd.clear();
}


void init_components ( void ) {
   Wire.begin();
   lcd.init();
   lcd.SetInputKeysMask(LCD_MCP_INPUT_PINS_MASK);
   lcd.set_backlight_levels( backlight_min ,backlight_max);
   lcd.lcd_fade_backlight_on();
   
    //RTC.setDate(second, minute, hour, dayOfWeek, dayOfMonth, month, year);
}
