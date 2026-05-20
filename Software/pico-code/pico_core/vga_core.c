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
 *  - GPIO 7-14 ---> 8 Bit Data In from 6502
 *  - GPIO 26 ---> Data Ready
 *  - GPIO 27 ---> IRQ/Handshake to VIA for PS/2
 *  - GPIO 28 ---> audio/sound
 *
 * RESOURCES USED
 *  CORE 0
 *  - VGA:
 *  -   PIO state machines 0, 1, and 2 on PIO instance 0
 *  -   DMA channels 0, 1, 2, and 3 (vga, memset, memcpy, isr-copy)
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
// #include "clk.pio.h"
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

// The RP2040 lacks enough memory for double buffering.
// On RP2350 the two buffers are placed in separate named sections so the
// custom linker script (memmap_vga_rp2350.ld) can pin them to different
// SRAM bank groups.  Buffer 0 (show) lands in SRAM4/5; buffer 1 (draw)
// lands in SRAM6/7.  The show buffer is always the one scanned out by the
// PIO DMA.  When double-buffering is enabled the VBlank handler copies the
// draw buffer into the show buffer (~256µs via word-DMA, well within the
// ~1,440µs blanking interval).  Separate banks ensure this copy and the
// pixel DMA never contend on the same bus.  On RP2040 a single buffer is
// used (no DB).
#if PICO_RP2040
unsigned char __attribute__((aligned(4))) vga_data_array[1][(SCREENWIDTH * SCREENHEIGHT) / 2];
#else
unsigned char __attribute__((aligned(4), section(".vga_show_buf"))) vga_buf0[(SCREENWIDTH * SCREENHEIGHT) / 2];
unsigned char __attribute__((aligned(4), section(".vga_draw_buf"))) vga_buf1[(SCREENWIDTH * SCREENHEIGHT) / 2];
// Pointer array indexed by db_show / db_draw — same call-site syntax as before.
// Initialised from address constants so the compiler places it in .rodata (flash).
// Two pointer reads at 60 Hz from flash is negligible; the buffers themselves are in RAM.
unsigned char * const vga_data_array[2] = { vga_buf0, vga_buf1 };
#endif
//unsigned char *address_pointer = &vga_data_array[0][0];
int scanline_size = (SCREENWIDTH / 2); // Amount of bytes taken by each scanline

static const unsigned char *font = font_sweet16;
static char txtfont = 0;

static int memset_dma_chan;
static int memcpy_dma_chan;
static int isr_dma_chan;

// configurations
// wrap: auto wrap around at terminal end
// cr2crlf/lf2crlf: auto CRLF when we get CR or LF
//      we handle "special" characters (like arrows and other non-printables
static bool wrap = true, cr2crlf = false, lf2crlf = false, smooth_scroll = false;
volatile char textfgcolor = WHITE_INT, textbgcolor = BLACK_INT;

struct scrpos savedTcurs = {0,0};
volatile struct scrpos tcurs = {0,0};
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
    int idx = tcurs.x + (tcurs.y * textrow_size);
    if (!cursorOn) {
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, '_', textfgcolor, textbgcolor, textsize, false);
    } else {
        unsigned char oldChar = terminal[idx] ? terminal[idx] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar, textfgcolor, textbgcolor, textsize, false);
    }
    cursorOn = !cursorOn;
    return true;
}

bool enableCurs(bool flag) {
    bool was = cursorEnabled;
    if (!flag && cursorEnabled && cursorOn) { // turning it off when on
        int idx = tcurs.x + (tcurs.y * textrow_size);
        unsigned char oldChar = terminal[idx] ? terminal[idx] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar, textfgcolor, textbgcolor, textsize, false);
    }
    cursorEnabled = flag;
    return was;
}

// Double buffers stuff
int vga_chan;
volatile int db_show = 0;
volatile int db_draw = 0;
volatile bool _do_switch = false;
volatile bool _db_switched = false;
volatile bool _db_vga_enabled = false;
// Incremented on every frame boundary (VBlank). Used by waitForVBlank().
volatile uint32_t _vblank_count = 0;
static void __time_critical_func(db_vga_ihandler)(void) {
    // Clear the interrupt request first so the DMA controller does not
    // immediately re-assert when we re-trigger below.
    dma_hw->ints0 = 1u << vga_chan;
#if !PICO_RP2040
    _db_switched = false;
    if (_db_vga_enabled && _do_switch) {
        dma_channel_set_read_addr(isr_dma_chan, vga_data_array[db_draw], false);
        dma_channel_set_write_addr(isr_dma_chan, vga_data_array[db_show], false);
        dma_channel_set_trans_count(isr_dma_chan, txcount >> 2, true);
        dma_channel_wait_for_finish_blocking(isr_dma_chan);
        _do_switch = false;
        _db_switched = true;
    }
#endif
    // Re-trigger VGA DMA — show buffer always remains at index 0.
    dma_channel_set_read_addr(vga_chan, vga_data_array[db_show], true);
    _vblank_count++;
}

// Enable or Disable the Double Buffering
void enableDB(void) {
#if !PICO_RP2040
    _do_switch = false;
    _db_vga_enabled = true;
    db_show = 0;
    db_draw = 1;
    // Both buffers start with identical content — copy show→draw so the
    // draw buffer begins as an exact clone of what's currently on screen.
    dma_memcpy(vga_data_array[db_draw], vga_data_array[db_show], txcount, true);
    _db_switched = true;
#endif
}
void disableDB(void) {
    _db_vga_enabled = false;
    // When disabling, ensure show buffer has the latest draw content,
    // then point both indices at the show buffer.
    dma_memcpy(vga_data_array[0], vga_data_array[db_draw], txcount, true);
    db_show = 0;
    db_draw = 0;
}
// Get the current state of the Double Buffering
bool getDBEnabled(void) {
    return _db_vga_enabled;
}
// Copy the currently showing buffer to the drawing buffer.
// Under the new model the switchDB handler copies draw→show, so after a
// switch both buffers are already identical.  This function exists so
// callers that only modify a small portion of the frame can explicitly
// re-seed the draw buffer from the show buffer at any time.
void show2drawDB(void) {
    if (db_show != db_draw) {
        dma_memcpy(vga_data_array[db_draw], vga_data_array[db_show], txcount, true);
    }
}
// Request a draw→show copy at the next VBlank.
void switchDB(void) {
    _do_switch = true;
}
// Did the handler switch the buffers?
bool getDBSwitched(void) {
    return _db_switched;
}
// Block until the DMA frame-end IRQ fires. See vga_core.h for usage context.
void waitForVBlank(void) {
    uint32_t before = _vblank_count;
    while (_vblank_count == before)
        tight_loop_contents();
}

// Interrupt Handler: We have data on GPIO7-14 and DREADY on GPIO26
static uint memin_offset;
static uint memin_sm;
static PIO memin_pio;
static uint memin_pio_irq;
static unsigned char inbuf[5120];  // Increase these if you start dropping bytes
static unsigned char *endbuf = inbuf + sizeof(inbuf);
volatile static unsigned char *rptr = inbuf;
volatile static unsigned char *wptr = inbuf;

// Clock
// static uint clk_offset;
// static uint clk_sm;
// static PIO clk_pio;

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
    pio_sm_exec(pio, vsync_sm, pio_encode_set(pio_pins, 1));  // prime vsync pin HIGH; PIO output register resets to 0, causing false sync on frame 1
    scanline_program_init(pio, scanline_sm, scanline_offset, RED_PIN, SCANFREQ);

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // ============================== PIO DMA Channels
    // =================================================
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // DMA channel - sends color data to VGA system
    vga_chan = dma_claim_unused_channel(true);

    memset_dma_chan = dma_claim_unused_channel(true);
    memcpy_dma_chan = dma_claim_unused_channel(true);
    isr_dma_chan = dma_claim_unused_channel(true);

#if !PICO_RP2040
    // Fully pre-configure isr_dma_chan for draw→show copies in the VBlank ISR.
    // Addresses and config are static; the ISR only sets trans_count to trigger.
    dma_channel_config ci = dma_channel_get_default_config(isr_dma_chan);
    channel_config_set_transfer_data_size(&ci, DMA_SIZE_32);
    channel_config_set_read_increment(&ci, true);
    channel_config_set_write_increment(&ci, true);
    dma_channel_configure(isr_dma_chan, &ci,
        vga_data_array[0], vga_data_array[1],
        0, false);
#endif

    // Channel Zero (sends color data to PIO VGA machine)
    dma_channel_config c0 = dma_channel_get_default_config(vga_chan);    // default configs
    channel_config_set_transfer_data_size(&c0, DMA_SIZE_8); // 8-bit txfers
    channel_config_set_read_increment(&c0, true);           // yes read incrementing
    channel_config_set_write_increment(&c0, false);         // no write incrementing
    channel_config_set_dreq(&c0, DREQ_PIO0_TX2);            // DREQ_PIO0_TX2 pacing (FIFO)
    //channel_config_set_chain_to(&c0, recon_chan);        // chain to other channel

    dma_channel_configure(vga_chan,     // Channel to be configured
        &c0,                            // The configuration we just created
        &pio->txf[scanline_sm],         // write address (SCANLINE PIO TX FIFO)
        vga_data_array[0],              // The initial read address (pixel color array)
        txcount,                        // Number of transfers; in this case each is 1 byte.
        false                           // Don't start immediately.
    );

    // Tell the DMA to raise IRQ line 0 when the channel finishes a block
    dma_channel_set_irq0_enabled(vga_chan, true);
    // Configure the processor to run dma_handler() when DMA IRQ 0 is asserted
    irq_set_exclusive_handler(DMA_IRQ_0, db_vga_ihandler);
    irq_set_enabled(DMA_IRQ_0, true);

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
    dma_start_channel_mask((1u << vga_chan));

    // Now setup terminal
    terminal = malloc(terminal_size);
    dma_memset(terminal, ' ', terminal_size, true);

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
    // clk_pio = pio1;
    // clk_offset = pio_add_program(clk_pio, &clk_program);
    // clk_sm = pio_claim_unused_sm(clk_pio, true);
    // clk_program_init(clk_pio, clk_sm, clk_offset, CLK_PIN);
    //pio_sm_set_enabled(clk_pio, clk_sm, true);
    //
    apool = alarm_pool_create_with_unused_hardware_alarm(10);
    alarm_pool_add_repeating_timer_ms(apool, 500, cursor_callback, NULL, &ctimer);
}

// Strategy:
//   1. CPU-fill any unaligned head bytes (synchronous, before kicking off DMA).
//   2. block=true OR tail==0: word-DMA the aligned bulk (fast path).
//      block=true also runs CPU tail writes after the DMA completes.
//   3. block=false with tail bytes: fall back to a single byte-DMA covering
//      the whole post-head range so the call returns truly asynchronously.
// Static fill words/bytes outlive the stack frame so the DMA source remains
// valid after this function returns in the non-blocking case.
void __not_in_flash_func(dma_memset)(void *dest, uint8_t val, size_t num, bool block) {
    if (num == 0) return;

    uint8_t *d = (uint8_t *)dest;

    // Head: CPU-fill 0-3 bytes until d is 4-byte aligned.
    while (num > 0 && ((uintptr_t)d & 3) != 0) {
        *d++ = val;
        num--;
    }
    if (num == 0) return;

    size_t words = num >> 2;
    size_t tail = num & 3;

    static uint32_t word32;
    word32 = (uint32_t)val * 0x01010101u;

    dma_channel_config c = dma_channel_get_default_config(memset_dma_chan);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, true);

    if (block) {
        // Synchronous: word-DMA the bulk (if any), then CPU-fill the tail.
        if (words > 0) {
            channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
            dma_channel_configure(memset_dma_chan, &c, d, &word32, words, true);
            dma_channel_wait_for_finish_blocking(memset_dma_chan);
            d += words << 2;
        }
        while (tail > 0) {
            *d++ = val;
            tail--;
        }
    } else if (tail == 0) {
        // Async fast path: pure word DMA (num >= 4 guaranteed here).
        channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
        dma_channel_configure(memset_dma_chan, &c, d, &word32, words, true);
    } else {
        // Async with tail bytes: single byte DMA covers the whole range so
        // the call returns truly asynchronously.
        static uint8_t byte_val;
        byte_val = val;
        channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
        dma_channel_configure(memset_dma_chan, &c, d, &byte_val, num, true);
    }
}

void __not_in_flash_func(dma_memcpy)(void *dest, const void *src, size_t num, bool block) {
    if (num == 0) return;

    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;

    dma_channel_config c = dma_channel_get_default_config(memcpy_dma_chan);
    channel_config_set_read_increment(&c, true);
    channel_config_set_write_increment(&c, true);

    // Mismatched alignment: word-mode would corrupt — single byte DMA.
    // Works for both blocking and non-blocking (src is caller-owned).
    if ((((uintptr_t)d ^ (uintptr_t)s) & 3) != 0) {
        channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
        dma_channel_configure(memcpy_dma_chan, &c, d, s, num, true);
        if (block) dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
        return;
    }

    // Head: CPU-copy 0-3 bytes until both pointers are 4-byte aligned.
    while (num > 0 && ((uintptr_t)d & 3) != 0) {
        *d++ = *s++;
        num--;
    }
    if (num == 0) return;

    size_t words = num >> 2;
    size_t tail = num & 3;

    if (block) {
        // Synchronous: word-DMA the bulk (if any), then CPU-copy the tail.
        if (words > 0) {
            channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
            dma_channel_configure(memcpy_dma_chan, &c, d, s, words, true);
            dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
            size_t bulk = words << 2;
            d += bulk;
            s += bulk;
        }
        while (tail > 0) {
            *d++ = *s++;
            tail--;
        }
    } else if (tail == 0) {
        // Async fast path: pure word DMA (num >= 4 guaranteed here).
        channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
        dma_channel_configure(memcpy_dma_chan, &c, d, s, words, true);
    } else {
        // Async with tail bytes: single byte DMA covers the whole range.
        channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
        dma_channel_configure(memcpy_dma_chan, &c, d, s, num, true);
    }
}

// vga_graphics.c is included here (not compiled separately) so the two
// share a translation unit. Do NOT add vga_graphics.c to target_sources
// in CMakeLists.txt or you'll get duplicate-symbol errors at link.
#include "vga_graphics.c"
