/**
 *
 * HARDWARE CONNECTIONS
 *  - GPIO 16 ---> VGA Hsync
 *  - GPIO 17 ---> VGA Vsync
 *  - GPIO 18 ---> 470 ohm resistor ---> VGA Red
 *  - GPIO 19 ---> 470 ohm resistor ---> VGA Blue
 *  - GPIO 20 ---> 470 ohm resistor ---> VGA Green
 *  - GPIO 21 ---> 1k ohm resistor ---> VGA Intensity (bright)
 *  - GPIO 14 ---> PS2 Data pin
 *  - GPIO 15 ---> PS2 Clock pin
 *  - RP2040 GND ---> VGA GND
 *
 * RESOURCES USED
 *  - VGA:
 *  -   PIO state machines 0, 1, and 2 on PIO instance 0
 *  -   DMA channels 0, 1, 2, and 3
 *  -   153.6 kBytes of RAM (for pixel color data)
 *  - PS2:
 *  -   PIO state machine 0 on PIO instance 1
 *
 */

#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#define PS2_DATA_PIN 14
#define PS2_CLK_PIN 15

void initPS2(void);
unsigned char ps2GetChar(void);
unsigned char ps2GetCharBlk(void);
