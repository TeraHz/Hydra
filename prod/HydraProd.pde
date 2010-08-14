#include <Wire.h>
#include <WProgram.h>
#include <EEPROM.h> 

//local libs
#include "LCDi2c4bit.h"
#include "DS1307.h"
#include "mcp23xx.h"
#include "IRremote.h"

#define PH_READ_PIN             3    //analog pin to poll PH
#define PWM_BACKLIGHT_PIN       6    // pwm-controlled LED backlight
#define IR_PIN                       8	 // Sensor data-out pin, wired direct
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
int bluePhotoPeriod =      760;  // photoperiod in minutes, blues. Change this to alter the total
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

//stop config here


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
byte go_to_setup_mode = 0;
byte global_mode = 0;
uint8_t in_keys = 0;
long key;
byte ms,ls;
decode_results results;
byte menu_position = 0;

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

#define EEPROM_BACKLIGHT_LEVEL    3    // current working level
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
  byte internal_funct_code;
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
  byte pos;
  char description[20];
  char tooltip1[20];
  char tooltip2[20];
  byte eepromLoc;
}

// Menu
menu_mapping[MENU_OPTIONS] = {
   { 0,  "Backlight min"      , "Minimum level of"   , "the LCD brightness", EEPROM_BACKLIGHT_MIN   }
  ,{ 1,  "Backlight max"      , "Maximum level of"   , "the LCD brightness", EEPROM_BACKLIGHT_MAX   }
  ,{ 2,  "Clock setup"        , "Set time"           , ""                  , 0                      }
  ,{ 3,  "IR Diagnose"        , "Check if IR is"     , "working"           , 0                      }
  ,{ 4,  "Remote Learning"    , "Map remote control" , "keys to functions" , 0                      }
  ,{ 5,  "White LED limit"    , "Maximum level of"   , "white LEDs"        , EEPROM_WHITE_MAX       }
  ,{ 6,  "Blue LED limit"     , "Maximum level of"   , "blue LEDs"         , EEPROM_BLUE_MAX        }
  ,{ 7,  "Moonlight level"    , "The level of Blue"  , "during moonlight"  , EEPROM_MOON_LEVEL      }
  ,{ 8,  "White LED start"    , "When to turn on"    , "white LEDs"        , EEPROM_WHITE_START     }
  ,{ 9,  "Blue LED start"     , "When to turn on"    , "blue LEDs"         , EEPROM_BLUE_START      }
  ,{ 10, "White LED duration" , "How long will"      , "whites stay on"    , EEPROM_WHITE_DURATION  }
  ,{ 11, "Blue LED duration"  , "How long will"      , "blues stay on"     , EEPROM_BLUE_DURATION   }
  ,{ 12, "Moon duration"      , "How long to stay in", "moonlight mode"    , EEPROM_MOON_DURATION   }
  ,{ 13, "Channel Delay"      , "The level of Blue"  , "durong moonlight"  , EEPROM_CHANNEL_DELAY   }
  ,{ 14, "Fade Duration"      , "Duration of sunrise", "and sunset"        , EEPROM_FADE_DURATION   }
};


MCP23XX lcd_mcp = MCP23XX(LCD_MCP_DEV_ADDR);

LCDI2C4Bit lcd = LCDI2C4Bit(LCD_MCP_DEV_ADDR, LCD_PHYS_LINES, LCD_PHYS_ROWS, PWM_BACKLIGHT_PIN);

IRrecv irrecv(IR_PIN);


template <class T> int EEPROM_writeAnything(int ee, const T& value)
{
    const byte* p = (const byte*)(const void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
	  EEPROM.write(ee++, *p++);
    return i;
}

template <class T> int EEPROM_readAnything(int ee, T& value)
{
    byte* p = (byte*)(void*)&value;
    int i;
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
      //menu();
  }
  
  else if (global_mode == 2) {       // Setting a value
    Serial.println("MODE 2");
       // if the menu item is not a simple byte value
    if ( menu_mapping[menu_position].eepromLoc == 0 ){
      if ( menu_mapping[menu_position].pos == 2 ){ //set clock
        //set_time();
      }else if ( menu_mapping[menu_position].pos == 3 ) {
        //diagnose_IR();
      }else if ( menu_mapping[menu_position].pos == 4 ) {
        //enter_setup_mode();
      }
    }else{
      //setCurrentMenuOption();   
    }
  }// global_mode == 2
  
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
      sprintf(ledValBuf,"PWM%02d:%02d ",bluePins[i], percent);
      lcd.cursorTo(0, i*10);
      lcd.print(ledValBuf);
  }
  for (i = 0; i < whiteChannels; i++){
      ledVal = setLed(minCounter, whitePins[i], whiteStartMins + channelDelay*i, whitePhotoPeriod, fadeDuration, whiteMax);
      percent = (int)(ledVal/2.55);
      sprintf(ledValBuf,"PWM%02d:%02d ",whitePins[i], percent);
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
  int i;
  Wire.begin();
  lcd.init();
  lcd.SetInputKeysMask(LCD_MCP_INPUT_PINS_MASK);
  lcd.set_backlight_levels( backlight_min ,backlight_max);
  lcd.lcd_fade_backlight_on();
  irrecv.enableIRIn();              // Start the receiver
  //RTC.setDate(second, minute, hour, dayOfWeek, dayOfMonth, month, year);
  
  //read remote keys from EEPROM  
  for (i=0; i<=MAX_FUNCTS; i++) {
    EEPROM_readAnything(40 + i*sizeof(key), key);
    ir_keypress_mapping[i].key_hex = key;
  }
  
}

byte scan_front_button( void ) {
  in_keys = lcd.ReadInputKeys();
  if ( (in_keys & LCD_MCP_INPUT_PINS_MASK ) != LCD_MCP_INPUT_PINS_MASK) {
    return 1;
  } 
  else {
    return 0;
  }
}

void enter_setup_mode( void )  {

  byte setup_finished = 0;
  byte idx = 0, i = 0;
  byte blink_toggle = 0;
  byte blink_count = 0;
  float ratio;
  byte eeprom_index = 0;
  byte key_pressed = 0;
  

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

#ifdef DEBUG_IR
    Serial.println(results.value, HEX);
#endif

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
  
#ifdef DBG
  Serial.println("LCD_print_long_hex()");
#endif
  byte Byte1 = ((p_value >> 0) & 0xFF);
  byte Byte2 = ((p_value >> 8) & 0xFF);
  byte Byte3 = ((p_value >> 16) & 0xFF);
  byte Byte4 = ((p_value >> 24) & 0xFF);

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

void  hex2ascii( const byte val, byte* ms, byte* ls ) {
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
    lcd.clear_L1();
    lcd.cursorTo(0,0);
    lcd.print("Unsupported");
    delay(500);
    lcd.clear_L1();
  //do something
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

