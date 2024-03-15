/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
/**
 *
 * HARDWARE CONNECTIONS
 *  - GPIO 17 ---> VGA Hsync
 *  - GPIO 18 ---> VGA Vsync
 *  - GPIO 19 ---> 470 ohm resistor ---> VGA Red
 *  - GPIO 20 ---> 470 ohm resistor ---> VGA Green
 *  - GPIO 21 ---> 470 ohm resistor ---> VGA Blue
 *  - GPIO 22 ---> 1k ohm resistor ---> VGA Intensity (bright)
 *  - GPIO 15 ---> PS2 Data pin
 *  - GPIO 16 ---> PS2 Clock pin
 *  - RP2040 GND ---> VGA GND
 *  - GPIO 0-6 ---> 7 bit PS/2 Data to VIA
 *  - GPIO 7-14 ---> 8 Bit Data In from VIA
 *  - GPIO 26 ---> Data Ready
 *  - GPIO 27 ---> IRQ/Handshake to VIA for PS/2
 *  - GPIO 28 ---> audio/sound
 *
 * RESOURCES USED
 *  CORE 0
 *  - VGA:
 *  -   PIO state machines 0, 1, and 2 on PIO instance 0
 *  -   DMA channels 0, 1, 2, and 3
 *  -   IRQ 0, 1
 *  -   153.6 kBytes of RAM (for pixel color data)
 *  - PS2:
 *  -   PIO state machine 0 on PIO instance 1
 *  -   IRQ 1
 *  - MEMIN:
 *  -   PIO state machine 1 on PIO instance 1
 *  -   IRQ 0
 *
 * CORE 1
 * - SND:
 * -   PWM
 */

#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/dma.h"
#include "pico/multicore.h"
#include "vga_core.h"
#include "ps2_keyboard.h"
#include "rp2040_synth_ex.h"

void core1_main() {
    initPS2();
    clearPS2();
    initSOUND();
    startup_chord();
    while (true) {
        soundTask();
        ps2Task(false);
        //tight_loop_contents();
    }
}

int main() {
    set_sys_clock_khz(250000, true);
    // Initialize stdio
    //stdio_init_all();

    // start core 1 threads
    //multicore_reset_core1();
    multicore_launch_core1(&core1_main);
    // Initialize the VGA screen and PS/2 interface
    initVGA();
    //initPS2();
    //clearPS2();
    setFont(0);
    setTextColor2(WHITE, BLUE);
    setTxtCursor(0, 0);
    vgaFillScreen(BLUE);
    setCursor(65, 0);
    setTextSize(2);
    drawString(VERSION_6502);
    setTextSize(1);
    setTxtCursor(0, 3);
    enableCurs(false);
    //clearPS2();
    while (true) {
        conInTask();  // Look for incoming data
        //ps2Task(false);  // And send out any PS/2 data
        //tight_loop_contents();
    }
}
