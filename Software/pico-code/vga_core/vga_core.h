/**
 *
 * HARDWARE CONNECTIONS
 *  - GPIO 16 ---> VGA Hsync
 *  - GPIO 17 ---> VGA Vsync
 *  - GPIO 18 ---> 470 ohm resistor ---> VGA Red
 *  - GPIO 19 ---> 470 ohm resistor ---> VGA Blue
 *  - GPIO 20 ---> 470 ohm resistor ---> VGA Green
 *  - GPIO 21 ---> 1k ohm resistor ---> VGA Intensity (bright)
 *  - RP2040 GND ---> VGA GND
 *
 * RESOURCES USED
 *  - PIO state machines 0, 1, and 2 on PIO instance 0
 *  - DMA channels 0, 1, 2, and 3
 *  - 153.6 kBytes of RAM (for pixel color data)
 *
 */
#include <stdint.h>
#include <stddef.h>

// Give the I/O pins that we're using some names that make sense - usable in main()
 enum vga_pins {HSYNC=16, VSYNC, RED_PIN, GREEN_PIN, BLUE_PIN, I_PIN};

// We can only produce 16 (4-bit) colors, so let's give them readable names - usable in main()
enum colors {BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, LIGHT_GREY,
            GREY, LIGHT_RED, LIGHT_GREEN, LIGHT_YELLOW, LIGHT_BLUE, LIGHT_MAGENTA, LIGHT_CYAN, WHITE};

// VGA primitives - usable in main
void initVGA(void);
void drawPixel(short x, short y, char color);
void drawVLine(short x, short y, short h, char color);
void drawHLine(short x, short y, short w, char color);
void drawLine(short x0, short y0, short x1, short y1, char color);
void drawRect(short x, short y, short w, short h, char color);
void drawCircle(short x0, short y0, short r, char color);
void drawCircleHelper( short x0, short y0, short r, unsigned char cornername, char color);
void fillCircle(short x0, short y0, short r, char color);
void fillCircleHelper(short x0, short y0, short r, unsigned char cornername, short delta, char color);
void drawRoundRect(short x, short y, short w, short h, short r, char color);
void fillRoundRect(short x, short y, short w, short h, short r, char color);
void fillRect(short x, short y, short w, short h, char color);
void drawChar(short x, short y, unsigned char c, char color, char bg, unsigned char size);
void setCursor(short x, short y);
void setTextColor(char c);
void setTextColor2(char c, char bg);
void setTextSize(unsigned char s);
void setTextWrap(char w);
void tft_write(unsigned char c);
void writeString(char* str);

void VGA_fillScreen(uint16_t color);

void dma_memset(void *dest, uint8_t val, size_t num);
void dma_memcpy(void *dest, void *src, size_t num);
