#ifndef __6502_IO__
#define __6502_IO__

#include <stdio.h>

#include "cpu.h"

#define IO_PUTCHAR    0xFF00
#define IO_GETCHAR    0xFF01

#define IO_PAINT_BLACK     0x00
#define IO_PAINT_RED       0x01
#define IO_PAINT_GREEN     0x02
#define IO_PAINT_YELLOW    0x03
#define IO_PAINT_BLUE      0x04
#define IO_PAINT_MAGENTA   0x05
#define IO_PAINT_CYAN      0x06
#define IO_PAINT_WHITE     0x07

#define VIA1_ADDRESS       0x8020   // VIA1 address space
#define VIA1_PORTB         (VIA1_ADDRESS + 0x00)
#define VIA1_PORTA         (VIA1_ADDRESS + 0x01)
#define VIA1_DDRB          (VIA1_ADDRESS + 0x02)
#define VIA1_DDRA          (VIA1_ADDRESS + 0x03)
#define VIA1_IER           (VIA1_ADDRESS + 0x0e)

void init_io();
void finish_io();
void handle_io(cpu *m, bool rwb);

#endif
