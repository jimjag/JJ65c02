// PS2 Core Functions
#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#define PS2_DATA_PIN 14
#define PS2_CLK_PIN 15

void initPS2(PIO upio);
int ps2_ready(void);
char ps2_readc(void);
