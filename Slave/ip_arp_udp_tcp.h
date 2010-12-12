/*********************************************
 * vim:sw=8:ts=8:si:et
 * To use the above modeline in vim you must have "set modeline" in your .vimrc
 * Author: Guido Socher 
 * Copyright: GPL V2
 *
 * IP/ARP/UDP/TCP functions
 *
 * Chip type           : ATMEGA88 with ENC28J60
 *********************************************/
 /*********************************************
 * Modified: nuelectronics.com -- Ethershield for Arduino
 *********************************************/
//@{
#ifndef IP_ARP_UDP_TCP_H
#define IP_ARP_UDP_TCP_H
#include "ip_config.h"
#include <avr/pgmspace.h>

// you must call this function once before you use any of the other functions:
//extern void init_ip_arp_udp_tcp(uint8_t *mymac,uint8_t *myip,uint8_t wwwp);
//
//extern uint8_t eth_type_is_arp_and_my_ip(uint8_t *buf,uint16_t len);
//extern uint8_t eth_type_is_ip_and_my_ip(uint8_t *buf,uint16_t len);
//extern void make_arp_answer_from_request(uint8_t *buf);
//extern void make_echo_reply_from_request(uint8_t *buf,uint16_t len);
//extern void make_udp_reply_from_request(uint8_t *buf,char *data,uint8_t datalen,uint16_t port);


//extern void make_tcp_synack_from_syn(uint8_t *buf);
//extern void init_len_info(uint8_t *buf);
//extern uint16_t get_tcp_data_pointer(void);
//extern uint16_t fill_tcp_data_p(uint8_t *buf,uint16_t pos, const prog_char *progmem_s);
//extern uint16_t fill_tcp_data(uint8_t *buf,uint16_t pos, const char *s);
//extern void make_tcp_ack_from_any(uint8_t *buf);
//extern void make_tcp_ack_with_data(uint8_t *buf,uint16_t dlen);
//extern void make_arp_request(uint8_t *buf, uint8_t *server_ip);
//extern uint8_t arp_packet_is_myreply_arp ( uint8_t *buf );
//extern void tcp_client_send_packet(uint8_t *buf,uint16_t dest_port, uint16_t src_port, uint8_t flags, uint8_t max_segment_size, 
//	uint8_t clear_seqck, uint16_t next_ack_num, uint16_t dlength, uint8_t *dest_mac, uint8_t *dest_ip);
//extern uint16_t tcp_get_dlength ( uint8_t *buf );

// -- web server functions --
// you must call this function once before you use any of the other server functions:
extern void init_ip_arp_udp_tcp(uint8_t *mymac,uint8_t *myip,uint16_t port);
// for a UDP server:
extern uint8_t eth_type_is_arp_and_my_ip(uint8_t *buf,uint16_t len);
extern uint8_t eth_type_is_ip_and_my_ip(uint8_t *buf,uint16_t len);
extern uint8_t eth_type_is_arp_reply(uint8_t *buf);
extern uint8_t eth_type_is_arp_req(uint8_t *buf);

extern void make_udp_reply_from_request(uint8_t *buf,char *data,uint8_t datalen,uint16_t port);
extern void make_echo_reply_from_request(uint8_t *buf,uint16_t len);

extern void make_arp_answer_from_request(uint8_t *buf);
extern void make_tcp_synack_from_syn(uint8_t *buf);
extern void init_len_info(uint8_t *buf);
extern uint16_t get_tcp_data_pointer(void);

extern void make_tcp_ack_from_any(uint8_t *buf);
extern void make_tcp_ack_with_data(uint8_t *buf,uint16_t dlen);


// return 0 to just continue in the packet loop and return the position 
// of the tcp data if there is tcp data part
extern uint16_t packetloop_icmp_tcp(uint8_t *buf,uint16_t plen);
// functions to fill the web pages with data:
extern uint16_t fill_tcp_data_p(uint8_t *buf,uint16_t pos, const prog_char *progmem_s);
extern uint16_t fill_tcp_data(uint8_t *buf,uint16_t pos, const char *s);
// send data from the web server to the client:
extern void www_server_reply(uint8_t *buf,uint16_t dlen);

// -- client functions --
#if defined (WWW_client) || defined (NTP_client)
extern uint8_t client_store_gw_mac(uint8_t *buf, uint8_t *gwipaddr);
extern void client_set_gwip(uint8_t *gwipaddr);
extern void client_set_wwwip(uint8_t *wwwipaddr);
extern void client_arp_whohas(uint8_t *buf,uint8_t *ip_we_search) ;
#endif

#define HTTP_HEADER_START ((uint16_t)TCP_SRC_PORT_H_P+(buf[TCP_HEADER_LEN_P]>>4)*4)
#ifdef WWW_client
// ----- http get
extern void client_browse_url(prog_char *urlbuf, char *urlbuf_varpart, prog_char *hoststr,void (*callback)(uint8_t,uint16_t));
// The callback is a reference to a function which must look like this:
// void browserresult_callback(uint8_t statuscode,uint16_t datapos)
// statuscode=0 means a good webpage was received, with http code 200 OK
// statuscode=1 an http error was received
// statuscode=2 means the other side in not a web server and in this case datapos is also zero
// ----- http post
// client web browser using http POST operation:
// additionalheaderline must be set to NULL if not used.
// postval is a string buffer which can only be de-allocated by the caller 
// when the post operation was really done (e.g when callback was executed).
// postval must be urlencoded.
extern void client_http_post(prog_char *urlbuf, prog_char *hoststr, prog_char *additionalheaderline, prog_char *method, char *postval,void (*callback)(uint8_t,uint16_t));
// The callback is a reference to a function which must look like this:
// void browserresult_callback(uint8_t statuscode,uint16_t datapos)
// statuscode=0 means a good webpage was received, with http code 200 OK
// statuscode=1 an http error was received
// statuscode=2 means the other side in not a web server and in this case datapos is also zero
#endif

#ifdef NTP_client
extern void client_ntp_request(uint8_t *buf,uint8_t *ntpip,uint8_t srcport);
extern uint8_t client_ntp_process_answer(uint8_t *buf,uint32_t *time,uint8_t dstport_l);
#endif

// you can find out who ping-ed you if you want:
extern void register_ping_rec_callback(void (*callback)(uint8_t *srcip));

#ifdef PING_client
extern void client_icmp_request(uint8_t *buf,uint8_t *destip);
// you must loop over this function to check if there was a ping reply:
extern uint8_t packetloop_icmp_checkreply(uint8_t *buf,uint8_t *ip_monitoredhost);
#endif // PING_client

#ifdef WOL_client
extern void send_wol(uint8_t *buf,uint8_t *wolmac);
#endif // WOL_client

#endif /* IP_ARP_UDP_TCP_H */
//@}
