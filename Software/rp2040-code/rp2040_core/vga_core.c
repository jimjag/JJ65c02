/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
/**
 *
 * RP2040 HARDWARE CONNECTIONS
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
 *  - GPIO 24 ---> 6502 PHI/CLK
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
 *  - CLK:
 *  -   PIO state machine 2 on PIO instance 1
 *
 * CORE 1
 * - SND:
 * -   PWM
 */

#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "hardware/gpio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
// Our assembled programs:
// pioasm converts foo.pio to foo.pio.h
#include "hsync.pio.h"
#include "scanline.pio.h"
#include "vsync.pio.h"
#include "memin.pio.h"
#include "clk.pio.h"
// Header file
#include "vga_core.h"
// Font file
#include "vga_fonts.c"

// Pixel color array that is DMAed to the PIO machines and
// a pointer to the ADDRESS of this color array.
// Note that this array is automatically initialized to all 0's (black)
// Length of the pixel array, and number of DMA transfers
// #define txcount 153600 // Total pixels/2 (since we have 2 pixels per byte)
int txcount = (SCREENWIDTH * SCREENHEIGHT) / 2; // Total pixels/2 (since we have 2 pixels per byte)
unsigned char vga_data_array[(SCREENWIDTH * SCREENHEIGHT) / 2];
unsigned char *address_pointer = &vga_data_array[0];
int scanline_size = (SCREENWIDTH / 2); // Amount of bytes taken by each scanline

static const unsigned char *font = font_sweet16;
static char txtfont = 0;

// DMA channel for dma_memcpy and dma_memset
int memcpy_dma_chan;

// configurations
// wrap: auto wrap around at terminal end
// cr2crlf/lf2crlf: auto CRLF when we get CR or LF
//      we handle "special" characters (like arrows and other non-printables
static bool wrap = true, cr2crlf = false, lf2crlf = false, smooth_scroll = false;
char textfgcolor = WHITE_INT, textbgcolor = BLACK_INT;

struct scrpos savedTcurs = {0,0};
struct scrpos tcurs = {0,0};
struct scrpos maxTcurs = {(SCREENWIDTH / FONTWIDTH) - 1, (SCREENHEIGHT / FONTHEIGHT) - 1};

// The terminal mode array
unsigned char *terminal;
int terminal_size = (SCREENWIDTH / FONTWIDTH) * (SCREENHEIGHT / FONTHEIGHT);
int textrow_size = (SCREENWIDTH / FONTWIDTH);

// For drawing characters in Graphics Mode
int cursor_y, cursor_x, textsize;

// Data rec'd from the 6502 VIA chip
//volatile static unsigned char inputChar;
//volatile static bool hasChar = false;



// Stuff for blinking cursor functions
static struct repeating_timer ctimer;
alarm_pool_t *apool = NULL;
volatile bool cursorEnabled = false;
volatile bool cursorOn = false;

bool cursor_callback(struct repeating_timer *t) {
    if (!cursorEnabled) return true;
    if (!cursorOn) {
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, '_', textfgcolor, textbgcolor, textsize, false);
    } else {
        unsigned char oldChar = (terminal[tcurs.x + (tcurs.y * textrow_size)]) ? terminal[tcurs.x + (tcurs.y * textrow_size)] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar, textfgcolor, textbgcolor, textsize, false);
    }
    cursorOn = !cursorOn;
    return true;
}

bool enableCurs(bool flag) {
    bool was = cursorEnabled;
    if (!flag && cursorEnabled && cursorOn) { // turning it off when on
        unsigned char oldChar = (terminal[tcurs.x + (tcurs.y * textrow_size)]) ? terminal[tcurs.x + (tcurs.y * textrow_size)] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar, textfgcolor, textbgcolor, textsize, false);
    }
    cursorEnabled = flag;
    return was;
}

// Interrupt Handler: We have data on GPIO7-14 and DREADY on GPIO26
static uint memin_offset;
static uint memin_sm;
static PIO memin_pio;
static uint memin_pio_irq;
static unsigned char inbuf[10240];
static unsigned char *endbuf = inbuf + sizeof(inbuf);
volatile static unsigned char *rptr = inbuf;
volatile static unsigned char *wptr = inbuf;

// Clock
static uint clk_offset;
static uint clk_sm;
static PIO clk_pio;

// ISR
static void __time_critical_func(readMem)(void) {
    //uint8_t code = pio_sm_get(memin_pio, memin_sm) >> 24;
    *wptr++ = memin_pio->rxf[memin_sm] >> 24;
    memin_pio->irq = (1u << 0);
    if (wptr >= endbuf)
        wptr = inbuf;
    //pio_interrupt_clear(memin_pio, 0);
}

// Once we grab the character/byte we've rec'd, we no longer
// have it available to "read" again.
bool getByte(unsigned char *ascii) {
    if (rptr != wptr) {
        *ascii = *rptr++;
        if (rptr >= endbuf)
            rptr = inbuf;
        return true;
    }
    return false;
}

// This is the actual task used in polling/looping:
//   Check if we rec'd a character from the 6502
//   if so, we print it (send it to the VGA system)
void conInTask(void) {
    unsigned char ascii;
    if (getByte(&ascii)) {
        handleByte(ascii);
    }
}

void initVGA(void) {
    // Choose which PIO instance to use (there are two instances, each with 4 state
    // machines)
    PIO pio = pio0;

    // Our assembled program needs to be loaded into this PIO's instruction
    // memory. This SDK function will find a location (offset) in the
    // instruction memory where there is enough space for our program. We need
    // to remember these locations!
    //
    // We only have 32 instructions to spend! If the PIO programs contain more than
    // 32 instructions, then an error message will get thrown at these lines of code.
    //
    // The program name comes from the .program part of the pio file
    // and is of the form <program name_program>
    uint hsync_offset = pio_add_program(pio, &hsync_program);
    uint vsync_offset = pio_add_program(pio, &vsync_program);
    uint scanline_offset = pio_add_program(pio, &scanline_program);

    // Manually select a few state machines from pio instance pio.
    uint hsync_sm = pio_claim_unused_sm(pio, true);
    uint vsync_sm = pio_claim_unused_sm(pio, true);
    uint scanline_sm = pio_claim_unused_sm(pio, true);

    // Call the initialization functions that are defined within each PIO file.
    // Why not create these programs here? By putting the initialization function in
    // the pio file, then all information about how to use/setup that state machine
    // is consolidated in one place. Here in the C, we then just import and use it.
    hsync_program_init(pio, hsync_sm, hsync_offset, HSYNC, PIXFREQ);
    vsync_program_init(pio, vsync_sm, vsync_offset, VSYNC, PIXFREQ);
    scanline_program_init(pio, scanline_sm, scanline_offset, RED_PIN, SCANFREQ);

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // ============================== PIO DMA Channels
    // =================================================
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // DMA channels - 0 sends color data, 1 reconfigures and restarts 0
    int scanline_chan_0 = dma_claim_unused_channel(true);
    int scanline_chan_1 = dma_claim_unused_channel(true);

    // DMA channel for dma_memcpy and dma_memset
    memcpy_dma_chan = dma_claim_unused_channel(true);

    // Channel Zero (sends color data to PIO VGA machine)
    dma_channel_config c0 = dma_channel_get_default_config(scanline_chan_0);    // default configs
    channel_config_set_transfer_data_size(&c0, DMA_SIZE_8); // 8-bit txfers
    channel_config_set_read_increment(&c0, true);           // yes read incrementing
    channel_config_set_write_increment(&c0, false);         // no write incrementing
    channel_config_set_dreq(&c0, DREQ_PIO0_TX2);            // DREQ_PIO0_TX2 pacing (FIFO)
    channel_config_set_chain_to(&c0, scanline_chan_1);      // chain to other channel

    dma_channel_configure(scanline_chan_0,        // Channel to be configured
        &c0,                    // The configuration we just created
        &pio->txf[scanline_sm], // write address (SCANLINE PIO TX FIFO)
        &vga_data_array, // The initial read address (pixel color array)
        txcount, // Number of transfers; in this case each is 1 byte.
        false    // Don't start immediately.
    );

    // Channel One (reconfigures the first channel)
    dma_channel_config c1 = dma_channel_get_default_config(scanline_chan_1);     // default configs
    channel_config_set_transfer_data_size(&c1, DMA_SIZE_32); // 32-bit txfers
    channel_config_set_read_increment(&c1, false);           // no read incrementing
    channel_config_set_write_increment(&c1, false);          // no write incrementing
    channel_config_set_chain_to(&c1, scanline_chan_0);       // chain to other channel

    dma_channel_configure(scanline_chan_1,                        // Channel to be configured
        &c1,                                    // The configuration we just created
        &dma_hw->ch[scanline_chan_0].read_addr, // Write address (channel 0 read address)
        &address_pointer,                       // Read address (POINTER TO AN ADDRESS)
        1,    // Number of transfers, in this case each is 4 byte
        false // Don't start immediately.
    );

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // Initialize PIO state machine counters. This passes the information to the state
    // machines that they retrieve in the first 'pull' instructions, before the
    // .wrap_target directive in the assembly. Each uses these values to initialize some
    // counting registers.
    pio_sm_put_blocking(pio, hsync_sm, H_ACTIVE);
    pio_sm_put_blocking(pio, vsync_sm, V_ACTIVE);
    pio_sm_put_blocking(pio, scanline_sm, SCANLINE_ACTIVE);

    // Start the two pio machine IN SYNC
    // Note that the SCANLINE state machine is running at full speed,
    // so synchronization doesn't matter for that one. But, we'll
    // start them all simultaneously anyway.
    pio_enable_sm_mask_in_sync(pio, ((1u << hsync_sm) | (1u << vsync_sm) | (1u << scanline_sm)));

    // Start DMA channel 0. Once started, the contents of the pixel color array
    // will be constantly DMAed to the PIO machines that are driving the screen.
    // To change the contents of the screen, we need only change the contents
    // of that array.
    dma_start_channel_mask((1u << scanline_chan_0));

    // Now setup terminal
    terminal = malloc(terminal_size);
    dma_memset(terminal, ' ', terminal_size);

    // GPIO pin setup for data sent from 6502 to us (Console Output)
    rptr = wptr = inbuf;
    memin_pio = pio1;
    memin_pio_irq = PIO1_IRQ_0;
    memin_offset = pio_add_program(memin_pio, &memin_program);
    memin_sm = pio_claim_unused_sm(memin_pio, true);
    memin_program_init(memin_pio, memin_sm, memin_offset, DATA0);
    pio_gpio_init(memin_pio,DREADY);
    gpio_set_dir(DREADY, GPIO_IN);
    pio_set_irq0_source_enabled(memin_pio, pis_interrupt0, true);
    irq_set_exclusive_handler(memin_pio_irq, readMem);
    irq_set_enabled(memin_pio_irq, true);
    pio_sm_set_enabled(memin_pio, memin_sm, true);
    // The 6502 Clock signal
    clk_pio = pio1;
    clk_offset = pio_add_program(clk_pio, &clk_program);
    clk_sm = pio_claim_unused_sm(clk_pio, true);
    clk_program_init(clk_pio, clk_sm, clk_offset, CLK_PIN);
    //pio_sm_set_enabled(clk_pio, clk_sm, true);
    //
    apool = alarm_pool_create_with_unused_hardware_alarm(10);
    alarm_pool_add_repeating_timer_ms(apool, 500, cursor_callback, NULL, &ctimer);
}

void __not_in_flash_func(dma_memset)(void *dest, uint8_t val, size_t num) {
    dma_channel_config c = dma_channel_get_default_config(memcpy_dma_chan);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, true);

    dma_channel_configure(
            memcpy_dma_chan, // Channel to be configured
            &c,              // The configuration we just created
            dest,            // The initial write address
            &val,            // The initial read address
            num, // Number of transfers; in this case each is 1 byte.
            true // Start immediately.
    );

    // We could choose to go and do something else whilst the DMA is doing its
    // thing. In this case the processor has nothing else to do, so we just
    // wait for the DMA to finish.
    dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
}

void __not_in_flash_func(dma_memcpy)(void *dest, void *src, size_t num) {
    dma_channel_config c = dma_channel_get_default_config(memcpy_dma_chan);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
    channel_config_set_read_increment(&c, true);
    channel_config_set_write_increment(&c, true);

    dma_channel_configure(
            memcpy_dma_chan, // Channel to be configured
            &c,              // The configuration we just created
            dest,            // The initial write address
            src,             // The initial read address
            num, // Number of transfers; in this case each is 1 byte.
            true // Start immediately.
    );

    // We could choose to go and do something else whilst the DMA is doing its
    // thing. In this case the processor has nothing else to do, so we just
    // wait for the DMA to finish.
    dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
}

#include "vga_graphics.c"
