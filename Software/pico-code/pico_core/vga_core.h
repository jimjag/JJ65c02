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
void drawPixel(int x, int y, char color);
void drawVLine(int x, int y, int h, char color);
void drawHLine(int x, int y, int w, char color);
void drawLine(int x0, int y0, int x1, int y1, char color);
void drawRect(int x, int y, int w, int h, char color);
void drawCircle(int x0, int y0, int r, char color);
void drawCircleHelper( int x0, int y0, int r, unsigned char cornername, char color);
void fillCircle(int x0, int y0, int r, char color);
void fillCircleHelper(int x0, int y0, int r, unsigned char cornername, int delta, char color);
void drawRoundRect(int x, int y, int w, int h, int r, char color);
void fillRoundRect(int x, int y, int w, int h, int r, char color);
void fillRect(int x, int y, int w, int h, char color);
void drawChar(int x, int y, unsigned char c, char color, char bg, unsigned char size);
void setCursor(int x, int y);
void setTextColor(char c);
void setTextColor2(char c, char bg);
void setTextSize(unsigned char s);
void setTextWrap(char w);
void tft_write(unsigned char c);
void writeString(char* str);

void VGA_fillScreen(uint16_t color);

void dma_memset(void *dest, uint8_t val, size_t num);
void dma_memcpy(void *dest, void *src, size_t num);

void PrintChar(unsigned char c);
void Scroll (void);
void SetTxtCursor(int x, int y);
