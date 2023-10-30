// PS2 Core Functions
#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#define PS2_DATA_PIN 14
#define PS2_CLK_PIN 15

void initPS2(void);
int ps2Ready(void);
char ps2GetChar(void);
