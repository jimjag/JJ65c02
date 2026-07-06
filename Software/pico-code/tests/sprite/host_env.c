// Host environment for the sprite unit tests.
//
// The sprite subsystem lives inside vga_graphics.c, which is #included into
// vga_core.c and pulls in the Pico SDK / VGA hardware — it cannot be compiled
// on a host directly. run.sh extracts just the sprite functions (everything
// between the `sprites[]` and `tiles[]` markers) into _extracted.c and
// concatenates:  host_env.c + _extracted.c + <test>.c  into one host TU.
//
// This file provides the minimal symbols the extracted code needs: a stand-in
// framebuffer, the sprite_t struct, the RGB/geometry macros, and stubs for the
// two helpers loadSprite calls. Screen dimensions are deliberately small so a
// test screen is densely populated with overlapping sprites.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef unsigned int uint;

#define SCREENWIDTH   128
#define SCREENHEIGHT  48
#define FBYTES        (SCREENWIDTH*SCREENHEIGHT/2)

#define SPRITE16_WIDTH 16
#define SPRITE32_WIDTH 32
#define MAXSPRITES     32
#define LOW_NIBBLE_MASK 0x0f
#define TRANSPARENT_INT 0xFF
#define LSN64 0x0fULL
#define MSN64 0xf000000000000000ULL

// Must match sprite_t in vga_core.h.
typedef struct {
    uint64_t *bitmap[2][2];
    uint64_t *invmask[2][2];
    uint64_t *bgrnd[2];
    uint64_t opaque[2][2];
    short x, y;
    unsigned char height;
    unsigned char width;
    bool bgValid;
} sprite_t;

// Framebuffer stand-in for vga_data_array[db_draw] (2 pixels/byte, low nibble
// = even/left pixel).
static unsigned char fb[FBYTES];
unsigned char *vga_data_array[2] = { fb, NULL };
volatile int db_draw = 0;

// Public sprite API (defined by the extracted code; loadSprite calls freeSprite).
void drawSprite(uint sn, short x, short y, bool erase);
void loadSprite(uint sn, short width, short height, unsigned char *sdata);
void freeSprite(uint sn);
void eraseSprite(uint sn);
void moveSprite(uint sn, short x, short y);
void hideSprite(uint sn);
void refreshSprites(void);

// Tests feed sprite data already in internal form (0..15 colour, 0xFF = clear),
// so convertRGB332 is the identity-with-clamp and getByte is never used.
static unsigned char convertRGB332(unsigned char c){ return (c<=15)?c:TRANSPARENT_INT; }
static bool getByte(unsigned char *c){ (void)c; return false; }

// -------- optional SDL display (built only with -DTEST_DISPLAY; see run.sh) ----
// The test drivers wrap their operations with these so the framebuffer can be
// watched live. Headless builds compile them out to nothing.
#ifdef TEST_DISPLAY
void td_open(int w, int h, int scale, const char *title);
int  td_frame(const unsigned char *fb);
void td_delay(int ms);
void td_close(void);
#define TD_OPEN(title) td_open(SCREENWIDTH, SCREENHEIGHT, 8, (title))
#define TD_FRAME()     td_frame(fb)
#define TD_DELAY(ms)   td_delay(ms)
#define TD_CLOSE()     td_close()
#else
#define TD_OPEN(title) ((void)0)
#define TD_FRAME()     ((void)0)
#define TD_DELAY(ms)   ((void)0)
#define TD_CLOSE()     ((void)0)
#endif

// ================= REAL CODE (extracted from vga_graphics.c) =================
