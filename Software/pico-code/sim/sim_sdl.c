// SDL2 viewer for the JJ65c02 VGA simulation (macOS / Apple silicon baseline).
//
// Owns the process main thread (required for a Cocoa/SDL event loop on macOS):
// creates the 640x480 window, runs the real pico_core_demo.c on a worker
// thread, and every frame expands the packed 4bpp framebuffer through the
// 16-colour palette into an ARGB texture and presents it. Keyboard events are
// decoded to ASCII and pushed into the demo's PS/2 input ring.
//
// Build with -DHOST_SIM. See build.sh / README.md.

#include <SDL2/SDL.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <pthread.h>

#include "pico_shim.h"

// Provided by sim_platform.c.
extern unsigned char *const vga_data_array[2];
extern volatile int        db_show;
// pico_core_demo.c's main(), renamed under HOST_SIM.
int demo_main(void);

#define SCREEN_W 640
#define SCREEN_H 480
#define SCALE    2                 // window is SCALE x the 640x480 logical size

// Internal colour index -> RGB. These are exactly the "Regular RGB" values
// documented next to each case in vga_core.c's convertRGB332() (BLACK..WHITE).
// Packed 0xAARRGGBB for SDL_PIXELFORMAT_ARGB8888.
static const uint32_t palette[16] = {
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

static void *demo_thread(void *arg) {
    (void)arg;
    demo_main();
    return NULL;   // demo returned; window stays open until closed by the user
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    SDL_Window *win = SDL_CreateWindow(
        "JJ65c02 VGA simulation",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        SCREEN_W * SCALE, SCREEN_H * SCALE, SDL_WINDOW_ALLOW_HIGHDPI);
    if (!win) { fprintf(stderr, "CreateWindow: %s\n", SDL_GetError()); return 1; }

    SDL_Renderer *ren = SDL_CreateRenderer(
        win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!ren) { fprintf(stderr, "CreateRenderer: %s\n", SDL_GetError()); return 1; }
    SDL_RenderSetLogicalSize(ren, SCREEN_W, SCREEN_H);   // crisp integer upscale

    SDL_Texture *tex = SDL_CreateTexture(
        ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
        SCREEN_W, SCREEN_H);
    if (!tex) { fprintf(stderr, "CreateTexture: %s\n", SDL_GetError()); return 1; }

    SDL_StartTextInput();

    // Run the real demo on a worker thread; SDL stays on the main thread.
    pthread_t demo_tid;
    if (pthread_create(&demo_tid, NULL, demo_thread, NULL) != 0) {
        fprintf(stderr, "pthread_create failed\n");
        return 1;
    }

    static uint32_t rgba[SCREEN_W * SCREEN_H];
    bool running = true;
    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
            case SDL_QUIT:
                running = false;
                break;
            case SDL_TEXTINPUT:                 // printable ASCII
                for (const char *s = e.text.text; *s; s++)
                    sim_feed_key((unsigned char)*s);
                break;
            case SDL_KEYDOWN:                   // keys SDL_TEXTINPUT won't give us
                switch (e.key.keysym.sym) {
                case SDLK_RETURN:
                case SDLK_KP_ENTER:   sim_feed_key('\r'); break;
                case SDLK_BACKSPACE:  sim_feed_key('\b'); break;
                case SDLK_TAB:        sim_feed_key('\t'); break;
                case SDLK_ESCAPE:     running = false;    break;  // ESC = quit app
                default: break;
                }
                break;
            default: break;
            }
        }

        // Expand the packed framebuffer: low nibble = even/left pixel (emitted
        // first by the PIO), high nibble = odd/right pixel.
        const unsigned char *fb = vga_data_array[db_show];
        for (int i = 0; i < SCREEN_W * SCREEN_H / 2; i++) {
            unsigned char b = fb[i];
            rgba[i * 2]     = palette[b & 0x0F];
            rgba[i * 2 + 1] = palette[(b >> 4) & 0x0F];
        }

        SDL_UpdateTexture(tex, NULL, rgba, SCREEN_W * (int)sizeof(uint32_t));
        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, tex, NULL, NULL);
        SDL_RenderPresent(ren);                 // vsync paces the loop (~60 Hz)
    }

    SDL_StopTextInput();
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;   // process exits; detached demo thread goes with it
}
