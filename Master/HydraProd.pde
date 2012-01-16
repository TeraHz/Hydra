#include <Wire.h>
#include <WProgram.h>
#include <EEPROM.h> 

//local libs
#include "LCDi2c4bit.h"
#include "DS1307.h"
#include "mcp23xx.h"
#include "IRremote.h"
#include "I2CRelay.h"
#include "Hydra.h"
#include "OneWire.h"
#include "DallasTemperature.h"



//**********************************
//
//              SETUP
//
//**********************************

//remove coment to enable various debug modes
//#define DEBUG       //general    
//#define DEBUG_LED   //extra for LEDs    
//#define DEBUG_IR    //extra for IR
//#define DEBUG_CLOCK //extra for RTC

// select one of the input methods
#define IR_INPUT                    // used this if you are going to have IR input
#define IR_PIN                 6    // Sensor data-out pin, wired direct
//#define KEYPAD_INPUT               // use this if you are going to have a physical keypad


#define LEDS                        // comment this out if you don't have LEDs


#define PH_READ_PIN            3    // analog pin to poll PH
#define PWM_BACKLIGHT_PIN      8    // pwm-controlled LED backlight
#define SplashScrnTime         2    //  Splash Screen display time, seconds  


#define ONE_WIRE_BUS 2
#define TEMPERATURE_PRECISION 10  

//ignore these if you don't use LEDs
uint8_t bluePins[]        =   { 
  5, 9};  // pwm pins for blues

uint8_t whitePins[]       = { 
  10, 11};  // pwm pins for whites

uint16_t blueChannels      =         2; // how many PWMs for blues (count from above)

uint16_t whiteChannels     =         2; // how many PWMs for whites (count from above)

uint16_t blueStartMins    =       690;  // minute to start blues. Change this to the number of minutes past
// midnight you want the blues to start.

uint16_t whiteStartMins   =       750;  // minute to start whites. Same as above.

uint16_t bluePhotoPeriod  =       600;  // photoperiod in minutes, blues. Change this to alter the total
// photoperiod for blues.

uint16_t whitePhotoPeriod =       360;  // photoperiod in minutes, whites. Same as above.

uint16_t fadeDuration     =       120;  // duration of the fade on and off for sunrise and sunset. Change
// this to alter how long the fade lasts.

uint8_t moonLevel         =         4;  // level of blues for moonlights

uint16_t moonDuration     =        60;  // duration of moonlights

uint8_t blueMax           =       255;  // max intensity for blues. Change if you want to limit max intensity.

uint8_t whiteMax          =       255;  // max intensity for whites. Same as above.
uint16_t channelDelay     =         0;  // this sets the delay in minutes between strings
// of the same color for simulating directional light.
// 0 means all will ramp up at the same time. 
//**********************************
//
//            END SETUP
//
//**********************************



const char Title[]   = { 
  "Hydra-THZ" };
const char Version[] = {  
  "0.04" };

uint8_t lcd_in_use_flag = 0;
uint8_t psecond = 0;
uint16_t minCounter = 0;
uint16_t tempMinHolder = 0; // this is used for holding the temp value in menu setting
char strTime[20];
char tmp[20];
float PH = 0;
float TEMP = 0;
uint8_t second = 00;
uint8_t minute = 30;
uint8_t hour = 18;
uint8_t dayOfWeek = 4;
uint8_t dayOfMonth = 3;
uint8_t month = 3;
uint8_t year = 11;
uint8_t go_to_setup_mode = 0;
uint8_t global_mode = 0;
uint8_t sPos = 1; // position for setting
union fUnion {
  byte _b[4]; 
  float _fval;
} 
FUnion;
uint8_t in_keys = 0;
long key;
uint8_t ms,ls, ts, tmi, th, tdw, tdm, tmo, ty;
decode_results results;
uint8_t menu_position = 0;
boolean first = true;

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

// has to be the last entry in this list
#define IFC_KEY_SENTINEL            9   // this must always be the last in the list
#define MAX_FUNCTS                  IFC_KEY_SENTINEL

#define EEPROM_MAGIC              0

#ifdef LEDS
#define EEPROM_WHITE_LVL          1    // white LED brightness
#define EEPROM_BLUE_LVL           2    // blue LED brightness
#define EEPROM_BLUE_MAX           3    // Cap for blue light
#define EEPROM_WHITE_MAX          4    // Cap for white light
#define EEPROM_WHITE_DURATION     5    // 2 bytes; how long to keep whites on
#define EEPROM_BLUE_DURATION      7   // 2 bytes; how long to keep blues on
#define EEPROM_MOON_LEVEL         9   // level of moon lights
#define EEPROM_MOON_DURATION      10   // 2 bytes; Duration of moon lights
#define EEPROM_BLUE_START         12   // 2 bytes; Starting time for blues
#define EEPROM_WHITE_START        14   // 2 bytes; Starting time for whites
#define EEPROM_CHANNEL_DELAY      16   // 2 bytes; Delay between channels
#define EEPROM_FADE_DURATION      18   // 2 bytes; Suration of sunrise/sunset
#endif

// this is a temporary holding area that we write to, key by key; and then dump all at once when the user finishes the last one
long ir_key_bank1[MAX_FUNCTS+1];

// this is used in learn-mode, to prompt the user and assign enums to internal functions
struct _ir_keypress_mapping {
  long key_hex;
  uint8_t internal_funct_code;
  char funct_name[16];
}

ir_keypress_mapping[MAX_FUNCTS+1] = {
  { 
    0x00, IFC_DIAG_IR_RX,      "Debug IR (rx)"                  }
  ,{ 
    0x00, IFC_MOONLIGHT_ONOFF, "Moonlight"                      }
  ,{ 
    0x00, IFC_MENU,            "Menu"                           }
  ,{ 
    0x00, IFC_UP,              "Up Arrow"                       }
  ,{ 
    0x00, IFC_DOWN,            "Down Arrow"                     }
  ,{ 
    0x00, IFC_LEFT,            "Left Arrow"                     }
  ,{ 
    0x00, IFC_RIGHT,           "Right Arrow"                    }
  ,{ 
    0x00, IFC_OK,              "Confirm/Select"                 }
  ,{ 
    0x00, IFC_CANCEL,          "Back/Cancel"                    }
  ,{ 
    0x00, IFC_KEY_SENTINEL,    "NULL"                           }
};

// menu struct:
struct _menu_mapping {
  uint8_t pos;
  char description[20];
  uint8_t eepromLoc;
  uint8_t size;
}

// Menu

#ifdef LEDS
#define MENU_OPTIONS 13
#else
#define MENU_OPTIONS 3
#endif

menu_mapping[MENU_OPTIONS] = {
  { 
    0,  "Clock setup"        , 0                      , 0             }
  ,{ 
    1,  "IR Diagnose"        , 0                      , 0             }
  ,{ 
    2,  "Remote Learning"    , 0                      , 0             }
#ifdef LEDS
  ,{ 
    3,  "White LED limit"    , EEPROM_WHITE_MAX       , 1             }
  ,{ 
    4,  "Blue LED limit"     , EEPROM_BLUE_MAX        , 1             }
  ,{ 
    5,  "Moonlight level"    , EEPROM_MOON_LEVEL      , 1             }
  ,{ 
    6,  "White LED start"    , EEPROM_WHITE_START     , 2             }
  ,{ 
    7,  "Blue LED start"     , EEPROM_BLUE_START      , 2             }
  ,{ 
    8, "White LED duration"  , EEPROM_WHITE_DURATION  , 2             }
  ,{ 
    9, "Blue LED duration"   , EEPROM_BLUE_DURATION   , 2             }
  ,{ 
    10, "Moon duration"      , EEPROM_MOON_DURATION   , 2             }
  ,{ 
    11, "Channel Delay"      , EEPROM_CHANNEL_DELAY   , 2             }
  ,{ 
    12, "Fade Duration"      , EEPROM_FADE_DURATION   , 2             }
#endif
};


MCP23XX lcd_mcp = MCP23XX(LCD_MCP_DEV_ADDR);
MCP23XX relay_mcp = MCP23XX(RELAY_MCP_DEV_ADDR);

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);
DeviceAddress tempSensor;
LCDI2C4Bit lcd = LCDI2C4Bit(LCD_MCP_DEV_ADDR, LCD_PHYS_LINES, LCD_PHYS_ROWS, PWM_BACKLIGHT_PIN);

#ifdef IR_INPUT
IRrecv irrecv(IR_PIN);
#endif

I2CRelay relay = I2CRelay();

void setup() {
#ifdef DEBUG
  Serial.begin(9600);
#endif
  digitalWrite(PWM_BACKLIGHT_PIN, HIGH); //turn on the LCD backlight
  init_components();
  signon_msg();

  // check if clock is running
  if (!RTC.isRunning()){
#ifdef DEBUG_CLOCK
    Serial.print("Clock is NOT running");
#endif    
    //  set some  date
    RTC.setDate(second, minute, hour, dayOfWeek, dayOfMonth, month, year);
#ifdef IR_INPUT
    //  Enter IR learning mode
    menu_position = 2;
    global_mode = 2; 
#endif

  }
  else{
#ifdef DEBUG_CLOCK
    Serial.println("Clock is running");
#endif 
  }
  
  uint8_t dc[8] = {     0b00011000,
		        0b00011000,
			0b00000111,
			0b00000100,
			0b00000100,
			0b00000100,
			0b00000111,
			0b00000000	};

  lcd.setCustomCharacter(1,dc);
  
  uint8_t df[8] = {     0b00011000,
		        0b00011000,
			0b00000111,
			0b00000100,
			0b00000110,
			0b00000100,
			0b00000100,
			0b00000000	};

  lcd.setCustomCharacter(2,df);
  uint8_t curr[8] = {   0b00000000,
		        0b00000100,
			0b00000110,
			0b00011111,
			0b00000110,
			0b00000100,
			0b00000000,
			0b00000000	};

  lcd.setCustomCharacter(3,curr);

  sensors.begin();
  sensors.getAddress(tempSensor,0);
  printAddress(tempSensor);
  sensors.setResolution(tempSensor, TEMPERATURE_PRECISION);
  
}

void loop() {

  if (global_mode == 0) {            // main 'everyday use' mode
    onKeyPress();
  }//global_mode == 0
  else if (global_mode == 1) {       // Main Menu
    menu();
  }
  else if (global_mode == 2) {       // Setting a value
#ifdef DEBUG  
    // menu positions
    // 0 - "Clock setup" 
    // 1 - "IR Diagnose"
    // 2 - "Remote Learning"
    // 3 - "White LED limit"
    // 4 - "Blue LED limit"
    // 5 - "Moonlight level"
    // 6 - "White LED start"
    // 7 - "Blue LED start" 
    // 8 - "White LED duration"
    // 9 - "Blue LED duration"
    //10 - "Moon duration"
    //11 - "Channel Delay"
    //12 - "Fade Duration"
    Serial.print("MODE 2; ");
    Serial.print("menu_position = ");
    Serial.println(menu_position,DEC);
#endif
    // if the menu item is not a simple uint8_t value
    if ( menu_mapping[menu_position].eepromLoc == 0 ){
      if ( menu_mapping[menu_position].pos == 0 ){ //set clock
        if (first){
#ifdef DEBUG_CLOCK
          Serial.println("Entering clock setup");         
#endif
          lcd.send_string("Use arrows to adjust", LCD_CURS_POS_L2_HOME);
          sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d %d",th, tmi, ts, tdm, tmo, ty, tdw);
          update_clock(2,0);   
          lcd.send_string("HH:MM:SS DD:MM:YY DW",LCD_CURS_POS_L4_HOME);
          first = false;
        }
        set_time();
      }
      else if ( menu_mapping[menu_position].pos == 1 ) {
        if (first){
#ifdef DEBUG_IR
          Serial.println("Entering IR Diagnlose");         
#endif
          first = false;
        }
        diagnose_IR();
      }
      else if ( menu_mapping[menu_position].pos == 2 ) {
        if (first){
#ifdef DEBUG_IR       
          Serial.println("Entering IR Learning");         
#endif
          first = false;
        }
        enter_setup_mode();
      }
    }
    else{
      if (first){
#ifdef DEBUG          
        Serial.println("Entering setCurrentMenuOption");         
#endif
          
        if (menu_mapping[menu_position].size == 2){
          EEPROM_readAnything(menu_mapping[menu_position].eepromLoc, tempMinHolder);
          lcd.send_string("Value is in minutes", LCD_CURS_POS_L3_HOME);
        }else if (menu_mapping[menu_position].size == 1){
          uint8_t tmp;
          EEPROM_readAnything(menu_mapping[menu_position].eepromLoc, tmp);
          tempMinHolder = tmp;
          lcd.send_string("255 - MAX; 0 - MIN  ", LCD_CURS_POS_L3_HOME);
        }
        lcd.cursorTo(3,0);
        printMenuValue();
        first = false;
      }
      setCurrentMenuOption(menu_mapping[menu_position].size);   
    }
  }// global_mode == 2

#ifdef DEBUG_CLOCK
  Serial.println("trying to get date and time");
#endif  

  RTC.getDate(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year);

#ifdef DEBUG_CLOCK
  Serial.println("got date and time");
  Serial.print("second is ");
  Serial.print(second,DEC);
  Serial.print(" psecond is ");
  Serial.println(psecond,DEC);
#endif

  if (psecond != second){

#ifdef DEBUG_CLOCK
    if (!RTC.isRunning()){
      Serial.println("Clock is NOT running");
    }
    else{
      Serial.println("Clock is running");
    }
#endif 

    //Serial.println("tick");
    psecond = second;
    run_sec();
  }

  delay(50);

}

void run_sec( void ){ // runs every second
  sensors.requestTemperatures();
  minCounter = hour * 60 + minute;
  if (global_mode == 0){
    sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d",hour, minute, second, dayOfMonth, month, year);

    update_ph(2,0);
    update_temp(2,14);
    update_clock(3,3);
  }

#ifdef LEDS
  update_leds();
#endif

  send_to_slave();
}


void update_clock(uint8_t x, uint8_t y){
  lcd.cursorTo(x,y);
  lcd.print(strTime);
}

void update_ph(uint8_t x, uint8_t y){
  lcd.cursorTo(x,y);
  lcd.print("pH:");
  getPH();
  lcd.print(PH);
  lcd.print(" ");


}

void update_temp(uint8_t x, uint8_t y){
  lcd.cursorTo(x,y);
  getTemp();
  if (TEMP < 0){
  }else{
    lcd.print(TEMP);
    lcd.write(1);
  }
}

void getPH( void ){
  double sum = 0.0;
  uint8_t samples = 15;
  for (uint8_t i=0; i<=samples;i++){
    sum+=analogRead(PH_READ_PIN);
    delay(20);
  }
  PH = sum/15/46;
}

void getTemp(){
  TEMP = sensors.getTempC(tempSensor);
#ifdef DEBUG
  Serial.print("Temp C: ");
  Serial.println(TEMP);
#endif
}
#ifdef LEDS
void update_leds( void ){
  uint8_t i;
  uint8_t ledVal;
  uint8_t percent;
  char ledValBuf[20];
  for (i = 0; i < blueChannels; i++){
    ledVal = setLed(minCounter, bluePins[i], blueStartMins + channelDelay*i, bluePhotoPeriod, fadeDuration, blueMax);
    percent = (int)(ledVal/2.55);
    sprintf(ledValBuf,"B%d:%02d ",i+1, percent);
    if (global_mode == 0){
      lcd.cursorTo(0, i*7);
      lcd.print(ledValBuf);
    }
  }
  for (i = 0; i < whiteChannels; i++){
    ledVal = setLed(minCounter, whitePins[i], whiteStartMins + channelDelay*i, whitePhotoPeriod, fadeDuration, whiteMax);
    percent = (int)(ledVal/2.55);
    sprintf(ledValBuf,"W%d:%02d ",i+1, percent);
    if (global_mode == 0){
      lcd.cursorTo(1, i*7);
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
#ifdef DEBUG_LED
  Serial.print("current time: ");
  Serial.println(mins);
  Serial.print("Pin: ");
  Serial.println(ledPin,DEC);
  Serial.print("start time: ");
  Serial.println(start);
  Serial.print("photoperiod: ");
  Serial.println(period);
  Serial.print("fade: ");
  Serial.println(fade);
  Serial.print("max value for LED: ");
  Serial.println(ledMax, DEC);
#endif
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

#ifdef DEBUG_LED
  Serial.print("Setting LED to: ");
  Serial.println(ledVal, DEC);
#endif  
  analogWrite(ledPin, ledVal);

  return ledVal;  

}
#endif

void send_to_slave( void ){
  FUnion._fval = PH;
  Wire.beginTransmission(4); // transmit to device #4
  Wire.send(FUnion._b,4);    // sends one byte  
  Wire.endTransmission();    // stop transmitting
}


void  signon_msg( void ) {  
  long start_time = millis();

  lcd.clear();

  lcd.send_string(Title,   LCD_CURS_POS_L1_HOME);
  lcd.send_string(Version, LCD_CURS_POS_L2_HOME);

  delay(SplashScrnTime*1000);
  lcd.clear();
}

// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}


void init_components ( void ) {
  uint16_t i;
  Wire.begin();
  //start LCD
  lcd.init();
  
#ifdef IR_INPUT
  //start IR sensor
  irrecv.enableIRIn();


  //read remote keys from EEPROM  
  for (i=0; i<=MAX_FUNCTS; i++) {
    EEPROM_readAnything(40 + i*sizeof(key), key);
    ir_keypress_mapping[i].key_hex = key;
  }
#endif


#ifdef LEDS
  //check if eeprom is good and if not set defaults
  if (EEPROM.read(EEPROM_MAGIC) != 01) {
    // init all of EEPROM area

    EEPROM_writeAnything(EEPROM_WHITE_LVL,         0);
    EEPROM_writeAnything(EEPROM_BLUE_LVL,          0);
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
  readFromEEPROM();

#endif
}

void readFromEEPROM ( void ){

#ifdef LEDS
  //read settings from EEPROM
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
#endif

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

    while ( (key = get_input_key()) == 0 ) {

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
  first = true;
  delay(1000);

  lcd.clear();
}

long get_input_key( void ){
#ifdef IR_INPUT
  return get_IR_key();
#endif

#ifdef KEYPAD_INPUT
  return get_KP_key();
#endif

}


#ifdef IR_INPUT
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
    } 
    else {
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

void diagnose_IR( void ){

  /*
   * we got a valid IR start pulse! fetch the keycode, now.
   */

  key = get_input_key();
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
    first = true;
    delay (200); //Debounce switch
  }

  delay(100);
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value

}
#endif

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

  key = get_input_key();
  if (key == 0) {
    return;   // try again to sync up on an IR start-pulse
  }
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
#ifdef LEDS
    if (blueMax < 255){
      blueMax++;
    }
#endif
  }

  // key = DOWN
  else if (key == ir_keypress_mapping[IFC_DOWN].key_hex) {
#ifdef LEDS
    if (blueMax > 0){
      blueMax--;
    }
#endif
  }

  // key = LEFT
  else if (key == ir_keypress_mapping[IFC_LEFT].key_hex) {
#ifdef LEDS
    if (whiteMax < 255){
      whiteMax--;
    }
#endif
  }

  // key = RIGHT
  else if (key == ir_keypress_mapping[IFC_RIGHT].key_hex) {
#ifdef LEDS
    if (whiteMax > 0){
      whiteMax++;
    }
#endif
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
  }
  else{
    Serial.println("unsupported");
  }

  delay(100);
  irrecv.resume();
}


/***********************/
/****** MAIN MENU ******/
/***********************/
void menu( void ) {
  key = get_input_key();
  if (key == 0) {
    return;
  }

  if (key == ir_keypress_mapping[IFC_OK].key_hex ) {
    lcd.clear();
    RTC.getDate(&ts, &tmi, &th, &tdw, &tdm, &tmo, &ty);
    lcd.send_string(menu_mapping[menu_position].description, LCD_CURS_POS_L1_HOME);
    //EEPROM_readAnything(menu_mapping[menu_position].eepromLoc, sVal);
    global_mode = 2;
    delay (100);
  }
  else if (key == ir_keypress_mapping[IFC_DOWN].key_hex){
    if (menu_position < MENU_OPTIONS-1){
      menu_position++;
    }
    else{
      menu_position = 0;
    }
    update_menu();
    delay (100);
  }
  else if (key == ir_keypress_mapping[IFC_UP].key_hex){ 
    if (menu_position > 0){
      menu_position--;
    }
    else{
      menu_position = MENU_OPTIONS-1;
    }
    update_menu();
    delay (100);
  }
  else if (key == ir_keypress_mapping[IFC_CANCEL].key_hex){
    global_mode = 0;
    first = true;
    lcd.clear();
    delay (100);
  } 

  delay(100);

  irrecv.resume(); // we just consumed one key; 'start' to receive the next value

}


void update_menu( void ){
  byte next = menu_position+1;
  byte nextnext = menu_position+2;
  byte prev = menu_position-1;
  lcd.clear();
  if (menu_position < 1){
    prev = MENU_OPTIONS-1;
  }
  if (menu_position == MENU_OPTIONS-1){
    next = 0;
    nextnext = 1;
  }else if (menu_position == MENU_OPTIONS-2){
    nextnext = 0;
  }
  
  lcd.send_string(menu_mapping[prev].description, LCD_CURS_POS_L1_HOME);
  lcd.cursorTo(1,0);
  lcd.print(" ");
  lcd.write(3);
  lcd.print(menu_mapping[menu_position].description);
  lcd.send_string(menu_mapping[next].description, LCD_CURS_POS_L3_HOME);
  lcd.send_string(menu_mapping[nextnext].description, LCD_CURS_POS_L4_HOME);
}


void set_time( void ){
  key = get_input_key();
  if (key == 0) {
    return;
  }
  // key = OK
  if (key == ir_keypress_mapping[IFC_OK].key_hex ) {
    RTC.setDate(ts, tmi, th, tdw, tdm, tmo, ty);
    global_mode = 0;
    lcd.clear();
    first=true;
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
    }
    else if (sPos == 2){
      if (tmi < 59) {
        tmi++;
      } 
      else {
        tmi = 0;  // wrap around
      }
    }
    else if (sPos == 3){
      if (ts < 59) {
        ts++;
      } 
      else {
        ts = 0;  // wrap around
      }
    }
    else if (sPos == 4){
      if (tdm < 31) {
        tdm++;
      } 
      else {
        tdm = 1;  // wrap around
      }
    }
    else if (sPos == 5){
      if (tmo < 12) {
        tmo++;
      } 
      else {
        tmo = 1;  // wrap around
      }
    }
    else if (sPos == 6){
      if (ty < 99) {
        ty++;
      } 
      else {
        ty = 0;  // wrap around
      }
    }
    else if (sPos == 7){
      if (tdw < 7) {
        tdw++;
      } 
      else {
        tdw = 1;  // wrap around
      }
    }
    delay (100);
    sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d %d",th, tmi, ts, tdm, tmo, ty, tdw);
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
    }
    else if (sPos == 2){
      if (tmi > 0) {
        tmi--;
      } 
      else {
        tmi = 59;  // wrap around
      }
    }
    else if (sPos == 3){
      if (ts > 0) {
        ts--;
      } 
      else {
        ts = 59;  // wrap around
      }
    }
    else if (sPos == 4){
      if (tdm > 1) {
        tdm--;
      } 
      else {
        tdm = 31;  // wrap around
      }
    }
    else if (sPos == 5){
      if (tmo > 1) {
        tmo--;
      } 
      else {
        tmo = 12;  // wrap around
      }
    }
    else if (sPos == 6){
      if (ty > 1) {
        ty--;
      } 
      else {
        ty = 99;  // wrap around
      }
    }
    else if (sPos == 7){
      if (tdw > 1) {
        tdw--;
      } 
      else {
        tdw = 7;  // wrap around
      }   
    }
    delay (100);
    sprintf(strTime,"%02d:%02d:%02d %02d/%02d/%02d %d",th, tmi, ts, tdm, tmo, ty, tdw);
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
    first = true;
  } 
  delay(100);
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value

}

/**********************************/
/****** GENERIG MENU HANDLER ******/
/**********************************/
void setCurrentMenuOption ( uint8_t size ) {
  key = get_input_key();
  if (key == 0) {
    return;
  }
  // key = OK
  if (key == ir_keypress_mapping[IFC_OK].key_hex ) {
    if (size == 2){
      EEPROM_writeAnything(menu_mapping[menu_position].eepromLoc, tempMinHolder);
    }else if (size == 1){
      EEPROM_writeAnything(menu_mapping[menu_position].eepromLoc, (uint8_t)tempMinHolder);
    }
    global_mode = 0;
    readFromEEPROM();
    lcd.clear();
    first=true;
  }

  // key = Up
  else if (key == ir_keypress_mapping[IFC_UP].key_hex){
    if (size == 2){
      if (tempMinHolder < 1440){
        tempMinHolder++;
      }
      else{
        lcd.send_string("Cannot go over 24hrs", LCD_CURS_POS_L2_HOME);
        delay(1000);
        lcd.clear_L2();
      }
    }else if (size == 1){
            if (tempMinHolder < 255){
        tempMinHolder++;
      }
      else{
        lcd.send_string("Cannot go over 255 ", LCD_CURS_POS_L2_HOME);
        delay(1000);
        lcd.clear_L2();
      }
    }
    
    lcd.cursorTo(3,0);
    printMenuValue();
  }

  // key = Down
  else if (key == ir_keypress_mapping[IFC_DOWN].key_hex){

    if (tempMinHolder > 0){
      tempMinHolder--;
    }
    else{
      lcd.send_string("Cannot go under 0  ", LCD_CURS_POS_L2_HOME);
      delay(1000);
      lcd.clear_L2();
    }
    lcd.cursorTo(3,0);
    printMenuValue();
  }

  // key = Left
  else if (key == ir_keypress_mapping[IFC_LEFT].key_hex){

  }

  // key = Right
  else if (key == ir_keypress_mapping[IFC_RIGHT].key_hex){ 

  }

  // key = Cancel
  else if (key == ir_keypress_mapping[IFC_CANCEL].key_hex){
    lcd.clear();
    global_mode = 0;
    delay (100);
    first = true;
  } 

  delay(100);
  irrecv.resume(); // we just consumed one key; 'start' to receive the next value
}


void printMenuValue(){
#ifdef DEBUG
      Serial.print("menu_position: ");
      Serial.println(menu_position);
#endif
  if (menu_mapping[menu_position].size == 2){
      uint8_t hr = tempMinHolder/60;
      uint8_t mn = tempMinHolder - (hr*60);
      sprintf(tmp,"%02u   (%02u:%02u)   ",tempMinHolder, hr, mn);
#ifdef DEBUG
      Serial.print("tmp: ");
      Serial.println(tmp);
#endif
    }else if (menu_mapping[menu_position].size == 1){
      uint8_t pct = (tempMinHolder/2.55);
      sprintf(tmp,"%02u   (%02u%%)      ",tempMinHolder, pct);
#ifdef DEBUG
      Serial.print("tmp: ");
      Serial.println(tmp);
#endif
    }
  lcd.print(tmp);
}
