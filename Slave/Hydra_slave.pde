/*
 * Arduino ENC28J60 Ethernet shield web update client
 * Sends temp and humidity data every 30s to a given url using GET method.
 * 
 * Written by Andrew Lindsay, July 2009.
 * Portions of code taken from examples on nulectronics.com (sht11 code)
 * TCP/IP code originally from tuxgraphics.org - combined with ethershield library by me.
 *
 */
#include <Wire.h>
#include<stdlib.h>
#include "etherShield.h"
#include "OneWire.h"
#include "DallasTemperature.h"

// ** Local Network Setup **
// Please modify the following lines. mac and ip have to be unique
// in your local area network. You can not have the same numbers in
// two devices:
static uint8_t mymac[6] = { 
  0x00,0x1c,0x42,0x00,0x00,0x10};

// how did I get the mac addr? Translate the first 3 numbers into ascii is: TUX
// The IP address of the arduino.
static uint8_t myip[4] = {
  192,168,1,127};

// Default gateway. The ip address of your DSL/Cable router.
static uint8_t gwip[4] = {
  192,168,1,1};

// IP address of the host running php script (IP of the first portion of the URL):
static uint8_t webip[4] = {
  69,163,220,144};

// The name of the virtual host which you want to contact at webip (hostname of the first portion of the URL):
#define WEB_VHOST "somehost.com"
#define WEBURL "/storedata.php"

// End of configuration 

// listen port for tcp/www:
#define MYWWWPORT 80

// Data wire is plugged into pin 3 on the Arduino
#define ONE_WIRE_BUS 3

// Precision can be from 9 to 12 on the DS12B20
#define TEMPERATURE_PRECISION 11


// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);


// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// arrays to hold device addresses
DeviceAddress DTThermometer;
DeviceAddress RoomThermometer;
DeviceAddress SumpThermometer;


static volatile uint8_t start_web_client=0;  // 0=off but enabled, 1=send update, 2=sending initiated, 3=update was sent OK, 4=diable updates
static uint8_t web_client_attempts=0;
static uint8_t web_client_sendok=0;
static uint8_t resend=0;

int my_temp1 = 0;
int my_temp2 = 0;
int my_temp3 = 0;

union fUnion {
  byte _b[4]; 
  float _fval;
} 
FUnion;	 //DRPS = Drum Revs per Second

byte data[4];
int i = 0;
float PH=0.0;

#define STATUS_BUFFER_SIZE 50

#define BUFFER_SIZE 650
static uint8_t buf[BUFFER_SIZE+1];

// global string buffer for twitter message:
static char statusstr[STATUS_BUFFER_SIZE];

char buffer1[8];
char buffer2[8];
char buffer3[8];
char buffer4[8];
// Instantiate the EtherShield class
EtherShield es=EtherShield();

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage(uint8_t *buf)
{
  uint16_t plen;

  plen = es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR(""));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<html>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<head>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<title>TeraHz's Hydra</title>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</head>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<body>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<img src=\"http://hydra-reef.com/wiki/skins/hydralogo.png\" />"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<br />"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<table style=\"border:1px solid #6699cc; width:150px;\">"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td colspan=\"2\" style=\"text-align:center;\">Temperature</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>Sensor 1</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>"));
  plen=es.ES_fill_tcp_data(buf,plen,buffer1);
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("C&deg;"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>Sensor 2</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>"));
  plen=es.ES_fill_tcp_data(buf,plen,buffer2);
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("C&deg;"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>Sensor 3</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>"));
  plen=es.ES_fill_tcp_data(buf,plen,buffer3);
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("C&deg;"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</table>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<br />"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<table style=\"border:1px solid #6699cc; width:150px\">"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td colspan=\"2\" style=\"text-align:center;\">PH</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>Probe 1</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("<td>"));
  plen=es.ES_fill_tcp_data(buf,plen,buffer4);
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</td>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</tr>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</table>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</body>"));
  plen = es.ES_fill_tcp_data_p(buf,plen,PSTR("</html>"));
  return(plen);
}

// Browser callback, where we get to after receiving a reply to an update, should really 
// do somthing here to check all was OK.
void browserresult_callback(uint8_t statuscode,uint16_t datapos){
  if (statuscode==0){
    Serial.println("HTTP OK");
    web_client_sendok++;
  }
  else{
    Serial.print("HTTP status code:");
    Serial.println(statuscode, DEC);
  }
  // clear pending state at sucessful contact with the
  // web server even if account is expired:
  if (start_web_client==2) start_web_client=3;
}
// Perform setup on ethernet and oneWire
void setup(){
  Serial.begin(19200);
  Serial.println("Let's do it!");
  Wire.begin(4);                // join i2c bus with address #4
  Wire.onReceive(receiveEvent); // register event
  // initialize enc28j60
  es.ES_enc28j60Init(mymac);
  //init the ethernet/ip layer:
  es.ES_init_ip_arp_udp_tcp(mymac,myip, MYWWWPORT);
  // init the web client:
  es.ES_client_set_gwip(gwip);  // e.g internal IP of dsl router

  //setup temperature library
  sensors.begin();

  sensors.getAddress(DTThermometer, 0);
  sensors.getAddress(RoomThermometer, 1);
  sensors.getAddress(SumpThermometer, 2);
  //  DTThermometer = { 0x28, 0x14, 0x0B, 0xB2, 0x02, 0x00, 0x00, 0x30 };
  //  RoomThermometer = { 0x28, 0xE9, 0xBC, 0xB1, 0x02, 0x00, 0x00, 0x9E };
  //  SumpThermometer = {  0x28, 0xED, 0xA3, 0xB2, 0x02, 0x00, 0x00, 0xD9 };

  sensors.setResolution(DTThermometer, TEMPERATURE_PRECISION);
  sensors.setResolution(RoomThermometer, TEMPERATURE_PRECISION);
  sensors.setResolution(SumpThermometer, TEMPERATURE_PRECISION);


}


// The business end of things
void loop(){
  uint16_t dat_p;
  int8_t cmd;
  start_web_client=1;
  unsigned long lastSend = millis();
  unsigned long time;
  while(1){
    // handle ping and wait for a tcp packet
    dat_p=es.ES_packetloop_icmp_tcp(buf,es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf));
    if(dat_p==0){
      // Nothing received, jus see if there is anythng to do 
      // update every 60s
      time = millis();
      if( time > (lastSend + 59625) ) {
        resend=1; // resend once if it failed
        start_web_client=1;
        lastSend = time;
      }

      if (start_web_client==1) {
        // Read values from the sensor
        //        my_temp1 = read_value(buffer1, 0);//room
        //        my_temp2 = read_value(buffer2, 2);//sump
        //        my_temp2 = read_value(buffer3, 3);//DT
        dtostrf(PH,4,2,buffer4);

        Serial.print("PH: "); 
        Serial.println(buffer4);

        sensors.requestTemperatures();
        dtostrf(printData(RoomThermometer),4,2,buffer1);
        dtostrf(printData(DTThermometer),4,2,buffer3);
        dtostrf(printData(SumpThermometer),4,2,buffer2);

        sprintf( statusstr, "?p1=%s&p2=%s&p3=%s&p4=%s", buffer1, buffer2, buffer3, buffer4 );
        es.ES_client_set_wwwip(webip);
        es.ES_client_browse_url(PSTR(WEBURL),statusstr,PSTR(WEB_VHOST), &browserresult_callback);
        start_web_client=2;
        web_client_attempts++;
      }

      continue;
    }

    dat_p=print_webpage(buf);
    es.ES_www_server_reply(buf,dat_p); // send data
  }
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

// function to print the temperature for a device
float printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  Serial.print("Temp C: ");
  Serial.print(tempC);
  Serial.print(" Temp F: ");
  Serial.print(DallasTemperature::toFahrenheit(tempC));
  return tempC;
}


float printData(DeviceAddress deviceAddress)
{
  float tmp;
  Serial.print("Device Address: ");
  printAddress(deviceAddress);
  Serial.print(" ");
  tmp = printTemperature(deviceAddress);
  Serial.println();
  return tmp;
}
void receiveEvent(int howMany)
{
  Serial.println("Calling receiveEvent");
  int i = 0;
  while(Wire.available())    // slave may send less than requested
  {
    data[i] = Wire.receive(); // receive a byte as character
    i = i + 1;
  } 
  FUnion._b[0] = data[0];
  FUnion._b[1] = data[1];
  FUnion._b[2] = data[2];
  FUnion._b[3] = data[3];

  PH = FUnion._fval;
}




