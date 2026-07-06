// Optional SDL display for the sprite host tests. When the suite is built with
// -DTEST_DISPLAY (see `run.sh display`), the test drivers call these hooks to
// show the 128x48 test framebuffer live as sprites are drawn/moved/hidden, so
// the operations being verified can actually be watched. Headless builds (the
// default, with ASan) don't compile or link this file.
//
// The 4bpp framebuffer is expanded through the same palette the real SDL
// emulator uses (../../sim/vga_palette.h). Single-threaded: the test's main()
// thread drives the ops and calls td_frame() to present, which is fine on macOS
// since that IS the process main thread.
#include <SDL2/SDL.h>
#include <stdint.h>
#include <stdlib.h>

#include "../../sim/vga_palette.h"   // vga_palette_argb[16]

static SDL_Window   *win;
static SDL_Renderer *ren;
static SDL_Texture  *tex;
static uint32_t     *rgba;
static int           g_w, g_h;
static int           ok     = 0;   // window created
static int           closed = 0;   // user closed the window -> stop presenting

// Drain the event queue; note a window-close so the rest of the run finishes
// fast and headless.
static void pump(void) {
    SDL_Event e;
    while (SDL_PollEvent(&e))
        if (e.type == SDL_QUIT ||
            (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE))
            closed = 1;
}

void td_open(int w, int h, int scale, const char *title) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return;
    g_w = w; g_h = h;
    win = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                           w * scale, h * scale, 0);
    if (!win) return;
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) return;
    SDL_RenderSetLogicalSize(ren, w, h);
    tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888,
                            SDL_TEXTUREACCESS_STREAMING, w, h);
    if (!tex) return;
    rgba = malloc((size_t)w * h * sizeof(uint32_t));
    ok = (rgba != NULL);
}

// Present the packed 4bpp framebuffer (low nibble = even/left pixel). Returns 0
// once the window has been closed. Cheap no-op if the window never opened.
int td_frame(const unsigned char *fb) {
    if (!ok || closed) return 0;
    pump();
    if (closed) return 0;
    for (int i = 0; i < g_w * g_h / 2; i++) {
        unsigned char b = fb[i];
        rgba[i * 2]     = vga_palette_argb[b & 0x0F];
        rgba[i * 2 + 1] = vga_palette_argb[(b >> 4) & 0x0F];
    }
    SDL_UpdateTexture(tex, NULL, rgba, g_w * (int)sizeof(uint32_t));
    SDL_RenderClear(ren);
    SDL_RenderCopy(ren, tex, NULL, NULL);
    SDL_RenderPresent(ren);
    return 1;
}

void td_delay(int ms) {
    if (!ok || closed) return;
    pump();
    SDL_Delay(ms);
}

// Hold the final frame briefly (or until closed) so the end state is visible.
void td_close(void) {
    if (ok) {
        for (int i = 0; i < 30 && !closed; i++) { pump(); SDL_Delay(50); }  // ~1.5s
        if (tex) SDL_DestroyTexture(tex);
        if (ren) SDL_DestroyRenderer(ren);
        if (win) SDL_DestroyWindow(win);
        free(rgba);
    }
    SDL_Quit();
    ok = 0;
}
