
#ifndef P2_KEYBOARD_H_
#define P2_KEYBOARD_H_
#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "hardware/gpio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>

#define PS2FREQ   133600.0f

// GPIO pins to VIA chip
enum ps2_pins {PA0=0, PA1, PA2, PA3, PA4, PA5, PA6, PS2_DATA_PIN=15, PS2_CLK_PIN, PIRQ=27};

void initPS2(void);
unsigned char ps2GetChar(bool auto_print);
unsigned char ps2GetCharBlk(bool auto_print);
void clearPS2(void);
void ps2Task(bool auto_print);
void send2RAM(unsigned char c);

#endif // P2_KEYBOARD_H_
