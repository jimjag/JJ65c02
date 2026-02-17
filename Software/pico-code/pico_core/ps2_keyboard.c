/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
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
#include "vga_core.h"

static uint ps2_offset;
static uint ps2_sm;
static PIO ps2_pio;
static uint ps2_pio_irq;
static void ps2_ihandler();

static bool release; // Flag indicates the release of a key
static bool shift;   // Shift indication
static bool cntl;    // Control indication
static bool caps;    // Caps Lock

static unsigned char keybuf[128];
volatile static unsigned char *rptr = keybuf;
volatile static unsigned char *wptr = keybuf;

void initPS2(void) {
    ps2_pio = pio1;
    ps2_pio_irq = PIO1_IRQ_1;
    ps2_offset = pio_add_program(ps2_pio, &ps2_program);
    ps2_sm = pio_claim_unused_sm(ps2_pio, true);
    ps2_program_init(ps2_pio, ps2_sm, ps2_offset, PS2_DATA_PIN, PS2FREQ);
    pio_set_irq1_source_enabled(ps2_pio, pis_interrupt1, true);
    irq_set_exclusive_handler(ps2_pio_irq, ps2_ihandler);
    irq_set_enabled(ps2_pio_irq, true);
    pio_sm_set_enabled(ps2_pio, ps2_sm, true);
    // get rid of noise on pins when the PS/2 keyboard is enabled
    sleep_ms(1);
    pio_sm_clear_fifos(ps2_pio, ps2_sm);

    // Now the GPIO pins for the Keyboard data to the VIA chip
    // GPIO pin setup
    for (uint pin = PA0; pin <= PA6; pin++) {
        gpio_init(pin);
        gpio_set_dir(pin, GPIO_OUT);
    }
    gpio_init(PIRQ);
    gpio_set_dir(PIRQ, GPIO_OUT);
    gpio_pull_down(PIRQ);
    gpio_put(PIRQ, 0);
    rptr = wptr = keybuf;
}

// Run this even after we INIT and before we start ps2Task()
void clearPS2(void) {
    pio_sm_clear_fifos(ps2_pio, ps2_sm);
    release = shift = cntl = caps = 0;
    rptr = wptr = keybuf;
}
// clang-format off

// SPECIAL CASE:
//   Left Arrow:  scancode 107 -> Ascii 0x14   Esc[D
//   Right Arrow: scancode 116 -> Ascii 0x13   Esc[C
//   Down Arrow:  scancode 114 -> Ascii 0x12   Esc[B
//   Up Arrow:    scancode 117 -> Ascii 0x11   Esc[A
//
static const char __in_flash() ps2_to_ascii_lower[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '`', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00,  'q',  '1', 0x00, 0x00, 0x00,  'z',  's',  'a',  'w',  '2', 0x00,
0x00,  'c',  'x',  'd',  'e',  '4',  '3', 0x00, 0x00,  ' ',  'v',  'f',  't',  'r',  '5', 0x00,
0x00,  'n',  'b',  'h',  'g',  'y',  '6', 0x00, 0x00, 0x00,  'm',  'j',  'u',  '7',  '8', 0x00,
0x00,  ',',  'k',  'i',  'o',  '0',  '9', 0x00, 0x00,  '.',  '/',  'l',  ';',  'p',  '-', 0x00,
0x00, 0x00, '\'', 0x00,  '[',  '=', 0x00, 0x00, 0x00, 0x00, 0x0D,  ']', 0x00, '\\', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x12, 0x00, 0x13, 0x11, 0x1B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const char __in_flash() ps2_to_ascii_upper[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '~', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00,  'Q',  '!', 0x00, 0x00, 0x00,  'Z',  'S',  'A',  'W',  '@', 0x00,
0x00,  'C',  'X',  'D',  'E',  '$',  '#', 0x00, 0x00,  ' ',  'V',  'F',  'T',  'R',  '%', 0x00,
0x00,  'N',  'B',  'H',  'G',  'Y',  '^', 0x00, 0x00, 0x00,  'M',  'J',  'U',  '&',  '*', 0x00,
0x00,  '<',  'K',  'I',  'O',  ')',  '(', 0x00, 0x00,  '>',  '?',  'L',  ':',  'P',  '_', 0x00,
0x00, 0x00, 0x22, 0x00,  '{',  '+', 0x00, 0x00, 0x00, 0x00, 0x0D,  '}', 0x00,  '|', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x12, 0x00, 0x13, 0x11, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const char __in_flash() ps2_to_ascii_cntl[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09,  '~', 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x11,  '!', 0x00, 0x00, 0x00, 0x1A, 0x13, 0x01, 0x17,  '@', 0x00,
0x00, 0x03, 0x18, 0x04, 0x05,  '$',  '#', 0x00, 0x00,  ' ', 0x16, 0x06, 0x14, 0x12,  '%', 0x00,
0x00, 0x0E, 0x02, 0x08, 0x07, 0x19,  '^', 0x00, 0x00, 0x00, 0x0D, 0x0A, 0x15,  '&',  '*', 0x00,
0x00,  '<', 0x0B, 0x09, 0x0F,  ')',  '(', 0x00, 0x00,  '>',  '?', 0x0C,  ':', 0x10,  '_', 0x00,
0x00, 0x00, 0x22, 0x00,  '{',  '+', 0x00, 0x00, 0x00, 0x00, 0x0D,  '}', 0x00,  '|', 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x12, 0x00, 0x13, 0x11, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// ISR
void ps2_ihandler(void) {
    unsigned char ascii = 0;
    // pio_interrupt_clear(ps2_pio, 0);
    if (pio_sm_is_rx_fifo_empty(ps2_pio, ps2_sm)) {
        pio_interrupt_clear(ps2_pio, 1);
        return;
    }
    // pull a scan code from the PIO SM fifo
    // uint8_t code = *((io_rw_8*)&ps2_pio->rxf[ps2_sm] + 3);
    uint8_t code = pio_sm_get(ps2_pio, ps2_sm) >> 24;
    switch (code) {
        case 0xF0:               // key-release code 0xF0
            release = 1;         // release flag
            break;
        case 0x58:               // Caps Lock?
            if (release) {
                release = 0;
            } else {
                caps = !caps;
            }
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
                    // cntl = 0;
                } else if (shift) {
                    ascii = ps2_to_ascii_upper[code];
                    // shift = 0;
                } else {
                    // default
                    ascii = ps2_to_ascii_lower[code];
                    if (caps && (ascii >= 'a' && ascii <= 'z')) {
                        ascii -= 32;
                    }
                }
            }
            release = 0;
            break;
    }
    *wptr++ = ascii;
    if (wptr >= (keybuf + sizeof(keybuf)))
        wptr = keybuf;
    pio_interrupt_clear(ps2_pio, 1);
}

// Return keyboard status
// Returns: 0 for not ready, ASCII code otherwise ready
// The default is to auto-print to the VGA console, but we
// can disable this if, for some reason, we want/need the
// *host* (ie, the 6502) to echo rec'd characters itself.
unsigned char ps2GetChar(bool auto_print) {
    unsigned char ascii = 0;
    if (rptr != wptr) {
        ascii = *rptr++;
        if (rptr >= (keybuf + sizeof(keybuf)))
            rptr = keybuf;
    }
    if (ascii && auto_print) handleByte(ascii);
    return ascii;
}

// Blocking keyboard read
// Returns  - single ASCII character
unsigned char ps2GetCharBlk(bool auto_print) {
    unsigned char c;
    while (!(c = ps2GetChar(auto_print))) {
        tight_loop_contents();
    }
    return c;
}

// This is the actual task used in polling/looping:
//   Check if we rec'd a character from the PS/2 Keyboard
//   if so, we print it (send it to the VGA system) and
//   then send it to the 6502 via the VIA.
void ps2Task(bool auto_print) {
    unsigned char c;
    if ((c = ps2GetChar(auto_print))) {
        for (uint pin = PA0; pin <= PA6; pin++) {
            gpio_put(pin, c & 0x01);
            c = c>>1;
        }
        gpio_put(PIRQ, 1);  // Trigger VIA to read PortA
        sleep_us(1);               // Give the 6502 time to read
        gpio_put(PIRQ, 0);  // Reset
    }
}

// We need some way to send a byte to the 6502 via the VIA
// We do this being sending a special byte that the PS2 could
// never send (0x02: STX) and then the actual 7-bit byte. The VIA
// sees this sequence and acts accordingly.
void send2RAM(unsigned char c) {
    unsigned char d = 0x02;
    for (uint pin = PA0; pin <= PA6; pin++) {
        gpio_put(pin, d & 0x01);
        d = d>>1;
    }
    gpio_put(PIRQ, 1);  // Trigger VIA to read PortA
    sleep_us(1);               // Give the 6502 time to read
    gpio_put(PIRQ, 0);  // Reset
    for (uint pin = PA0; pin <= PA6; pin++) {
        gpio_put(pin, c & 0x01);
        c = c>>1;
    }
    gpio_put(PIRQ, 1);  // Trigger VIA to read PortA
    sleep_us(1);               // Give the 6502 time to read
    gpio_put(PIRQ, 0);  // Reset
}
