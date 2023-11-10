/**
 *
 * HARDWARE CONNECTIONS
 *  - GPIO 17 ---> VGA Hsync
 *  - GPIO 18 ---> VGA Vsync
 *  - GPIO 19 ---> 470 ohm resistor ---> VGA Red
 *  - GPIO 20 ---> 470 ohm resistor ---> VGA Green
 *  - GPIO 21 ---> 470 ohm resistor ---> VGA Blue
 *  - GPIO 22 ---> 1k ohm resistor ---> VGA Intensity (bright)
 *  - GPIO 15 ---> PS2 Data pin
 *  - GPIO 16 ---> PS2 Clock pin
 *  - RP2040 GND ---> VGA GND
 *
 * RESOURCES USED
 *  - VGA:
 *  -   PIO state machines 0, 1, and 2 on PIO instance 0
 *  -   DMA channels 0, 1, 2, and 3
 *  -   153.6 kBytes of RAM (for pixel color data)
 *  - PS2:
 *  -   PIO state machine 0 on PIO instance 1
 *
 */

// Orig version V. Hunter Adams / Cornell

// VGA graphics library
#include "vga_core.h"
#include "ps2_keyboard.h"
#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/dma.h"

// Some globals for storing timer information
volatile int time_accum = 15;
int time_accum_old = 0;
char timetext[40];

// Timer interrupt
bool repeating_timer_callback(struct repeating_timer *t) {

    time_accum -= 1;
    return true;
}

int main() {

    // Initialize stdio
    stdio_init_all();

    // Initialize the VGA screen
    initVGA();
    initPS2();

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
    // Draw some filled rectangles
    fillRect(64, 0, 176, 50, BLUE); // blue box
    fillRect(250, 0, 176, 50, RED); // red box
    fillRect(435, 0, 176, 50, GREEN); // green box

    // Write some text
    setTextColor(WHITE);
    setCursor(65, 0);
    setTextSize(1);
    writeString("Raspberry Pi Pico");
    setCursor(65, 16);
    writeString("Graphics demo");
    setCursor(65, 32);
    writeString("JJ65C02");
    setCursor(250, 4);
    setTextSize(2);
    writeString("Countdown:");

    // Setup a 1Hz timer
    struct repeating_timer timer;
    add_repeating_timer_ms(-1000, repeating_timer_callback, NULL, &timer);

    while (true) {
        // Modify the color chooser
        if (color_index++ == 15) color_index = 0;

        // A row of filled circles
        fillCircle(disc_x, 100, 20, color_index);
        disc_x += 35;
        if (disc_x > 640) disc_x = 0;

        // Concentric empty circles
        drawCircle(circle_x, 200, circle_r, color_index);
        if (circle_r++ > 95) circle_r = 0;
        circle_x += 2;
        if (circle_x > 350) circle_x = 320;

        // A series of rectangles
        drawRect(10, 300, box_x, box_x, color_index);
        box_x += 5;
        if (box_x > 195) box_x = 10;

        // Random lines
        drawLine(210 + (rand() & 0x7f), 350 + (rand() & 0x7f), 210 + (rand() & 0x7f),
                 350 + (rand() & 0x7f), color_index);

        // Vertical lines
        drawVLine(Vline_x, 300, (Vline_x >> 2), color_index);
        Vline_x += 2;
        if (Vline_x > 620) Vline_x = 350;

        // Horizontal lines
        drawHLine(400, Hline_y, 150, color_index);
        Hline_y += 2;
        if (Hline_y > 400) Hline_y = 240;

        // Timing text
        if (time_accum != time_accum_old) {
            time_accum_old = time_accum;
            sprintf(timetext, "%02d", time_accum);
            setCursor(440, 4);
            setTextSize(2);
            setTextColor2(WHITE, GREEN);
            writeString(timetext);
        }

        // A brief nap
        sleep_ms(10);
        if (time_accum <= 0) break;
    }
    sleep_ms(5000);
    Scroll();
    sleep_ms(5000);
    VGA_fillScreen(BLACK);
    char video_buffer[32];
    setTextColor2(WHITE, BLACK);
    setTextSize(1);
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            fillRect(i * 90 + 20, 150 + j * 70, 60, 60, i + 4 * j);
            setCursor(i * 90 + 20, 150 + j * 70);
            sprintf(video_buffer, "%2d", i + 4 * j);
            writeString(video_buffer);
        }
    }
    // first row of colors
    setCursor(0 * 90 + 20, 200 + 0 * 70);
    writeString("Black");
    setCursor(1 * 90 + 20, 200 + 0 * 70);
    writeString("Red");
    setCursor(2 * 90 + 20, 200 + 0 * 70);
    writeString("Green");
    setCursor(3 * 90 + 20, 200 + 0 * 70);
    writeString("Yellow");
    // second row of colors
    setCursor(0 * 90 + 20, 200 + 1 * 70);
    writeString("Blue");
    setCursor(1 * 90 + 20, 200 + 1 * 70);
    writeString("Magenta");
    setCursor(2 * 90 + 20, 200 + 1 * 70);
    writeString("Cyan");
    setCursor(3 * 90 + 20, 200 + 1 * 70);
    writeString("Light Grey");
    // thrid row of colors
    setCursor(0 * 90 + 20, 200 + 2 * 70);
    writeString("Grey");
    setCursor(1 * 90 + 20, 200 + 2 * 70);
    writeString("Light Red");
    setCursor(2 * 90 + 20, 200 + 2 * 70);
    writeString("Light Green");
    setCursor(3 * 90 + 20, 200 + 2 * 70);
    writeString("Light Yellow");
    // fourth row of colors
    setCursor(0 * 90 + 20, 200 + 3 * 70);
    writeString("Light Blue");
    setCursor(1 * 90 + 20, 200 + 3 * 70);
    writeString("Light Magenta");
    setCursor(2 * 90 + 20, 200 + 3 * 70);
    writeString("Light Cyan");
    setCursor(3 * 90 + 20, 200 + 3 * 70);
    writeString("White");
    setCursor(0, 460);
    writeString("1234567890123456789012345678901234567890123456789012345678901234567890123456789");
    setFont(2);
    setCursor(0, 440);
    writeString("1234567890123456789012345678901234567890123456789012345678901234567890123456789");
    setFont(1);
    sleep_ms(5000);

    char hex[40];
    setTxtCursor(60, 20);
    printString("PS2 test");
    clearPS2();
    while (true) {
        char c = ps2GetChar();
        if (c) {
            setTxtCursor(60, 24);
            printChar(c);
            sprintf(hex, "0x%02x", c);
            setTxtCursor(70, 24);
            printString(hex);
        }
    }

}
