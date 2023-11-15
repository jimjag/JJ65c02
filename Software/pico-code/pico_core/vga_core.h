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
#include <stdint.h>
#include <stddef.h>
#include "hardware/pio.h"

// TODO: Eventually support resolutions > 640x480

// VGA timing constants
#define H_ACTIVE 655        // (active + frontporch - 1) - one cycle delay for mov
#define V_ACTIVE 479        // (active - 1)
#define SCANLINE_ACTIVE 319 // (horizontal active)/2 - 1
// #define SCANLINE_ACTIVE 639 // change to this if 1 pixel/byte

// Screen width/height/freq
#define SCREENWIDTH 640
#define SCREENHEIGHT 480
#define PIXFREQ 25000000.0f

// Length of the pixel array, and number of DMA transfers
#define TXCOUNT 153600 // Total pixels/2 (since we have 2 pixels per byte)
// int txcount = (SCREENWIDTH * SCREENHEIGHT) / 2; // Total pixels/2 (since we have 2 pixels per byte)

enum vga_pins {HSYNC=17, VSYNC, RED_PIN, GREEN_PIN, BLUE_PIN, I_PIN};

// We can only produce 16 (4-bit) colors, so let's give them readable names - usable in main()
enum colors {BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, LIGHT_GREY,
            GREY, LIGHT_RED, LIGHT_GREEN, LIGHT_YELLOW, LIGHT_BLUE, LIGHT_MAGENTA, LIGHT_CYAN, WHITE};

// VGA Core Functions
void initVGA(void);
void drawPixel(int x, int y, char color);
void drawVLine(int x, int y, int h, char color);
void drawHLine(int x, int y, int w, char color);
void drawLine(int x0, int y0, int x1, int y1, char color);
void drawRect(int x, int y, int w, int h, char color);
void drawCircle(int x0, int y0, int r, char color);
// void drawCircleHelper( int x0, int y0, int r, unsigned char cornername, char color);
void fillCircle(int x0, int y0, int r, char color);
// void fillCircleHelper(int x0, int y0, int r, unsigned char cornername, int delta, char color);
void drawRoundRect(int x, int y, int w, int h, int r, char color);
void fillRoundRect(int x, int y, int w, int h, int r, char color);
void fillRect(int x, int y, int w, int h, char color);
void drawChar(int x, int y, unsigned char c, char color, char bg, unsigned char size);
void setCursor(int x, int y);
void setTextColor(char c);
void setTextColor2(char c, char bg);
void setTextSize(unsigned char s);
void setTextWrap(char w);
void setFont(char n);
// void tft_write(unsigned char c);
void drawString(unsigned char* str);

void vgaFillScreen(uint16_t color);

void dma_memset(void *dest, uint8_t val, size_t num);
void dma_memcpy(void *dest, void *src, size_t num);

void printChar(unsigned char c);
void vgaScroll (int scanlines);
void termScroll (int rows);
void setTxtCursor(int x, int y);
void printString(unsigned char* str);
unsigned char getChar(void);
