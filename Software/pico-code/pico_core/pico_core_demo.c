/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
/**
 * Graphics demo for beam-chasing VGA architecture.
 * Demonstrates background pixel layer, tilemap, sprites, and text mode.
 */

// Orig version V. Hunter Adams / Cornell

#include "vga_core.h"
#include "ps2_keyboard.h"
#include "pico_synth_ex.h"
#include <stdio.h>
#include <stdlib.h>
#include "pico.h"
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/dma.h"
#include "pico/multicore.h"
#include "hardware/vreg.h"

// Some globals for storing timer information
volatile int time_accum = 12;
int time_accum_old = 0;
char timetext[40];
char mem[40];

// Timer interrupt
bool repeating_timer_callback(struct repeating_timer *t) {
    time_accum -= 1;
    return true;
}

void core1_main() {
    initPS2();
    clearPS2();
    initSOUND();
    startup_chord();
    while (true) {
        soundTask();
    }
}

#include <malloc.h>

uint32_t getTotalHeap(void) {
    extern char __StackLimit, __bss_end__;
    return &__StackLimit  - &__bss_end__;
}

uint32_t getFreeHeap(void) {
    struct mallinfo m = mallinfo();
    return getTotalHeap() - m.uordblks;
}

uint32_t getChunks(void) {
    struct mallinfo m = mallinfo();
    return m.ordblks;
}

uint32_t getProgramSize(void) {
    extern char __flash_binary_start, __flash_binary_end;
    return &__flash_binary_end - &__flash_binary_start;
}

uint32_t getFreeProgramSpace() {
    return PICO_FLASH_SIZE_BYTES - getProgramSize();
}

int main() {
    // rp2350 will run at 300 Mhz at 1.3 volt
    set_sys_clock_khz(300000, true);
    stdio_init_all();

    multicore_launch_core1(&core1_main);

    // Initialize the VGA screen
    initVGA();
    setFont(0);

    // --- Graphics primitives demo (tile mode with background pixel layer) ---
    setRenderModeTile();
    vgaFillScreen(BLACK_INT);

    // circle radii
    short circle_r = 0;
    short circle_x = 320;

    // color chooser
    char color_index = 0;

    // position of the disc primitive
    short disc_x = 0;
    // position of the box primitive
    short box_x = 0;
    // position of vertical line primitive
    short Vline_x = 350;
    // position of horizontal line primitive
    short Hline_y = 250;

    // Draw some filled rectangles on background layer
    drawFilledRect(20, 0, 176+44, 50, BLUE, true);
    drawFilledRect(250, 0, 176, 50, RED, true);
    drawFilledRect(435, 0, 176, 50, GREEN, true);

    // Write some text onto the background layer
    setTextColor2(WHITE, BLUE);
    setCursor(22, 0);
    setTextSize(1);
    drawString((unsigned char *)VERSION_6502);
    setCursor(22, 16);
    drawString((unsigned char *)"Graphics demo/HA based");
    setCursor(22, 32);
    drawString((unsigned char *)"JJ65C02");
    setCursor(250, 4);
    setTextSize(2);
    setTextColor2(WHITE, RED);
    drawString((unsigned char *)"Countdown:");

    // Setup a 1Hz timer
    struct repeating_timer timer;
    add_repeating_timer_ms(-999, repeating_timer_callback, NULL, &timer);

    while (true) {
        beamRenderTask();

        if (color_index++ == 15) color_index = 0;

        // A row of filled circles
        drawFilledCircle(disc_x, 100, 20, color_index, false);
        disc_x += 35;
        if (disc_x > 640) disc_x = 0;

        // Concentric empty circles
        drawCircle(circle_x, 200, circle_r, color_index, false);
        if (circle_r++ > 95) circle_r = 0;
        circle_x += 2;
        if (circle_x > 350) circle_x = 320;

        // A series of rectangles
        drawRect(10, 300, box_x, box_x, color_index, false);
        box_x += 5;
        if (box_x > 195) box_x = 10;

        // Random lines
        drawLine(210 + (rand() & 0x7f), 350 + (rand() & 0x7f), 210 + (rand() & 0x7f),
                 350 + (rand() & 0x7f), color_index, false);

        // Vertical lines
        drawVLine(Vline_x, 300, (Vline_x >> 2), color_index, false);
        Vline_x += 2;
        if (Vline_x > 620) Vline_x = 350;

        // Horizontal lines
        drawHLine(400, Hline_y, 150, color_index, false);
        Hline_y += 2;
        if (Hline_y > 400) Hline_y = 240;

        // Timing text
        if (time_accum != time_accum_old) {
            time_accum_old = time_accum;
            sprintf(timetext, "%02d", time_accum);
            setCursor(440, 4);
            setTextSize(2);
            setTextColor2(WHITE, GREEN);
            drawString((unsigned char *)timetext);
        }

        sleep_ms(10);
        if (time_accum < 0) break;
    }

    // --- Scroll and fill demo ---
    sleep_ms(1000);
    vgaFillScreen(BLACK_INT);
    sleep_ms(1000);

    // Color palette display
    char video_buffer[32];
    setTextColor2(WHITE, BLACK);
    setTextSize(1);
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            drawFilledRoundRect(i * 110 + 20, 100 + j * 70, 60, 60, 3, i + 4 * j, false);
            setCursor(i * 110 + 20, 100 + j * 70);
            sprintf(video_buffer, "%2d", i + 4 * j);
            drawString((unsigned char *)video_buffer);
        }
    }
    // Color labels
    setCursor(0 * 110 + 20, 150 + 0 * 70); drawString((unsigned char *)"Black");
    setCursor(1 * 110 + 20, 150 + 0 * 70); drawString((unsigned char *)"Red");
    setCursor(2 * 110 + 20, 150 + 0 * 70); drawString((unsigned char *)"Green");
    setCursor(3 * 110 + 20, 150 + 0 * 70); drawString((unsigned char *)"Yellow");
    setCursor(0 * 110 + 20, 150 + 1 * 70); drawString((unsigned char *)"Blue");
    setCursor(1 * 110 + 20, 150 + 1 * 70); drawString((unsigned char *)"Magenta");
    setCursor(2 * 110 + 20, 150 + 1 * 70); drawString((unsigned char *)"Cyan");
    setCursor(3 * 110 + 20, 150 + 1 * 70); drawString((unsigned char *)"Light Grey");
    setCursor(0 * 110 + 20, 150 + 2 * 70); drawString((unsigned char *)"Grey");
    setCursor(1 * 110 + 20, 150 + 2 * 70); drawString((unsigned char *)"Light Red");
    setCursor(2 * 110 + 20, 150 + 2 * 70); drawString((unsigned char *)"Light Green");
    setCursor(3 * 110 + 20, 150 + 2 * 70); drawString((unsigned char *)"Light Yellow");
    setCursor(0 * 110 + 20, 150 + 3 * 70); drawString((unsigned char *)"Light Blue");
    setCursor(1 * 110 + 20, 150 + 3 * 70); drawString((unsigned char *)"Light Magenta");
    setCursor(2 * 110 + 20, 150 + 3 * 70); drawString((unsigned char *)"Light Cyan");
    setCursor(3 * 110 + 20, 150 + 3 * 70); drawString((unsigned char *)"White");

    // Font showcase
    setFont(1); setCursor(0, 460);
    drawString((unsigned char *)"ACM|     1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?#%*&@");
    setFont(2); setCursor(0, 440);
    drawString((unsigned char *)"Toshiba| 1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?#%*&@");
    setFont(3); setCursor(0, 420);
    drawString((unsigned char *)"Sperry|  1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?#%*&@");
    setFont(4); setCursor(0, 400);
    drawString((unsigned char *)"Verite|  1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?#%*&@");
    setFont(0); setCursor(0, 380);
    drawString((unsigned char *)"Sweet16| 1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?#%*&@");
    sleep_ms(5000);

    // --- Sprite and tile demo ---
    unsigned char foo2[] = {
        0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0xff, 0xff, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0xff, 0xff, 0xff, 0xff, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x68, 0x18, 0x68, 0x68, 0x68, 0x92, 0x92, 0x92, 0xdb, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0xdb, 0x92, 0x92, 0x92, 0x68, 0x68, 0x68, 0xe0, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x18, 0x18, 0x92, 0x92, 0x92, 0xdb, 0xdb, 0xdb, 0x1f, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x1f, 0xdb, 0xdb, 0xdb, 0x92, 0x92, 0x92, 0xe0, 0xe0, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x92, 0x1b, 0x1b, 0x1b, 0xdb, 0xdb, 0xdb, 0xdb, 0x1f, 0x68, 0x68, 0x00, 0x68, 0x68, 0x00, 0x68, 0x68, 0x1f, 0xdb, 0xdb, 0xdb, 0xdb, 0x1b, 0x1b, 0x1b, 0x92, 0x68, 0x68, 0x68, 0x68,
        0x68, 0xff, 0xe3, 0xe3, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xe3, 0xe3, 0xff, 0x68, 0x68, 0x68,
        0x68, 0x92, 0x92, 0x92, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0x92, 0x92, 0x92, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x68, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x68, 0x68, 0x68, 0x00, 0x00, 0x68, 0x68, 0xff, 0xfc, 0xff, 0xfc, 0xff, 0xfc, 0xff, 0xfc, 0xff, 0xfc, 0xff, 0xfc, 0x68, 0x68, 0x00, 0x00, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68,
        0x68, 0x68, 0x00, 0x00, 0x00, 0x00, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x68, 0x00, 0x00, 0x00, 0x00, 0x68, 0x68, 0x68, 0x68,
    };
    unsigned char tile_data[] = {
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0xe0, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0xfc, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0xdb, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0xff, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0xdb, 0x92, 0x92,
        0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0xdb, 0x92, 0xdb, 0x92,
        0x92, 0xe0, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92, 0x92,
    };

    // Fill background with blue, load tile and sprites
    vgaFillScreen(BLUE_INT);
    loadTile(1, TILE32_WIDTH, 11, tile_data);

    // Place tiles on the tilemap grid (tile 1 fills the screen)
    // Tilemap is 40 cols x 30 rows for 16px tiles; our 32px tile spans 2 cols
    // For simplicity, just fill a portion
    for (int r = 0; r < 30; r++)
        for (int c = 0; c < 40; c++)
            setTilemapCell(c, r, 1);

    // Load sprites
    for (int i = 0; i < 31; i++)
        loadSprite(i, SPRITE32_WIDTH, 11, foo2);

    // Show memory info on background layer
    setTextColor2(WHITE, BLUE);
    setTextSize(1);
    setCursor(65, 0);
    sprintf(mem, "TotalHeap: %llu", (int64_t)(uint32_t)getTotalHeap());
    drawString((unsigned char *)mem);
    setCursor(65, 16);
    sprintf(mem, "FreeHeap: %llu", (int64_t)(uint32_t)getFreeHeap());
    drawString((unsigned char *)mem);
    setCursor(65, 32);
    sprintf(mem, "Chunks: %llu", (int64_t)(uint32_t)getChunks());
    drawString((unsigned char *)mem);
    setCursor(65, 48);
    sprintf(mem, "ProgSize: %llu", (int64_t)(uint32_t)getProgramSize());
    drawString((unsigned char *)mem);
    setCursor(65, 64);
    sprintf(mem, "FreeProgSpace: %llu", (int64_t)(uint32_t)getFreeProgramSpace());
    drawString((unsigned char *)mem);

    // Animate sprites across the screen
    int y = 2;
    int x0 = 605;
    int y0 = 1;
    for (int i = 10; i < 400; i++) {
        beamRenderTask();
        moveSprite(0, i, y);
        for (int j = 1; j < 15; j++)
            moveSprite(j, (x0 - (j*20)), (y0 + (j*15)));
        for (int j = 15; j < 31; j++)
            moveSprite(j, (x0 - (j*10)), (y0 + (j*15)));
        y++;
        x0--;
        y0++;
        multicore_fifo_push_blocking(i % 2 ? 'q' : '7');
        sleep_ms(25);
    }

    // --- Switch to text mode for PS2 keyboard test ---
    setRenderModeText();
    setTextColor2(WHITE, BLACK);
    clearScreen();
    setTxtCursor(0, 0);
    printString("PS2 keyboard test - press Backspace to exit");
    setTxtCursor(0, 2);
    setTextColor2(GREEN, BLACK);
    clearPS2();
    enableCurs(true);
    while (true) {
        beamRenderTask();
        char c = ps2GetChar(false);
        if (c == '\b') break;
        if (c) writeChar(c);
    }
    enableCurs(false);

    // --- ESC sequence graphics test (tile mode) ---
    setRenderModeTile();
    vgaFillScreen(BLACK_INT);
    setTextColor(RED_INT);
    printString("\x1b[Z18;10;10;500;5Z");
    setTextColor(BLUE_INT);
    printString("\x1b[Z19;30;30;40;45Z");
    setTextColor(GREEN_INT);
    printString("\x1b[Z20;50;50;75;155Z");
    setTextColor(CYAN_INT);
    printString("\x1b[Z21;100;100;55Z");
    setTextColor(YELLOW_INT);
    printString("\x1b[Z22;200;200;55Z");

    // Wait for 'Q' to exit
    while (true) {
        beamRenderTask();
        unsigned char c = ps2GetChar(false);
        if (c == 'Q') break;
        if (c == 0) continue;
        multicore_fifo_push_blocking((uint32_t)c);
    }
}
