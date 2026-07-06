// Host platform layer for the JJ65c02 VGA simulation (macOS / Apple silicon).
//
// This translation unit stands in for everything the firmware's vga_core.c
// normally supplies to the *portable* renderer in vga_graphics.c:
//
//   - the packed 4bpp framebuffer (vga_data_array) and all the text/terminal
//     state globals,
//   - the dma_memset/dma_memcpy/getByte helpers (plain memory ops on host),
//   - enableCurs + the double-buffer entry points,
//   - a host initVGA,
//
// and then it #includes the *real* vga_graphics.c (which itself pulls in
// escape_seq.c) so the drawing/sprite/tile/terminal/escape code that runs on
// the Pico is exactly the code that runs here — no reimplementation.
//
// It also implements the Pico SDK shims declared in pico_shim.h: host timing,
// a pthread-based repeating timer, silent multicore/sound stubs, and the PS/2
// input ring that the SDL viewer feeds from keyboard events.
//
// Build with -DHOST_SIM. Never compiled into the firmware.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>

#include "pico_shim.h"            // uint, __in_flash, SDK shim prototypes

// Pure font data. __in_flash() was neutralised by pico_shim.h above.
#include "../pico_core/vga_fonts.c"
// Real declarations: SCREENWIDTH/HEIGHT, colour enums, masks, sprite_t/tile_t,
// scrpos, ansi_pallet, pgm_read_byte, the graphics prototypes. Its Pico-SDK
// #includes are compiled out under HOST_SIM.
#include "../pico_core/vga_core.h"

// ======================================================================
//  Global state normally defined in vga_core.c (see its lines 70..174).
//  vga_graphics.c / escape_seq.c reference these; keep types in sync.
// ======================================================================
int txcount = (SCREENWIDTH * SCREENHEIGHT) / 2;      // bytes in a framebuffer

static unsigned char vga_buf0[(SCREENWIDTH * SCREENHEIGHT) / 2];
static unsigned char vga_buf1[(SCREENWIDTH * SCREENHEIGHT) / 2];
unsigned char *const vga_data_array[2] = { vga_buf0, vga_buf1 };

int scanline_size = (SCREENWIDTH / 2);

static const unsigned char *font = font_sweet16;     // written by setFont
static char txtfont = 0;
static bool wrap = true, cr2crlf = false, lf2crlf = false, smooth_scroll = false;

volatile char textfgcolor = WHITE_INT, textbgcolor = BLACK_INT;

struct scrpos savedTcurs = { 0, 0 };
volatile struct scrpos tcurs = { 0, 0 };
struct scrpos maxTcurs = { (SCREENWIDTH / FONTWIDTH) - 1,
                           (SCREENHEIGHT / FONTHEIGHT) - 1 };

unsigned char *terminal;                             // malloc'd in initVGA
int terminal_size = (SCREENWIDTH / FONTWIDTH) * (SCREENHEIGHT / FONTHEIGHT);
int textrow_size  = (SCREENWIDTH / FONTWIDTH);

int cursor_y, cursor_x, textsize;

volatile int  db_show = 0;
volatile int  db_draw = 0;
volatile bool cursorEnabled = false;
volatile bool cursorOn = false;

// ======================================================================
//  Helpers vga_graphics.c/escape_seq.c call that live in vga_core.c.
//  Must be declared before the #include of vga_graphics.c below.
// ======================================================================

// On hardware these drive a DMA channel; on the host they are plain memory
// ops. dma_memcpy callers can pass overlapping ranges (scroll), so use memmove.
void dma_memset(void *dest, uint8_t val, size_t num, bool block) {
    (void)block;
    memset(dest, (int)val, num);
}
void dma_memcpy(void *dest, const void *src, size_t num, bool block) {
    (void)block;
    memmove(dest, src, num);
}

// ----------------------------------------------------------------------
//  6502 byte stream. On hardware, bytes the 6502 writes to the Pico arrive
//  via the memin PIO + readMem ISR into a ring; getByte() drains it. Here the
//  same ring is fed by sim_link.c (a unix socket to the x65c02 emulator), so
//  getByte() keeps the exact firmware semantics (vga_core.c:329).
//
//  Producer: sim_feed_6502_byte() (socket reader thread).
//  Consumer: getByte() -> conInTask() -> handleByte().
// ----------------------------------------------------------------------
#define IN6502_RING 8192
static unsigned char   in6502buf[IN6502_RING];
static volatile int    in6502_r = 0, in6502_w = 0;
static pthread_mutex_t  in6502_mx = PTHREAD_MUTEX_INITIALIZER;

void sim_feed_6502_byte(unsigned char c) {
    pthread_mutex_lock(&in6502_mx);
    int nw = (in6502_w + 1) % IN6502_RING;
    if (nw != in6502_r) { in6502buf[in6502_w] = c; in6502_w = nw; }  // drop on overflow
    pthread_mutex_unlock(&in6502_mx);
}

bool getByte(unsigned char *ascii) {
    bool has = false;
    pthread_mutex_lock(&in6502_mx);
    if (in6502_r != in6502_w) {
        *ascii = in6502buf[in6502_r];
        in6502_r = (in6502_r + 1) % IN6502_RING;
        has = true;
    }
    pthread_mutex_unlock(&in6502_mx);
    return has;
}

// The firmware's consume-and-render task lives in vga_core.c, which the sim
// does not compile; reproduce its three lines here (vga_core.c:342-347).
void conInTask(void) {
    unsigned char ascii;
    if (getByte(&ascii)) {
        handleByte(ascii);
    }
}

// Cursor enable — ported verbatim from vga_core.c:160. drawChar is declared by
// vga_core.h and defined below (in the vga_graphics.c include).
bool enableCurs(bool flag) {
    bool was = cursorEnabled;
    if (!flag && cursorEnabled && cursorOn) {         // turning it off when on
        int idx = tcurs.x + (tcurs.y * textrow_size);
        unsigned char oldChar = terminal[idx] ? terminal[idx] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar,
                 textfgcolor, textbgcolor, textsize, false);
    }
    cursorEnabled = flag;
    return was;
}

// Double-buffering is a no-op on the host: the demo never enables it, and the
// SDL viewer scans db_show == db_draw == 0 directly. These exist because
// escape_seq.c references them (ESC Z8..Z11).
void enableDB(void)     {}
void disableDB(void)    {}
void show2drawDB(void)  {}
void switchDB(void)     {}
void setDBSwap(bool sw) { (void)sw; }

// Host framebuffer/terminal init (stands in for vga_core.c initVGA()).
void initVGA(void) {
    memset(vga_buf0, 0, sizeof vga_buf0);             // black
    terminal = malloc((size_t)terminal_size);
    memset(terminal, ' ', (size_t)terminal_size);
}

// ======================================================================
//  The real renderer. Pulls in escape_seq.c at its line 812.
// ======================================================================
#include "../pico_core/vga_graphics.c"

// ======================================================================
//  Pico SDK shims (declared in pico_shim.h).
// ======================================================================

void sleep_ms(uint32_t ms) {
    struct timespec ts = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}
void sleep_us(uint64_t us) {
    struct timespec ts = { us / 1000000, (long)(us % 1000000) * 1000L };
    nanosleep(&ts, NULL);
}
bool set_sys_clock_khz(uint32_t khz, bool required) { (void)khz; (void)required; return true; }
void stdio_init_all(void) {}

// core1 (PS/2 init + sound synth) runs on a host thread. initSOUND/soundTask/
// startup_chord/beep are the REAL functions from pico_synth_ex.c.
static void *core1_trampoline(void *entry) {
    ((void (*)(void))entry)();     // runs core1_main: initSOUND + startup_chord + soundTask loop
    return NULL;
}
void multicore_launch_core1(void (*entry)(void)) {
    pthread_t th;
    if (pthread_create(&th, NULL, core1_trampoline, (void *)entry) == 0)
        pthread_detach(th);
}

// Inter-core FIFO: core0 (demo/escape) pushes note/preset command bytes, core1's
// soundTask() drains them.
#define FIFO_RING 256
static uint32_t        fifo[FIFO_RING];
static volatile int    fifo_r = 0, fifo_w = 0;
static pthread_mutex_t fifo_mx = PTHREAD_MUTEX_INITIALIZER;

void multicore_fifo_push_blocking(uint32_t data) {
    pthread_mutex_lock(&fifo_mx);
    int nw = (fifo_w + 1) % FIFO_RING;
    if (nw != fifo_r) { fifo[fifo_w] = data; fifo_w = nw; }   // drop on overflow
    pthread_mutex_unlock(&fifo_mx);
}
bool multicore_fifo_rvalid(void) {
    pthread_mutex_lock(&fifo_mx);
    bool has = (fifo_r != fifo_w);
    pthread_mutex_unlock(&fifo_mx);
    if (!has) usleep(500);        // core1_main polls this in a tight loop; throttle
    return has;
}
uint32_t multicore_fifo_pop_blocking(void) {
    for (;;) {
        pthread_mutex_lock(&fifo_mx);
        if (fifo_r != fifo_w) {
            uint32_t v = fifo[fifo_r];
            fifo_r = (fifo_r + 1) % FIFO_RING;
            pthread_mutex_unlock(&fifo_mx);
            return v;
        }
        pthread_mutex_unlock(&fifo_mx);
        usleep(500);              // block until a command arrives
    }
}

// ---- host repeating timer ----
struct rt_arg {
    long                        delay_us;
    repeating_timer_callback_t  cb;
    struct repeating_timer     *t;
};
static void *rt_thread(void *p) {
    struct rt_arg *a = (struct rt_arg *)p;
    for (;;) {
        struct timespec ts = { a->delay_us / 1000000,
                               (long)(a->delay_us % 1000000) * 1000L };
        nanosleep(&ts, NULL);
        if (!a->cb(a->t)) break;                      // false => stop repeating
    }
    free(a);
    return NULL;
}
bool add_repeating_timer_ms(int32_t delay_ms, repeating_timer_callback_t cb,
                            void *user_data, struct repeating_timer *out) {
    long us = (long)(delay_ms < 0 ? -delay_ms : delay_ms) * 1000L;
    if (out) { out->delay_us = us; out->user_data = user_data; }
    struct rt_arg *a = (struct rt_arg *)malloc(sizeof *a);
    a->delay_us = us; a->cb = cb; a->t = out;
    pthread_t th;
    if (pthread_create(&th, NULL, rt_thread, a) != 0) { free(a); return false; }
    pthread_detach(th);
    return true;
}

// ---- PS/2 input ring: SDL main thread writes, demo thread reads ----
#define PS2_RING 256
static unsigned char   ps2buf[PS2_RING];
static volatile int    ps2_r = 0, ps2_w = 0;
static pthread_mutex_t  ps2_mx = PTHREAD_MUTEX_INITIALIZER;

void sim_feed_key(unsigned char c) {
    pthread_mutex_lock(&ps2_mx);
    int nw = (ps2_w + 1) % PS2_RING;
    if (nw != ps2_r) { ps2buf[ps2_w] = c; ps2_w = nw; }   // drop on overflow
    pthread_mutex_unlock(&ps2_mx);
}
void initPS2(void) {}
void clearPS2(void) {
    pthread_mutex_lock(&ps2_mx);
    ps2_r = ps2_w = 0;
    pthread_mutex_unlock(&ps2_mx);
}
// Matches ps2_keyboard.h: non-blocking, returns 0 if none. auto_print echoes.
unsigned char ps2GetChar(bool auto_print) {
    unsigned char c = 0;
    pthread_mutex_lock(&ps2_mx);
    if (ps2_r != ps2_w) { c = ps2buf[ps2_r]; ps2_r = (ps2_r + 1) % PS2_RING; }
    pthread_mutex_unlock(&ps2_mx);
    if (c && auto_print) writeChar(c);
    if (!c) usleep(2000);         // the demo busy-polls this; don't peg a core
    return c;
}
