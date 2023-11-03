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
// Our assembled program:
// pioasm converts foo.pio to fio.pio.h
#include "ps2_keyboard.pio.h"
// Header file
#include "ps2_keyboard.h"

static uint ps2_offset;
static uint ps2_sm;
static PIO ps2_pio;
//static uint ps2_pio_irq;
//static void ps2_ihandler();

void initPS2(void) {
    ps2_pio = pio1;
    //ps2_pio_irq = (ps2_pio == pio1) ? PIO1_IRQ_0 : PIO0_IRQ_0;
    ps2_offset = pio_add_program(ps2_pio, &ps2_program);
    ps2_sm = pio_claim_unused_sm(ps2_pio, true);
    ps2_program_init(ps2_pio, ps2_sm, ps2_offset, PS2_DATA_PIN);
    //pio_set_irq0_source_enabled(ps2_pio, pis_interrupt0, true);
    //irq_set_exclusive_handler(ps2_pio_irq, ps2_ihandler);
    //irq_set_enabled(ps2_pio_irq, true);
    //pio_sm_set_enabled(ps2_pio, ps2_sm, true);
}

// clang-format off

static const char ps2_to_ascii_lower[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '`', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00,  'q',  '1', 0x00, 0x00, 0x00,  'z',  's',  'a',  'w',  '2', 0x00,
0x00,  'c',  'x',  'd',  'e',  '4',  '3', 0x00, 0x00,  ' ',  'v',  'f',  't',  'r',  '5', 0x00,
0x00,  'n',  'b',  'h',  'g',  'y',  '6', 0x00, 0x00, 0x00,  'm',  'j',  'u',  '7',  '8', 0x00,
0x00,  ',',  'k',  'i',  'o',  '0',  '9', 0x00, 0x00,  '.',  '/',  'l',  ';',  'p',  '-', 0x00,
0x00, 0x00, '\'', 0x00,  '[',  '=', 0x00, 0x00, 0x00, 0x00, 0x0D,  ']', 0x00, '\\', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const char ps2_to_ascii_upper[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '~', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00,  'Q',  '!', 0x00, 0x00, 0x00,  'Z',  'S',  'A',  'W',  '@', 0x00,
0x00,  'C',  'X',  'D',  'E',  '$',  '#', 0x00, 0x00,  ' ',  'V',  'F',  'T',  'R',  '%', 0x00,
0x00,  'N',  'B',  'H',  'G',  'Y',  '^', 0x00, 0x00, 0x00,  'M',  'J',  'U',  '&',  '*', 0x00,
0x00,  '<',  'K',  'I',  'O',  ')',  '(', 0x00, 0x00,  '>',  '?',  'L',  ':',  'P',  '_', 0x00,
0x00, 0x00, 0x22, 0x00,  '{',  '+', 0x00, 0x00, 0x00, 0x00, 0x0D,  '}', 0x00,  '|', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const char ps2_to_ascii_cntl[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '~', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x11,  '!', 0x00, 0x00, 0x00, 0x1A, 0x13, 0x01, 0x17,  '@', 0x00,
0x00, 0x03, 0x18, 0x04, 0x05,  '$',  '#', 0x00, 0x00,  ' ', 0x16, 0x06, 0x14, 0x12,  '%', 0x00,
0x00, 0x0E, 0x02, 0x08, 0x07, 0x19,  '^', 0x00, 0x00, 0x00, 0x0D, 0x0A, 0x15,  '&',  '*', 0x00,
0x00,  '<', 0x0B, 0x09, 0x0F,  ')',  '(', 0x00, 0x00,  '>',  '?', 0x0C,  ':', 0x10,  '_', 0x00,
0x00, 0x00, 0x22, 0x00,  '{',  '+', 0x00, 0x00, 0x00, 0x00, 0x0D,  '}', 0x00,  '|', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static bool release; // Flag indicates the release of a key
static bool shift;   // Shift indication
static bool cntl;    // Control indication
static unsigned char ascii;   // Translated to ASCII

// Return keyboard status
// Returns: 0 for not ready, ASCII code otherwise ready
unsigned char ps2GetChar(void) {
    if (ascii)
        return ascii;
    // pio_interrupt_clear(ps2_pio, 0);
    if (pio_sm_is_rx_fifo_empty(ps2_pio, ps2_sm))
        return 0;
    // pull a scan code from the PIO SM fifo
    // uint8_t code = *((io_rw_8*)&ps2_pio->rxf[ps2_sm] + 3);
    uint8_t code = pio_sm_get(ps2_pio, ps2_sm) >> 24;
    switch (code) {
    case 0xF0:               // key-release code 0xF0
        release = 1;         // release flag
        break;
    case 0x12:               // Left-side shift
    case 0x59:               // Right-side shift
        if (release) {
            shift = 0;
            release = 0;
        } else {
            shift = 1;
        }
        break;
    case 0x14:               // Left or Right CNTL key (yep, same scancode)
        if (release) {
            cntl = 0;
            release = 0;
        } else {
            cntl = 1;
        }
        break;
    default:
        code &= 0x7F;
        if (!release) {
            if (cntl) {
                ascii = ps2_to_ascii_cntl[code];
                cntl = 0;
            } else if (shift) {
                ascii = ps2_to_ascii_upper[code];
                shift = 0;
            } else {
                // default
                ascii = ps2_to_ascii_lower[code];
            }
        }
        release = 0;
        break;
    }
    return ascii;
}

// Blocking keyboard read
// Returns  - single ASCII character
unsigned char ps2GetCharBlk(void) {
    unsigned char c;
    while (!(c = ps2GetChar())) {
        tight_loop_contents();
    }
    ascii = 0;
    return c;
}
