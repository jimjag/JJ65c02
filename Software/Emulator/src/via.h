#ifndef __6502_VIA__
#define __6502_VIA__

#include <stdint.h>

typedef struct {
  // Current contents of PORTB
  uint8_t portb;
  // Current contents of PORTA
  uint8_t porta;
  // Current contents of Data Direction Register B
  uint8_t ddrb;
  // Current contents of Data Direction Register A
  uint8_t ddra;
} via;

via * new_via();
void destroy_via(via* v);

#endif
