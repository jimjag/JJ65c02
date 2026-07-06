// Headless verification harness: run the real demo for a short time against the
// host framebuffer (no SDL window), then snapshot it through the palette to a
// 24-bit BMP. Lets the render pipeline be checked in CI / over SSH where no
// display is available. Not part of the shipping viewer.
//
//   cc -DHOST_SIM sim_dump.c sim_platform.c ../pico_core/pico_core_demo.c \
//      -lpthread -o sim_dump && ./sim_dump 2 out.bmp
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include "pico_shim.h"

extern unsigned char *const vga_data_array[2];
extern volatile int        db_show;
int demo_main(void);

#define W 640
#define H 480

static const uint32_t palette[16] = {
    0x000000, 0xC00000, 0x00C000, 0xC0C000, 0x0000C0, 0xC000C0, 0x00C0C0, 0xC0C0C0,
    0x808080, 0xFF0000, 0x00FF00, 0xFFFF00, 0x0080FF, 0xFF00FF, 0x00FFFF, 0xFFFFFF,
};

static void *demo_thread(void *a) { (void)a; demo_main(); return NULL; }

static void put_u32(FILE *f, uint32_t v) { fputc(v, f); fputc(v>>8, f); fputc(v>>16, f); fputc(v>>24, f); }
static void put_u16(FILE *f, uint16_t v) { fputc(v, f); fputc(v>>8, f); }

static void write_bmp(const char *path) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror("fopen"); exit(1); }
    int rowbytes = W * 3;
    int pad = (4 - (rowbytes % 4)) % 4;
    uint32_t pixdata = (rowbytes + pad) * H;
    // BITMAPFILEHEADER
    fputc('B', f); fputc('M', f);
    put_u32(f, 14 + 40 + pixdata);
    put_u16(f, 0); put_u16(f, 0);
    put_u32(f, 14 + 40);
    // BITMAPINFOHEADER
    put_u32(f, 40); put_u32(f, W); put_u32(f, H);
    put_u16(f, 1); put_u16(f, 24);
    put_u32(f, 0); put_u32(f, pixdata);
    put_u32(f, 2835); put_u32(f, 2835); put_u32(f, 0); put_u32(f, 0);
    const unsigned char *fb = vga_data_array[db_show];
    for (int y = H - 1; y >= 0; y--) {                 // BMP rows are bottom-up
        for (int x = 0; x < W; x++) {
            int p = y * W + x;
            unsigned char b = fb[p >> 1];
            unsigned char idx = (p & 1) ? (b >> 4) & 0x0F : b & 0x0F;
            uint32_t rgb = palette[idx];
            fputc(rgb & 0xFF, f); fputc((rgb >> 8) & 0xFF, f); fputc((rgb >> 16) & 0xFF, f);
        }
        for (int i = 0; i < pad; i++) fputc(0, f);
    }
    fclose(f);
}

int main(int argc, char **argv) {
    int secs = argc > 1 ? atoi(argv[1]) : 2;
    const char *out = argc > 2 ? argv[2] : "out.bmp";
    pthread_t th;
    pthread_create(&th, NULL, demo_thread, NULL);
    sleep_ms((uint32_t)secs * 1000);                   // let the demo draw
    write_bmp(out);
    printf("wrote %s after %ds\n", out, secs);
    return 0;
}
