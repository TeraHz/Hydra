#include <Wire.h>
#include <WProgram.h>
#include <EEPROM.h> 

//local libs
#include "LCDi2c4bit.h"
#include "DS1307.h"
#include "mcp23xx.h"
#include "IRremote.h"
#include "I2CRelay.h"

#define PH_READ_PIN           3     //analog pin to poll PH
#define PWM_BACKLIGHT_PIN     6     // pwm-controlled LED backlight
#define IR_PIN                8     // Sensor data-out pin, wired direct
#define SplashScrnTime        2     //  Splash Screen display time, seconds  

const char Title[]   = { "Hydra-THz" };
const char Version[] = {  "0.01" };

uint8_t bluePins[]      = {5, 9};      // pwm pins for blues
uint8_t whitePins[]     = {10, 11};    // pwm pins for whites

uint8_t blueChannels    =        2;    // how many PWMs for blues (count from above)
uint8_t whiteChannels   =        2;    // how many PWMs for whites (count from above)

uint16_t blueStartMins    =        620;  // minute to start blues. Change this to the number of minutes past
                                    //    midnight you want the blues to start.
                                     
uint16_t whiteStartMins   =        640;  // minute to start whites. Same as above.
uint16_t bluePhotoPeriod  =        760;  // photoperiod in minutes, blues. Change this to alter the total
                                    // photoperiod for blues.
                                     
uint16_t whitePhotoPeriod =        720;  // photoperiod in minutes, whites. Same as above.
uint16_t fadeDuration     =        60;   // duration of the fade on and off for sunrise and sunset. Change
                                    //    this to alter how long the fade lasts.

uint8_t moonLevel       =        4;    // level of blues for moonlights
uint16_t moonDuration     =        60;   // duration of moonlights
uint8_t blueMax         =        255;  // max intensity for blues. Change if you want to limit max intensity.
uint8_t whiteMax        =        255;  // max intensity for whites. Same as above.
uint16_t channelDelay     =        0;    // this sets the delay in minutes between strings
                                    // of the same color for simulating directional light.
                                    // 0 means all will ramp up at the same time. 
                                   
uint8_t backlight_min   =        50;
uint8_t backlight_max   =        125;


//stop config here


uint8_t lcd_in_use_flag = 0;
uint8_t psecond = 0;
uint16_t minCounter = 0;
char strTime[20];
char tmp[20];
float PH = 0;
uint8_t second = 00;
uint8_t minute = 25;
uint8_t hour = 18;
uint8_t dayOfWeek = 1;
uint8_t dayOfMonth = 16;
uint8_t month = 8;
uint8_t year = 10;
uint8_t go_to_setup_mode = 0;
uint8_t global_mode = 0;
uint8_t sPos = 1; // position for setting

uint8_t in_keys = 0;
long key;
uint8_t ms,ls, ts, tmi, th, tdw, tdm, tmo, ty;
decode_results results;
uint8_t menu_position = 0;

#define MENU_OPTIONS 15
/*
 * arduino (not atmel!) pins for physical computing i/o
 */

/*
 * IFC = internal function codes
 *
 * these are logical mappings of physical IR keypad keys to internal callable functions.
 * its the way we soft-map keys on a remote to things that happen when you press those keys.
 */

#define IFC_DIAG_IR_RX              0   // enter diag-mode for IR receive
#define IFC_MENU                    1   // enter menu mode
#define IFC_UP                      2   // up-arrow
#define IFC_DOWN                    3   // down-arrow
#define IFC_LEFT                    4   // left-arrow
#define IFC_RIGHT                   5   // right-arrow
#define IFC_OK                      6   // Select/OK/Confirm btn
#define IFC_CANCEL                  7   // Cancel/back/exit
#define IFC_MOONLIGHT_ONOFF         8   // Moonlight toggle

#ifdef NUMBER_KEYS
#define IFC_KEY_1                   9
#define IFC_KEY_2                   10
#define IFC_KEY_3                   11
#define IFC_KEY_4                   12
#define IFC_KEY_5                   13
#define IFC_KEY_6                   14
#define IFC_KEY_7                   15
#define IFC_KEY_8                   16
#define IFC_KEY_9                   17
#define IFC_KEY_0                   18
#endif

// has to be the last entry in this list
#define IFC_KEY_SENTINEL            9   // this must always be the last in the list
#define MAX_FUNCTS                  IFC_KEY_SENTINEL

#define EEPROM_MAGIC              0


#define EEPROM_WHITE_LVL          1    // white LED brightness
#define EEPROM_BLUE_LVL           2    // blue LED brightness

//#define EEPROM_BACKLIGHT_LEVEL    3    // current working level
#define EEPROM_BACKLIGHT_MIN      4    // our 'dimest' setting
#define EEPROM_BACKLIGHT_MAX      5    // our 'brightest' setting
#define EEPROM_BLUE_MAX           6    // Cap for blue light
#define EEPROM_WHITE_MAX          7    // Cap for white light
#define EEPROM_WHITE_DURATION     8    // 2 bytes; how long to keep whites on
#define EEPROM_BLUE_DURATION      10   // 2 bytes; how long to keep blues on
#define EEPROM_MOON_LEVEL         12   // level of moon lights
#define EEPROM_MOON_DURATION      13   // 2 bytes; Duration of moon lights
#define EEPROM_BLUE_START         15   // 2 bytes; Starting time for blues
#define EEPROM_WHITE_START        17   // 2 bytes; Starting time for whites
#define EEPROM_CHANNEL_DELAY      19   // 2 bytes; Delay between channels
#define EEPROM_FADE_DURATION      21   // 2 bytes; Suration of sunrise/sunset


// this is a temporary holding area that we write to, key by key; and then dump all at once when the user finishes the last one
long ir_key_bank1[MAX_FUNCTS+1];

// this is used in learn-mode, to prompt the user and assign enums to internal functions
struct _ir_keypress_mapping {
  long key_hex;
  uint8_t internal_funct_code;
  char funct_name[16];
}

ir_keypress_mapping[MAX_FUNCTS+1] = {
   { 0x00, IFC_DIAG_IR_RX,      "Debug IR (rx)"  }
  ,{ 0x00, IFC_MOONLIGHT_ONOFF, "Moonlight"      }
  ,{ 0x00, IFC_MENU,            "Menu"           }
  ,{ 0x00, IFC_UP,              "Up Arrow"       }
  ,{ 0x00, IFC_DOWN,            "Down Arrow"     }
  ,{ 0x00, IFC_LEFT,            "Left Arrow"     }
  ,{ 0x00, IFC_RIGHT,           "Right Arrow"    }
  ,{ 0x00, IFC_OK,              "Confirm/Select" }
  ,{ 0x00, IFC_CANCEL,          "Back/Cancel"    }
#ifdef NUMBER_KEYS
  ,{ 0x00, IFC_KEY_1,           "Num 1"          }
  ,{ 0x00, IFC_KEY_2,           "Num 2"          }
  ,{ 0x00, IFC_KEY_3,           "Num 3"          }
  ,{ 0x00, IFC_KEY_4,           "Num 4"          }
  ,{ 0x00, IFC_KEY_5,           "Num 5"          }
  ,{ 0x00, IFC_KEY_6,           "Num 6"          }
  ,{ 0x00, IFC_KEY_7,           "Num 7"          }
  ,{ 0x00, IFC_KEY_8,           "Num 8"          }
  ,{ 0x00, IFC_KEY_9,           "Num 9"          }
  ,{ 0x00, IFC_KEY_0,           "Num 0"          }
#endif
  ,{ 0x00, IFC_KEY_SENTINEL,    "NULL"           }
};

// menu struct:
struct _menu_mapping {
  uint8_t pos;
  char description[20];
  uint8_t eepromLoc;
}

// Menu
menu_mapping[MENU_OPTIONS] = {
   { 0,  "Backlight min"      , EEPROM_BACKLIGHT_MIN   }
  ,{ 1,  "Backlight max"      , EEPROM_BACKLIGHT_MAX   }
  ,{ 2,  "Clock setup"        , 0                      }
  ,{ 3,  "IR Diagnose"        , 0                      }
  ,{ 4,  "Remote Learning"    , 0                      }
  ,{ 5,  "White LED limit"    , EEPROM_WHITE_MAX       }
  ,{ 6,  "Blue LED limit"     , EEPROM_BLUE_MAX        }
  ,{ 7,  "Moonlight level"    , EEPROM_MOON_LEVEL      }
  ,{ 8,  "White LED start"    , EEPROM_WHITE_START     }
  ,{ 9,  "Blue LED start"     , EEPROM_BLUE_START      }
  ,{ 10, "White LED duration" , EEPROM_WHITE_DURATION  }
  ,{ 11, "Blue LED duration"  , EEPROM_BLUE_DURATION   }
  ,{ 12, "Moon duration"      , EEPROM_MOON_DURATION   }
  ,{ 13, "Channel Delay"      , EEPROM_CHANNEL_DELAY   }
  ,{ 14, "Fade Duration"      , EEPROM_FADE_DURATION   }
};


MCP23XX lcd_mcp = MCP23XX(LCD_MCP_DEV_ADDR);
MCP23XX relay_mcp = MCP23XX(RELAY_MCP_DEV_ADDR);

LCDI2C4Bit lcd = LCDI2C4Bit(LCD_MCP_DEV_ADDR, LCD_PHYS_LINES, LCD_PHYS_ROWS, PWM_BACKLIGHT_PIN);

IRrecv irrecv(IR_PIN);

I2CRelay relay = I2CRelay();

template <class T> uint16_t EEPROM_writeAnything(uint16_t ee, const T& value)
{
    const byte* p = (const byte*)(const void*)&value;
    uint16_t i;
    for (i = 0; i < sizeof(value); i++)
	  EEPROM.write(ee++, *p++);
    return i;
}

template <class T> uint16_t EEPROM_readAnything(uint16_t ee, T& value)
{
    byte* p = (byte*)(void*)&value;
    uint16_t i;
    for (i = 0; i < sizeof(value); i++)
	  *p++ = EEPROM.read(ee++);
    return i;
}




void setup() {
    Serial.begin(9600);
    init_components();
    signon_msg();
    
  if (scan_front_button() == 1) {
      //enter_setup_mode();
  }

}

void loop() {
  
  if (global_mode == 0) {            // main 'everyday use' mode
      onKeyPress();
      Serial.println("MODE 0");
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
  }//global_mode == 0
  
  else if (global_mode == 1) {       // Main Menu
    Serial.println("MODE 1");
      menu();
  }
  
  else if (global_mode == 2) {       // Setting a value
    //Serial.println("MODE 2");
       // if the menu item is not a simple uint8_t value
    if ( menu_mapping[menu_position].eepromLoc == 0 ){
      if ( menu_mapping[menu_position].pos == 2 ){ //set clock
        set_time();
      }else if ( menu_mapping[menu_position].pos == 3 ) {
        diagnose_IR();
      }else if ( menu_mapping[menu_position].pos == 4 ) {
        enter_setup_mode();
      }
    }else{
      //setCurrentMenuOption();   
    }
  }// global_mode == 2
  
  RTC.getDate(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year);

  if (psecond != second){
    //Serial.println("tick");
    psecond = second;
    sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d",hour, minute, second, dayOfMonth, month, year);
    minCounter = hour * 60 + minute;
    run_sec();
  }

  delay(50);
  
}

void run_sec( void ){ // runs every second
if (global_mode == 0){
      update_ph(2,0);
      update_clock(3,3);
    }
    update_leds();
}


void update_clock(uint8_t x, uint8_t y){
  lcd.cursorTo(x,y);
  lcd.print(strTime);
}

void update_ph(uint8_t x, uint8_t y){
    lcd.cursorTo(x,y);
    lcd.print("Ph: ");
    getPH();
    lcd.print(PH);
    lcd.print(" ");

}

void getPH( void ){
  double sum = 0.0;
  uint8_t samples = 15;
  for (uint8_t i=0; i<=samples;i++){
    sum+=analogRead(PH_READ_PIN);
    delay(20);
  }
  PH = sum/15/50;
}

void update_leds( void ){
  uint8_t i;
  uint8_t ledVal;
  uint8_t percent;
  char ledValBuf[20];
  for (i = 0; i < blueChannels; i++){
      ledVal = setLed(minCounter, bluePins[i], blueStartMins + channelDelay*i, bluePhotoPeriod, fadeDuration, blueMax);
      percent = (int)(ledVal/2.55);
      sprintf(ledValBuf,"PWM%02d:%02d ",bluePins[i], percent);
      if (global_mode == 0){
        lcd.cursorTo(0, i*10);
        lcd.print(ledValBuf);
      }
  }
  for (i = 0; i < whiteChannels; i++){
      ledVal = setLed(minCounter, whitePins[i], whiteStartMins + channelDelay*i, whitePhotoPeriod, fadeDuration, whiteMax);
      percent = (int)(ledVal/2.55);
      sprintf(ledValBuf,"PWM%02d:%02d ",whitePins[i], percent);
      if (global_mode == 0){
          lcd.cursorTo(1, i*10);
          lcd.print(ledValBuf);
      }
  }
}


uint8_t setLed(uint16_t mins,    // current time in minutes
            uint8_t ledPin,  // pin for this channel of LEDs
            uint16_t start,   // start time for this channel of LEDs
            uint16_t period,  // photoperiod for this channel of LEDs
            uint16_t fade,    // fade duration for this channel of LEDs
            uint8_t ledMax   // max value for this channel
            )  {
  uint8_t ledVal = 0;
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
    ledVal = map(mins - start - period + fade, 0, fade, ledMax, 0);
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
  uint16_t i;
  Wire.begin();
  //start LCD
  lcd.init();
  lcd.SetInputKeysMask(LCD_MCP_INPUT_PINS_MASK);
  lcd.set_backlight_levels( backlight_min ,backlight_max);
  lcd.lcd_fade_backlight_on();
  
  //start IR sensor
  irrecv.enableIRIn();
  
  //set the date
  //RTC.setDate(second, minute, hour, dayOfWeek, dayOfMonth, month, year);
  
  //read remote keys from EEPROM  
  for (i=0; i<=MAX_FUNCTS; i++) {
    EEPROM_readAnything(40 + i*sizeof(key), key);
    ir_keypress_mapping[i].key_hex = key;
  }
  
  //check if eeprom is good and if not set defaults
  if (EEPROM.read(EEPROM_MAGIC) != 01) {
    // init all of EEPROM area

    EEPROM_writeAnything(EEPROM_WHITE_LVL,         0);
    EEPROM_writeAnything(EEPROM_BLUE_LVL,          0);
    EEPROM_writeAnything(EEPROM_BACKLIGHT_MIN,     backlight_min);
    EEPROM_writeAnything(EEPROM_BACKLIGHT_MAX,     backlight_max);
    EEPROM_writeAnything(EEPROM_BLUE_MAX,          blueMax);
    EEPROM_writeAnything(EEPROM_WHITE_MAX,         whiteMax);
    EEPROM_writeAnything(EEPROM_WHITE_DURATION,    whitePhotoPeriod);
    EEPROM_writeAnything(EEPROM_BLUE_DURATION,     bluePhotoPeriod);
    EEPROM_writeAnything(EEPROM_MOON_LEVEL,        moonLevel);
    EEPROM_writeAnything(EEPROM_MOON_DURATION,     moonDuration);
    EEPROM_writeAnything(EEPROM_WHITE_START,       whiteStartMins);
    EEPROM_writeAnything(EEPROM_BLUE_START,        blueStartMins);
    EEPROM_writeAnything(EEPROM_CHANNEL_DELAY,     channelDelay);
    EEPROM_writeAnything(EEPROM_FADE_DURATION,     fadeDuration);
    EEPROM_writeAnything(EEPROM_MAGIC, 01);  // this signals that we're whole again ;)
  }
  
  //read settings from EEPROM
  EEPROM_readAnything(EEPROM_BACKLIGHT_MIN, backlight_min);
  EEPROM_readAnything(EEPROM_BACKLIGHT_MAX, backlight_max);
  EEPROM_readAnything(EEPROM_BLUE_MAX, blueMax);
  EEPROM_readAnything(EEPROM_WHITE_MAX, whiteMax);
  EEPROM_readAnything(EEPROM_WHITE_DURATION, whitePhotoPeriod);
  EEPROM_readAnything(EEPROM_BLUE_DURATION, bluePhotoPeriod);
  EEPROM_readAnything(EEPROM_MOON_LEVEL, moonLevel);
  EEPROM_readAnything(EEPROM_MOON_DURATION, moonDuration);
  EEPROM_readAnything(EEPROM_WHITE_START, whiteStartMins);
  EEPROM_readAnything(EEPROM_BLUE_START, blueStartMins);
  EEPROM_readAnything(EEPROM_CHANNEL_DELAY, channelDelay);
  EEPROM_readAnything(EEPROM_FADE_DURATION, fadeDuration);
  
}

uint8_t scan_front_button( void ) {
  in_keys = lcd.ReadInputKeys();
  if ( (in_keys & LCD_MCP_INPUT_PINS_MASK ) != LCD_MCP_INPUT_PINS_MASK) {
    return 1;
  } 
  else {
    return 0;
  }
}

void enter_setup_mode( void )  {

  uint8_t setup_finished = 0;
  uint8_t idx = 0, i = 0;
  uint8_t blink_toggle = 0;
  uint8_t blink_count = 0;
  float ratio;
  uint8_t eeprom_index = 0;
  uint8_t key_pressed = 0;
  

  lcd.clear();
  lcd.send_string("Remote Learning", LCD_CURS_POS_L1_HOME);

  idx = 0;
  while (!setup_finished) {
    if (!strcmp(ir_keypress_mapping[idx].funct_name, "NULL")) {
      setup_finished = 1;   // signal we're done with the whole list  
      goto done_learn_mode;
    }  

    // we embed the index inside our array of structs, so that even if the user comments-out blocks
    // of it, we still have the same index # for the same row of content
    eeprom_index = ir_keypress_mapping[idx].internal_funct_code;

    // prompt the user for which key to press
    lcd.send_string(ir_keypress_mapping[idx].funct_name, LCD_CURS_POS_L2_HOME+1);
    delay(300);
  
    blink_toggle = 1;
    blink_count = 0;

    /*
     * non-blocking poll for a keypress
     */

    while ( (key = get_IR_key()) == 0 ) {
     
      if (blink_toggle == 1) {
        blink_toggle = 0;
        lcd.clear_L2();  // clear the string
        delay(300);  // debounce
      } 
      else {
        blink_toggle = 1;
        ++blink_count;
        lcd.send_string(ir_keypress_mapping[idx].funct_name, LCD_CURS_POS_L2_HOME+1);  // redraw the string
        delay(600);  // debounce
      }


      // check if we should exit (user got into this mode but had 2nd thoughts ;)
      if ( blink_count >= 30 ) {    // change the value of '30' if you need more time to find your keys ;)
        setup_finished = 1;
        global_mode = 0;           // back to main 'everyday use' mode

        lcd.clear();
        lcd.send_string("Abandon SETUP", LCD_CURS_POS_L1_HOME);


        /*
         * read LAST GOOD soft-set IR-key mappings from EEPROM
         */

        for (i=0; i<=MAX_FUNCTS; i++) {
          EEPROM_readAnything(40 + i*sizeof(key), key);
          ir_keypress_mapping[i].key_hex = key;
        }

        delay(1000);
        
        lcd.clear();
        return;

      } // if blink count was over the limit (ie, a user timeout)

    } // while


    // if we got here, a non-blank IR keypress was detected!
    lcd.send_string("*", LCD_CURS_POS_L2_HOME);
    lcd.send_string(ir_keypress_mapping[idx].funct_name, LCD_CURS_POS_L2_HOME+1);  // redraw the string

    delay(1000);  // debounce a little more


    // search the list of known keys to make sure this isn't a dupe or mistake
    // [tbd]


    // accept this keypress and save it in the array entry that matches this internal function call
    ir_key_bank1[eeprom_index] = key;

    idx++;  // point to the next one

    irrecv.resume(); // we just consumed one key; 'start' to receive the next value
    delay(300);
    
  } // while



 done_learn_mode:
  global_mode = 0;           // back to main 'everyday use' mode
  lcd.clear();
  lcd.send_string("Learning Done", LCD_CURS_POS_L1_HOME);
  delay(500);
  lcd.send_string("Saving Key Codes", LCD_CURS_POS_L2_HOME);

  // copy (submit) all keys to the REAL working slots
  for (i=0; i<=MAX_FUNCTS; i++) {
    ir_keypress_mapping[i].key_hex = ir_key_bank1[i];
    EEPROM_writeAnything(40 + i*sizeof(ir_key_bank1[i]), ir_key_bank1[i]);    // blocks of 4 bytes each (first 40 are reserved, though)
    ratio = (float)i / (float)idx;

    delay(50);
  }

  delay(1000);

  lcd.clear();
}

long  get_IR_key( void ) {
  long my_result;
  long last_value = results.value;   // save the last one in case the new one is a 'repeat code'

  if (irrecv.decode(&results)) {

    // fix repeat codes (make them look like truly repeated keys)
    if (results.value == 0xffffffff) {

      if (last_value != 0xffffffff) {  
        results.value = last_value;
      } 
      else {
        results.value = 0;
      }

    }


    /*
     * this is used when in 'debug IR' mode
     */
    if (global_mode == 4) {
      if (results.value != 0) {
        ir_key_dump();
      }
    }


#if 0
    if (results.value != 0xffffffff) {
      my_result = results.value;
    } else {
      my_result = last_value;  // 0;
    }
#endif

    irrecv.resume();    // we just consumed one key; 'start' to receive the next value

    return results.value; //my_result;
  }
  else {
    return 0;   // no key pressed
  }
}

void ir_key_dump( void ) {

  lcd.clear_L2();
  delay(50);

  if (results.decode_type == UNKNOWN) {
    //Serial.println("Could not decode IR message");
    lcd.send_string("UNKNOWN: (no hex)", LCD_CURS_POS_L2_HOME);
  } 

  else {
    if (results.decode_type == NEC) {
      lcd.send_string("NEC: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == SONY) {
      lcd.send_string("SONY: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == RC5) {
      lcd.send_string("RC5: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == RC6) {
      lcd.send_string("RC6: ", LCD_CURS_POS_L2_HOME);
    }


    // print the value!
    lcd_print_long_hex(results.value);

  }
}

void lcd_print_long_hex(long p_value) {

  uint8_t Byte1 = ((p_value >> 0) & 0xFF);
  uint8_t Byte2 = ((p_value >> 8) & 0xFF);
  uint8_t Byte3 = ((p_value >> 16) & 0xFF);
  uint8_t Byte4 = ((p_value >> 24) & 0xFF);

  lcd.write('(');

  hex2ascii(Byte1, &ms, &ls);
  lcd.write(ms); 
  lcd.write(ls);

  hex2ascii(Byte2, &ms, &ls);
  lcd.write(ms); 
  lcd.write(ls);

  hex2ascii(Byte3, &ms, &ls);
  lcd.write(ms); 
  lcd.write(ls);

  hex2ascii(Byte4, &ms, &ls);
  lcd.write(ms); 
  lcd.write(ls);

  lcd.write(')');
}

void  hex2ascii( const uint8_t val, byte* ms, byte* ls ) {
  static char hex_buf[8];

  sprintf(hex_buf, "%02x ", val);
  *ms = hex_buf[0];
  *ls = hex_buf[1];

  //*ms = val / 10 + '0';
  //*ls = val % 10 + '0';
}  


/*********************************/
/****** NORMAL MODE HANDLER ******/
/*********************************/
void onKeyPress( void )
{

  key = get_IR_key();
  if (key == 0) {
    return;   // try again to sync up on an IR start-pulse
  }
  lcd.restore_backlight();
  // key = IR diagnose
  if (key == ir_keypress_mapping[IFC_DIAG_IR_RX].key_hex) {
  //do something
  }

  // key = MENU
  else if (key == ir_keypress_mapping[IFC_MENU].key_hex) {
    global_mode = 1;
    update_menu();
  }

  // key = UP
  else if (key == ir_keypress_mapping[IFC_UP].key_hex) {
  //do something
  }

  // key = DOWN
  else if (key == ir_keypress_mapping[IFC_DOWN].key_hex) {
  //do something
  }

  // key = LEFT
  else if (key == ir_keypress_mapping[IFC_LEFT].key_hex) {
  //do something
  }

  // key = RIGHT
  else if (key == ir_keypress_mapping[IFC_RIGHT].key_hex) {
  //do something
  }

  // key = OK
  else if (key == ir_keypress_mapping[IFC_OK].key_hex) {
  //do something
  }
  
  // key = Cancel
  else if (key == ir_keypress_mapping[IFC_CANCEL].key_hex) {
  //do something
  }
  
  // key = moonlight toggle
  else if (key == ir_keypress_mapping[IFC_MOONLIGHT_ONOFF].key_hex) {
  //do something
  }else{
      Serial.println("unsupported");
  }
  
  delay(100);
  irrecv.resume();
}


/***********************/
/****** MAIN MENU ******/
/***********************/
void menu( void ) {
  key = get_IR_key();
  if (key == 0) {
    return;
  }

  if (key == ir_keypress_mapping[IFC_OK].key_hex ) {
    lcd.clear();
    RTC.getDate(&ts, &tmi, &th, &tdw, &tdm, &tmo, &ty);
    lcd.send_string(menu_mapping[menu_position].description, LCD_CURS_POS_L1_HOME);
    lcd.send_string("Use arrows to adjust", LCD_CURS_POS_L2_HOME);
    //EEPROM_readAnything(menu_mapping[menu_position].eepromLoc, sVal);
    global_mode = 2;
    delay (100);
  }else if (key == ir_keypress_mapping[IFC_UP].key_hex){
    if (menu_position < MENU_OPTIONS-1){
        menu_position++;
    }else{
        menu_position = 0;
    }
    update_menu();
    delay (100);
  }else if (key == ir_keypress_mapping[IFC_DOWN].key_hex){ 
    if (menu_position > 0){
      menu_position--;
    }else{
      menu_position = MENU_OPTIONS-1;
    }
    update_menu();
    delay (100);
  }else if (key == ir_keypress_mapping[IFC_CANCEL].key_hex){
    global_mode = 0;
    lcd.clear();
    delay (100);
  } 
  
  delay(100);
  
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value
  
}


void update_menu( void ){
  lcd.clear_L2();
  lcd.clear_L3();
  lcd.clear_L4();
  lcd.send_string(menu_mapping[menu_position].description, LCD_CURS_POS_L2_HOME);
}


void set_time( void ){
  key = get_IR_key();
  if (key == 0) {
    return;
  }
  sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d %d",th, tmi, ts, tdm, tmo, ty, tdw);
  update_clock(2,0);
  lcd.cursorTo(3,0);
  lcd.print("HH:MM:SS DD:MM:YY DW");
  // key = OK
  if (key == ir_keypress_mapping[IFC_OK].key_hex ) {
    RTC.setDate(ts, tmi, th, tdw, tdm, tmo, ty);
    global_mode = 0;
    lcd.clear();
  }
  
  // key = Up
  else if (key == ir_keypress_mapping[IFC_UP].key_hex){
        
    if (sPos == 1){
      if (th < 23) {
         th++;
      } 
      else {
        th = 0;  // wrap around
      }
    }else if (sPos == 2){
      if (tmi < 59) {
         tmi++;
      } 
      else {
        tmi = 0;  // wrap around
      }
    }else if (sPos == 3){
      if (ts < 59) {
         ts++;
      } 
      else {
        ts = 0;  // wrap around
      }
    }else if (sPos == 4){
      if (tdm < 31) {
         tdm++;
      } 
      else {
        tdm = 1;  // wrap around
      }
   }else if (sPos == 5){
      if (tmo < 12) {
         tmo++;
      } 
      else {
        tmo = 1;  // wrap around
      }
   }else if (sPos == 6){
      if (ty < 99) {
         ty++;
      } 
      else {
        ty = 0;  // wrap around
      }
   }else if (sPos == 7){
      if (tdw < 7) {
         tdw++;
      } 
      else {
        tdw = 1;  // wrap around
      }   
   }
    delay (100);
    update_clock(2,0);
  }
  
  
  // key = Down
  else if (key == ir_keypress_mapping[IFC_DOWN].key_hex){ 
        
    if (sPos == 1){
      if (th > 0) {
         th--;
      } 
      else {
        th = 23;  // wrap around
      }
    }else if (sPos == 2){
      if (tmi > 0) {
         tmi--;
      } 
      else {
        tmi = 59;  // wrap around
      }
    }else if (sPos == 3){
      if (ts > 0) {
         ts--;
      } 
      else {
        ts = 59;  // wrap around
      }
    }else if (sPos == 4){
      if (tdm > 1) {
         tdm--;
      } 
      else {
        tdm = 31;  // wrap around
      }
   }else if (sPos == 5){
      if (tmo > 1) {
         tmo--;
      } 
      else {
        tmo = 12;  // wrap around
      }
   }else if (sPos == 6){
      if (ty > 1) {
         ty--;
      } 
      else {
        ty = 99;  // wrap around
      }
   }else if (sPos == 7){
      if (tdw > 1) {
         tdw--;
      } 
      else {
        tdw = 7;  // wrap around
      }   
   }
    delay (100);
    update_clock(2,0);
  }
  
  
  // key = Left
  else if (key == ir_keypress_mapping[IFC_LEFT].key_hex){
    if (sPos > 1) {
        sPos--;
      } 
      else {
        sPos = 7;  // wrap around
      }
    delay (100);
  }
  
  
  // key = Right
  else if (key == ir_keypress_mapping[IFC_RIGHT].key_hex){ 
    if (sPos < 7) {
        sPos++;
      } 
      else {
        sPos = 1;  // wrap around
      }
    delay (100);
  }
  
  // key = Cancel
  else if (key == ir_keypress_mapping[IFC_CANCEL].key_hex){
    lcd.clear();
    global_mode = 0;
    delay (100);
  } 
  delay(100);
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value
  
}

void diagnose_IR( void ){
  
  /*
   * we got a valid IR start pulse! fetch the keycode, now.
   */

  key = get_IR_key();
  if (key == 0) {
    return;
  }
  lcd.clear();
  lcd.send_string(menu_mapping[menu_position].description, LCD_CURS_POS_L1_HOME);
  delay(50);

  if (results.decode_type == UNKNOWN) {
    //Serial.println("Could not decode IR message");
    lcd.send_string("UNKNOWN: (no hex)", LCD_CURS_POS_L2_HOME);
  } 

  else {
    if (results.decode_type == NEC) {
      lcd.send_string("NEC: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == SONY) {
      lcd.send_string("SONY: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == RC5) {
      lcd.send_string("RC5: ", LCD_CURS_POS_L2_HOME);
    } 

    else if (results.decode_type == RC6) {
      lcd.send_string("RC6: ", LCD_CURS_POS_L2_HOME);
    }


    // print the value!
    lcd_print_long_hex(results.value);

  }
  // 'diag mode' key exits
  if (key == ir_keypress_mapping[IFC_CANCEL].key_hex) {
    global_mode = 0;  // we're done in this edit mode
    /*
     * redraw the screen in '0' (main) mode
     */
     lcd.clear();
    delay (200); //Debounce switch
  }

  delay(100);
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value

}

