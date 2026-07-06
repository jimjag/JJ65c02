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
#include "vga_palette.h"   // vga_palette_argb[16]

// Provided by sim_platform.c.
extern unsigned char *const vga_data_array[2];
extern volatile int        db_show;
// pico_core_demo.c's main(), renamed under HOST_SIM.
int demo_main(void);

#define SCREEN_W 640
#define SCREEN_H 480
#define SCALE    2                 // window is SCALE x the 640x480 logical size

// Colour index -> ARGB is shared with the sprite-test display; see vga_palette.h.

// Decoded keys go into the PS/2 input ring, exactly as on hardware. In demo
// mode the demo drains it via ps2GetChar; in console mode core1's ps2Task drains
// it and ships each byte to the emulator over the socket (see sim_link.c).
static void feed_key(unsigned char c) {
    sim_feed_key(c);
}

static void *demo_thread(void *arg) {
    (void)arg;
    demo_main();
    return NULL;   // demo returned; window stays open until closed by the user
}

// SDL audio thread pulls mono S16 samples from the synth (pico_synth_ex.c),
// which is driven by note/preset commands the demo sends over the FIFO.
static void audio_cb(void *ud, Uint8 *stream, int len) {
    (void)ud;
    synth_render_s16((int16_t *)stream, len / (int)sizeof(int16_t));
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
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

    // Open the audio device (mono S16 @ 44.1 kHz, matching the synth's FS).
    SDL_AudioSpec want, have;
    SDL_zero(want);
    want.freq     = 44100;
    want.format   = AUDIO_S16SYS;
    want.channels = 1;
    want.samples  = 1024;
    want.callback = audio_cb;
    SDL_AudioDeviceID adev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (adev == 0)
        fprintf(stderr, "audio disabled: %s\n", SDL_GetError());
    else
        SDL_PauseAudioDevice(adev, 0);   // start pulling samples

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
                    feed_key((unsigned char)*s);
                break;
            case SDL_KEYDOWN:                   // keys SDL_TEXTINPUT won't give us
                switch (e.key.keysym.sym) {
                case SDLK_RETURN:
                case SDLK_KP_ENTER:   feed_key('\r');   break;
                case SDLK_BACKSPACE:  feed_key('\b');   break;
                case SDLK_TAB:        feed_key('\t');   break;
                // ESC is a console key (starts ANSI sequences); send it on,
                // don't quit. Quit via the window close button / Cmd+Q.
                case SDLK_ESCAPE:     feed_key(0x1b);   break;
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
            rgba[i * 2]     = vga_palette_argb[b & 0x0F];
            rgba[i * 2 + 1] = vga_palette_argb[(b >> 4) & 0x0F];
        }

        SDL_UpdateTexture(tex, NULL, rgba, SCREEN_W * (int)sizeof(uint32_t));
        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, tex, NULL, NULL);
        SDL_RenderPresent(ren);                 // vsync paces the loop (~60 Hz)
    }

    SDL_StopTextInput();
    if (adev) SDL_CloseAudioDevice(adev);
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;   // process exits; detached demo thread goes with it
}
