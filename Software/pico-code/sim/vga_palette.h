// Internal colour index (0..15) -> ARGB8888, matching the "Regular RGB"
// comments beside each case in vga_core.c's convertRGB332(). Shared by the SDL
// viewer (sim_sdl.c) and the sprite-test display (tests/sprite/test_display.c)
// so both render the framebuffer identically.
#ifndef SIM_VGA_PALETTE_H
#define SIM_VGA_PALETTE_H

#include <stdint.h>

static const uint32_t vga_palette_argb[16] = {
    0xFF000000, // 0  BLACK
    0xFFC00000, // 1  RED
    0xFF00C000, // 2  GREEN
    0xFFC0C000, // 3  YELLOW
    0xFF0000C0, // 4  BLUE
    0xFFC000C0, // 5  MAGENTA
    0xFF00C0C0, // 6  CYAN
    0xFFC0C0C0, // 7  LIGHT_GREY
    0xFF808080, // 8  GREY
    0xFFFF0000, // 9  LIGHT_RED
    0xFF00FF00, // 10 LIGHT_GREEN
    0xFFFFFF00, // 11 LIGHT_YELLOW
    0xFF0080FF, // 12 LIGHT_BLUE
    0xFFFF00FF, // 13 LIGHT_MAGENTA
    0xFF00FFFF, // 14 LIGHT_CYAN
    0xFFFFFFFF, // 15 WHITE
};

#endif // SIM_VGA_PALETTE_H
