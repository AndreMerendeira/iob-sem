#include "iob-uart.h"
#include "printf.h"
#include "iob_timer.h"
#include "irq.h"

//holds response from SEM core
extern volatile char resp_buffer[1400];
//signal from interrupt handler that signals when full response has been received
extern volatile unsigned int resp_end;

/*############################################
Funtions to wait for x useconds, mseconds or seconds
############################################*/
void wait_useconds (unsigned int useconds);
void wait_mseconds (unsigned int mseconds);
void wait_seconds (unsigned int seconds);

/*############################################
Waits for the response from SEM Core
Response terminated by returning to a state (signaled by "> ")
############################################*/
void wait_resp ();

/*############################################
Waits for the response from SEM Core,
but marks the asked line with "<-----"
############################################*/
void wait_resp_w_word (unsigned int word);

/*############################################
Enters IDLE state and waits for response
############################################*/
void idle_cmd();

/*############################################
Enters OBSERVATION state and waits for response
############################################*/
void observation_cmd();

/*############################################
Enters DETECT ONLY state and waits for response
############################################*/
void detect_only_cmd();

/*############################################
Enters DIAGNOSTIC SCAN state and waits for response
############################################*/
void diagnostic_cmd();

/*############################################
Performs a software reset on the SEM core
The reset returns an initilization report
############################################*/
void reset_cmd();

/*############################################
Ask the core for a status report
############################################*/
void status_cmd();

/*############################################
Prints the contents of <lfa> Configuration Frame present in <slr> (Super Logic Region)
<word> argument is used to signal (with "<-----") which line contains the word we're interested in
<bit> argument is ignored, but necessary
############################################*/
void query_cmd (unsigned int slr, unsigned int lfa, unsigned int word, unsigned int bit);

/*############################################
Injects error in given 10 digits hex address
############################################*/
void err_injection_cmd_in_addr (char addr [10]);

/*############################################
Injects an error (bit flip) in <bit>, of <word> in <lfa> (Linear Frame Address),
of <slr> (Super Logic Region)
############################################*/
void err_injection_cmd (unsigned int slr, unsigned int lfa, unsigned int word, unsigned int bit);
