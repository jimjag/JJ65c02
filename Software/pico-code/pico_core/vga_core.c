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
 *  -   DMA channels 0, 1, and 2 (vga, memset, memcpy)
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

// All display output is rendered per-scanline (beam-chasing).
// The rendering pipeline composites layers:
//   RENDER_TILEMAP: background pixels → tiles → sprites
//   RENDER_TEXT:    terminal[] + font (per-cell color)
int scanline_size = (SCREENWIDTH / 2); // bytes per scanline (320)

enum render_mode { RENDER_TEXT = 0, RENDER_TILEMAP };
static volatile enum render_mode _render_mode = RENDER_TEXT;
static unsigned char __attribute__((aligned(4))) _line_buf[2][SCREENWIDTH / 2];
static volatile int _line_buf_ready = 0; // which buf is ready for DMA
static volatile int _line_buf_render = 1; // which buf the CPU renders into
static volatile int _render_line = 0; // next line the CPU should render

// Background pixel layer for RENDER_TILEMAP mode.
// Graphics primitives (drawPixel, drawLine, etc.) write here.
// The tile scanline renderer reads one scanline from this as layer 0,
// then composites tiles and sprites on top.
static unsigned char __attribute__((aligned(4))) _bg_pixels[(SCREENWIDTH * SCREENHEIGHT) / 2];

// Tilemap state: grid of tile IDs composited per scanline.
// 640/16 = 40 columns, 480/16 = 30 rows for 16px tiles.
// For 32px tiles: 640/32 = 20 columns, 480/32 = 15 rows.
#define TILEMAP_COLS (SCREENWIDTH / TILE16_WIDTH)
#define TILEMAP_ROWS (SCREENHEIGHT / TILE16_WIDTH)
static unsigned char _tilemap[TILEMAP_ROWS][TILEMAP_COLS];
static int _tilemap_scroll_x = 0;
static int _tilemap_scroll_y = 0;

static const unsigned char *font = font_sweet16;
static char txtfont = 0;

static int memset_dma_chan;
static int memcpy_dma_chan;

// configurations
// wrap: auto wrap around at terminal end
// cr2crlf/lf2crlf: auto CRLF when we get CR or LF
//      we handle "special" characters (like arrows and other non-printables
static bool wrap = true, cr2crlf = false, lf2crlf = false;
volatile char textfgcolor = WHITE_INT, textbgcolor = BLACK_INT;

struct scrpos savedTcurs = {0,0};
volatile struct scrpos tcurs = {0,0};
struct scrpos maxTcurs = {(SCREENWIDTH / FONTWIDTH) - 1, (SCREENHEIGHT / FONTHEIGHT) - 1};

// The terminal mode array
unsigned char *terminal;
unsigned char *term_attr; // per-cell color: high nibble = bg, low nibble = fg
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

static unsigned char _cursor_saved_char = ' ';

bool cursor_callback(struct repeating_timer *t) {
    if (!cursorEnabled) return true;
    int idx = tcurs.x + (tcurs.y * textrow_size);
    if (!cursorOn) {
        _cursor_saved_char = terminal[idx] ? terminal[idx] : ' ';
        terminal[idx] = '_';
    } else {
        terminal[idx] = _cursor_saved_char;
    }
    cursorOn = !cursorOn;
    return true;
}

bool enableCurs(bool flag) {
    bool was = cursorEnabled;
    if (!flag && cursorEnabled && cursorOn) {
        int idx = tcurs.x + (tcurs.y * textrow_size);
        terminal[idx] = _cursor_saved_char;
        cursorOn = false;
    }
    cursorEnabled = flag;
    return was;
}

// Render one scanline of text into buf (320 bytes = 640 pixels at 4bpp).
// Called from main-loop context (not ISR) to prepare the next line.
static void __not_in_flash_func(render_text_scanline)(int line, unsigned char *buf) {
    int char_row = line / FONTHEIGHT;
    int font_row = line % FONTHEIGHT;
    unsigned char *trow = &terminal[char_row * textrow_size];
    unsigned char *arow = &term_attr[char_row * textrow_size];

    for (int col = 0; col < textrow_size; col++) {
        unsigned char glyph = pgm_read_byte(font + (trow[col] * FONTHEIGHT) + font_row);
        unsigned char attr = arow[col];
        unsigned char fg = attr & 0x0F;
        unsigned char bg = (attr >> 4) & 0x0F;

        // Expand 8 monochrome pixels into 4 bytes (2 pixels per byte).
        // PIO emits low nibble first, then high nibble.
        buf[0] = ((glyph & 0x80) ? fg : bg) | (((glyph & 0x40) ? fg : bg) << 4);
        buf[1] = ((glyph & 0x20) ? fg : bg) | (((glyph & 0x10) ? fg : bg) << 4);
        buf[2] = ((glyph & 0x08) ? fg : bg) | (((glyph & 0x04) ? fg : bg) << 4);
        buf[3] = ((glyph & 0x02) ? fg : bg) | (((glyph & 0x01) ? fg : bg) << 4);
        buf += 4;
    }
}

// Sprite and tile arrays — defined here (before the beam renderer) and
// referenced by the graphics functions in vga_graphics.c (same TU).
sprite_t *sprites[MAXSPRITES];
tile_t *tiles[MAXTILES];

// Render one scanline of tilemap + sprites into buf.
// Layer order: background pixels → tiles → sprites.
static void __not_in_flash_func(render_tile_scanline)(int line, unsigned char *buf) {
    int sy = (line + _tilemap_scroll_y) % (TILEMAP_ROWS * TILE16_WIDTH);
    int tile_row = sy / TILE16_WIDTH;
    int tile_y = sy % TILE16_WIDTH;
    int sx_base = _tilemap_scroll_x;

    // Layer 0: copy background pixel scanline
    const unsigned char *bg_src = &_bg_pixels[line * scanline_size];
    for (int i = 0; i < scanline_size; i++)
        buf[i] = bg_src[i];

    // Blit tiles for this scanline
    for (int col = 0; col < TILEMAP_COLS; col++) {
        int sx = (col * TILE16_WIDTH - sx_base);
        // Wrap horizontally
        if (sx < 0) sx += TILEMAP_COLS * TILE16_WIDTH;
        if (sx >= SCREENWIDTH) continue;

        unsigned char tid = _tilemap[tile_row][col];
        if (tid == 0 || tid >= MAXTILES || !tiles[tid]) continue;

        // Tile row is stored as uint64_t (8 bytes = 16 pixels at 4bpp).
        // Tiles at even X positions (aligned to 16px grid) use the [0] variant.
        int oddeven = (sx & 1);
        int byte_offset = sx >> 1;

        // For 16px tiles: one 64-bit chunk
        uint64_t bm = tiles[tid]->bitmap[0][oddeven][tile_y];
        if (byte_offset >= 0 && byte_offset + 8 <= scanline_size) {
            uint64_t *dest = (uint64_t *)&buf[byte_offset];
            *dest = bm;
        }
        // For 32px tiles: second chunk
        if (tiles[tid]->width == TILE32_WIDTH && byte_offset + 16 <= scanline_size) {
            uint64_t bm1 = tiles[tid]->bitmap[1][oddeven][tile_y];
            uint64_t *dest1 = (uint64_t *)&buf[byte_offset + 8];
            *dest1 = bm1;
        }
    }

    // Overlay active sprites using mask compositing
    for (int s = 0; s < MAXSPRITES; s++) {
        if (!sprites[s]) continue;
        int spy = sprites[s]->y;
        int sph = sprites[s]->height;
        if (line < spy || line >= spy + sph) continue;

        int sprite_row = line - spy;
        int spx = sprites[s]->x;
        int oddeven = spx & 1;
        int byte_offset = spx >> 1;
        int chunks = sprites[s]->width / SPRITE16_WIDTH;

        for (int k = 0; k < chunks; k++) {
            int bo = byte_offset + (k * 8);
            if (bo < 0 || bo + 8 > scanline_size) continue;
            uint64_t bm = sprites[s]->bitmap[k][oddeven][sprite_row];
            uint64_t mk = sprites[s]->mask[k][oddeven][sprite_row];
            uint64_t *dest = (uint64_t *)&buf[bo];
            *dest = (*dest & mk) | (~mk & bm);
        }
    }
}

int vga_chan;
// Incremented on every frame boundary (VBlank). Used by waitForVBlank().
volatile uint32_t _vblank_count = 0;
// Per-scanline DMA state: fires once per line (480 times/frame).
static volatile int _scanline_num = 0;
static void __time_critical_func(scanline_ihandler)(void) {
    dma_hw->ints0 = 1u << vga_chan;

    _scanline_num++;
    if (_scanline_num >= SCREENHEIGHT) {
        _scanline_num = 0;
        _vblank_count++;
        // Render line 0 directly — safe during VBlank (~1.4ms available).
        if (_render_mode == RENDER_TEXT)
            render_text_scanline(0, _line_buf[_line_buf_render]);
        else
            render_tile_scanline(0, _line_buf[_line_buf_render]);
        _line_buf_ready ^= 1;
        _line_buf_render ^= 1;
        _render_line = 1;
        dma_channel_set_read_addr(vga_chan, _line_buf[_line_buf_ready], true);
        return;
    }

    if (_render_line < 0) {
        _line_buf_ready ^= 1;
        _line_buf_render ^= 1;
    }
    _render_line = _scanline_num + 1;
    dma_channel_set_read_addr(vga_chan, _line_buf[_line_buf_ready], true);
}

void waitForVBlank(void) {
    uint32_t before = _vblank_count;
    while (_vblank_count == before)
        tight_loop_contents();
}

// Switch to text rendering mode (terminal[] + font).
void setRenderModeText(void) {
    render_text_scanline(0, _line_buf[_line_buf_ready]);
    _render_line = 1;
    _render_mode = RENDER_TEXT;
}

// Switch to tilemap rendering mode (background pixels → tiles → sprites).
void setRenderModeTile(void) {
    for (int r = 0; r < TILEMAP_ROWS; r++)
        for (int c = 0; c < TILEMAP_COLS; c++)
            _tilemap[r][c] = 0;
    _tilemap_scroll_x = 0;
    _tilemap_scroll_y = 0;
    dma_memset(_bg_pixels, 0, sizeof(_bg_pixels), true);
    render_tile_scanline(0, _line_buf[_line_buf_ready]);
    _render_line = 1;
    _render_mode = RENDER_TILEMAP;
}

bool isRenderModeText(void) {
    return _render_mode == RENDER_TEXT;
}

bool isRenderModeTile(void) {
    return _render_mode == RENDER_TILEMAP;
}

void setTilemapCell(int col, int row, unsigned char tile_id) {
    if (col >= 0 && col < TILEMAP_COLS && row >= 0 && row < TILEMAP_ROWS)
        _tilemap[row][col] = tile_id;
}

void setTilemapBg(unsigned char color) {
    dma_memset(_bg_pixels, (color & 0x0F) | (color << 4), sizeof(_bg_pixels), true);
}

void setTilemapScroll(int scroll_x, int scroll_y) {
    _tilemap_scroll_x = scroll_x;
    _tilemap_scroll_y = scroll_y;
}

// Must be called frequently from the main loop to feed the scanline renderer.
void __not_in_flash_func(beamRenderTask)(void) {
    int line = _render_line;
    if (line < 0 || line >= SCREENHEIGHT) return;
    if (_render_mode == RENDER_TEXT)
        render_text_scanline(line, _line_buf[_line_buf_render]);
    else
        render_tile_scanline(line, _line_buf[_line_buf_render]);
    _render_line = -1;
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
    beamRenderTask();
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

    // Channel Zero (sends color data to PIO VGA machine)
    dma_channel_config c0 = dma_channel_get_default_config(vga_chan);    // default configs
    channel_config_set_transfer_data_size(&c0, DMA_SIZE_8); // 8-bit txfers
    channel_config_set_read_increment(&c0, true);           // yes read incrementing
    channel_config_set_write_increment(&c0, false);         // no write incrementing
    channel_config_set_dreq(&c0, DREQ_PIO0_TX2);            // DREQ_PIO0_TX2 pacing (FIFO)
    //channel_config_set_chain_to(&c0, recon_chan);        // chain to other channel

    // Setup terminal and per-cell color attributes (before DMA, since
    // render_text_scanline reads from these).
    terminal = malloc(terminal_size);
    term_attr = malloc(terminal_size);
    dma_memset(terminal, ' ', terminal_size, true);
    dma_memset(term_attr, (BLACK_INT << 4) | WHITE_INT, terminal_size, true);

    // Pre-render line 0 so DMA has valid data on first trigger.
    render_text_scanline(0, _line_buf[_line_buf_ready]);

    dma_channel_configure(vga_chan,
        &c0,
        &pio->txf[scanline_sm],         // write address (SCANLINE PIO TX FIFO)
        _line_buf[_line_buf_ready],      // Initial read address (line buffer)
        scanline_size,                   // One scanline per DMA transfer (320 bytes).
        false
    );

    dma_channel_set_irq0_enabled(vga_chan, true);
    irq_set_exclusive_handler(DMA_IRQ_0, scanline_ihandler);
    irq_set_enabled(DMA_IRQ_0, true);

    pio_sm_put_blocking(pio, hsync_sm, H_ACTIVE);
    pio_sm_put_blocking(pio, vsync_sm, V_ACTIVE);
    pio_sm_put_blocking(pio, scanline_sm, SCANLINE_ACTIVE);

    pio_enable_sm_mask_in_sync(pio, ((1u << hsync_sm) | (1u << vsync_sm) | (1u << scanline_sm)));
    dma_start_channel_mask((1u << vga_chan));

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
