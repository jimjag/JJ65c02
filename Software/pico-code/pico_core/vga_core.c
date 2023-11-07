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

#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
// Our assembled programs:
// pioasm converts foo.pio to foo.pio.h
#include "hsync.pio.h"
#include "scanline.pio.h"
#include "vsync.pio.h"
// Header file
#include "vga_core.h"
// Font file
#include "vga_fonts.c"

// Pixel color array that is DMAed to the PIO machines and
// a pointer to the ADDRESS of this color array.
// Note that this array is automatically initialized to all 0's (black)
unsigned char vga_data_array[TXCOUNT];
unsigned char *address_pointer = &vga_data_array[0];

static const unsigned char *font = font_sperry;

// DMA channel for dma_memcpy and dma_memset
int memcpy_dma_chan;

// Bit masks for drawPixel routine - RGBIRGBI
#define TOPMASK 0b00001111
#define BOTTOMMASK 0b11110000

// For drawLine
#define swap(a, b) do { int t = a; a = b; b = t; } while (false)

// For writing text
#define tabspace 4 // number of spaces for a tab

// For accessing the font library
#define pgm_read_byte(addr) (*(const unsigned char *)(addr))

// For drawing characters in Graphics Mode
int cursor_y, cursor_x, textsize;
char textcolor, textbgcolor, wrap;

// Terminal screen sizes (Terminal mode) - Assume 640x480 and 8x16 bitmaps
int max_tcurs_x = (SCREENWIDTH / FONTWIDTH) - 1;    // 80
int max_tcurs_y = (SCREENHEIGHT / FONTHEIGHT) - 1;  // 30
int tcurs_x = 0;
int tcurs_y = 0;
int textrow_size = FONTHEIGHT * (SCREENWIDTH / 2); // Amount of space taken by each row of text

void initVGA(void) {
    // Choose which PIO instance to use (there are two instances, each with 4 state
    // machines)
    PIO pio = pio0;

    // Our assembled program needs to be loaded into this PIO's instruction
    // memory. This SDK function will find a location (offset) in the
    // instruction memory where there is enough space for our program. We need
    // to remember these locations!
    //
    // We only have 32 instructions to spend! If the PIO programs contain more than
    // 32 instructions, then an error message will get thrown at these lines of code.
    //
    // The program name comes from the .program part of the pio file
    // and is of the form <program name_program>
    uint hsync_offset = pio_add_program(pio, &hsync_program);
    uint vsync_offset = pio_add_program(pio, &vsync_program);
    uint scanline_offset = pio_add_program(pio, &scanline_program);

    // Manually select a few state machines from pio instance pio.
    uint hsync_sm = pio_claim_unused_sm(pio, true);
    uint vsync_sm = pio_claim_unused_sm(pio, true);
    uint scanline_sm = pio_claim_unused_sm(pio, true);

    // Call the initialization functions that are defined within each PIO file.
    // Why not create these programs here? By putting the initialization function in
    // the pio file, then all information about how to use/setup that state machine
    // is consolidated in one place. Here in the C, we then just import and use it.
    hsync_program_init(pio, hsync_sm, hsync_offset, HSYNC, PIXFREQ);
    vsync_program_init(pio, vsync_sm, vsync_offset, VSYNC, PIXFREQ);
    scanline_program_init(pio, scanline_sm, scanline_offset, RED_PIN);

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // ============================== PIO DMA Channels
    // =================================================
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // DMA channels - 0 sends color data, 1 reconfigures and restarts 0
    int scanline_chan_0 = dma_claim_unused_channel(true);
    int scanline_chan_1 = dma_claim_unused_channel(true);

    // DMA channel for dma_memcpy and dma_memset
    memcpy_dma_chan = dma_claim_unused_channel(true);

    // Channel Zero (sends color data to PIO VGA machine)
    dma_channel_config c0 = dma_channel_get_default_config(scanline_chan_0);    // default configs
    channel_config_set_transfer_data_size(&c0, DMA_SIZE_8); // 8-bit txfers
    channel_config_set_read_increment(&c0, true);           // yes read incrementing
    channel_config_set_write_increment(&c0, false);         // no write incrementing
    channel_config_set_dreq(&c0, DREQ_PIO0_TX2);            // DREQ_PIO0_TX2 pacing (FIFO)
    channel_config_set_chain_to(&c0, scanline_chan_1);      // chain to other channel

    dma_channel_configure(scanline_chan_0,        // Channel to be configured
        &c0,                    // The configuration we just created
        &pio->txf[scanline_sm], // write address (SCANLINE PIO TX FIFO)
        &vga_data_array, // The initial read address (pixel color array)
        TXCOUNT, // Number of transfers; in this case each is 1 byte.
        false    // Don't start immediately.
    );

    // Channel One (reconfigures the first channel)
    dma_channel_config c1 = dma_channel_get_default_config(scanline_chan_1);     // default configs
    channel_config_set_transfer_data_size(&c1, DMA_SIZE_32); // 32-bit txfers
    channel_config_set_read_increment(&c1, false);           // no read incrementing
    channel_config_set_write_increment(&c1, false);          // no write incrementing
    channel_config_set_chain_to(&c1, scanline_chan_0);       // chain to other channel

    dma_channel_configure(scanline_chan_1,                        // Channel to be configured
        &c1,                                    // The configuration we just created
        &dma_hw->ch[scanline_chan_0].read_addr, // Write address (channel 0 read address)
        &address_pointer,                       // Read address (POINTER TO AN ADDRESS)
        1,    // Number of transfers, in this case each is 4 byte
        false // Don't start immediately.
    );

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // Initialize PIO state machine counters. This passes the information to the state
    // machines that they retrieve in the first 'pull' instructions, before the
    // .wrap_target directive in the assembly. Each uses these values to initialize some
    // counting registers.
    pio_sm_put_blocking(pio, hsync_sm, H_ACTIVE);
    pio_sm_put_blocking(pio, vsync_sm, V_ACTIVE);
    pio_sm_put_blocking(pio, scanline_sm, SCANLINE_ACTIVE);

    // Start the two pio machine IN SYNC
    // Note that the SCANLINE state machine is running at full speed,
    // so synchronization doesn't matter for that one. But, we'll
    // start them all simultaneously anyway.
    pio_enable_sm_mask_in_sync(pio, ((1u << hsync_sm) | (1u << vsync_sm) | (1u << scanline_sm)));

    // Start DMA channel 0. Once started, the contents of the pixel color array
    // will be constantly DMAed to the PIO machines that are driving the screen.
    // To change the contents of the screen, we need only change the contents
    // of that array.
    dma_start_channel_mask((1u << scanline_chan_0));
}

void dma_memset(void *dest, uint8_t val, size_t num) {
    dma_channel_config c = dma_channel_get_default_config(memcpy_dma_chan);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, true);

    dma_channel_configure(
        memcpy_dma_chan, // Channel to be configured
        &c,              // The configuration we just created
        dest,            // The initial write address
        &val,            // The initial read address
        num, // Number of transfers; in this case each is 1 byte.
        true // Start immediately.
    );

    // We could choose to go and do something else whilst the DMA is doing its
    // thing. In this case the processor has nothing else to do, so we just
    // wait for the DMA to finish.
    dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
}

void dma_memcpy(void *dest, void *src, size_t num) {
    dma_channel_config c = dma_channel_get_default_config(memcpy_dma_chan);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
    channel_config_set_read_increment(&c, true);
    channel_config_set_write_increment(&c, true);

    dma_channel_configure(
        memcpy_dma_chan, // Channel to be configured
        &c,              // The configuration we just created
        dest,            // The initial write address
        src,             // The initial read address
        num, // Number of transfers; in this case each is 1 byte.
        true // Start immediately.
    );

    // We could choose to go and do something else whilst the DMA is doing its
    // thing. In this case the processor has nothing else to do, so we just
    // wait for the DMA to finish.
    dma_channel_wait_for_finish_blocking(memcpy_dma_chan);
}

void VGA_fillScreen(uint16_t color) {
    dma_memset(vga_data_array, (color) | (color << 3), TXCOUNT);
}

// A function for drawing a pixel with a specified color.
// Note that because information is passed to the PIO state machines through
// a DMA channel, we only need to modify the contents of the array and the
// pixels will be automatically updated on the screen.
void drawPixel(int x, int y, char color) {
    // Range checks (640x480 display)
    if (x > (SCREENWIDTH - 1))
        x = (SCREENWIDTH - 1);
    if (x < 0)
        x = 0;
    if (y < 0)
        y = 0;
    if (y > (SCREENHEIGHT - 1))
        y = (SCREENHEIGHT - 1);
    // if((x > 639) | (x < 0) | (y > 479) | (y < 0) ) return;

    // Which pixel is it?
    int pixel = ((SCREENWIDTH * y) + x);

    // Is this pixel stored in the first 4 bits
    // of the vga data array index, or the second
    // 4 bits? Check, then mask.
    if (pixel & 1) {
        vga_data_array[pixel >> 1] = (vga_data_array[pixel >> 1] & TOPMASK) | (color << 4);
    } else {
        vga_data_array[pixel >> 1] = (vga_data_array[pixel >> 1] & BOTTOMMASK) | (color);
    }
}

void drawVLine(int x, int y, int h, char color) {
    for (int i = y; i < (y + h); i++) {
        drawPixel(x, i, color);
    }
}

void drawHLine(int x, int y, int w, char color) {
    for (int i = x; i < (x + w); i++) {
        drawPixel(i, y, color);
    }
}

// Bresenham's algorithm - thx wikipedia and thx Bruce!
void drawLine(int x0, int y0, int x1, int y1, char color) {
    /* Draw a straight line from (x0,y0) to (x1,y1) with given color
     * Parameters:
     *      x0: x-coordinate of starting point of line. The x-coordinate of
     *          the top-left of the screen is 0. It increases to the right.
     *      y0: y-coordinate of starting point of line. The y-coordinate of
     *          the top-left of the screen is 0. It increases to the bottom.
     *      x1: x-coordinate of ending point of line. The x-coordinate of
     *          the top-left of the screen is 0. It increases to the right.
     *      y1: y-coordinate of ending point of line. The y-coordinate of
     *          the top-left of the screen is 0. It increases to the bottom.
     *      color: 3-bit color value for line
     */
    int steep = abs(y1 - y0) > abs(x1 - x0);
    if (steep) {
        swap(x0, y0);
        swap(x1, y1);
    }

    if (x0 > x1) {
        swap(x0, x1);
        swap(y0, y1);
    }

    int dx, dy;
    dx = x1 - x0;
    dy = abs(y1 - y0);

    int err = dx / 2;
    int ystep;

    if (y0 < y1) {
        ystep = 1;
    } else {
        ystep = -1;
    }

    for (; x0 <= x1; x0++) {
        if (steep) {
            drawPixel(y0, x0, color);
        } else {
            drawPixel(x0, y0, color);
        }
        err -= dy;
        if (err < 0) {
            y0 += ystep;
            err += dx;
        }
    }
}

// Draw a rectangle
void drawRect(int x, int y, int w, int h, char color) {
    /* Draw a rectangle outline with top left vertex (x,y), width w
     * and height h at given color
     * Parameters:
     *      x:  x-coordinate of top-left vertex. The x-coordinate of
     *          the top-left of the screen is 0. It increases to the right.
     *      y:  y-coordinate of top-left vertex. The y-coordinate of
     *          the top-left of the screen is 0. It increases to the bottom.
     *      w:  width of the rectangle
     *      h:  height of the rectangle
     *      color:  4-bit color of the rectangle outline
     * Returns: Nothing
     */
    drawHLine(x, y, w, color);
    drawHLine(x, y + h - 1, w, color);
    drawVLine(x, y, h, color);
    drawVLine(x + w - 1, y, h, color);
}

static void drawCircleHelper(int x0, int y0, int r, unsigned char cornername, char color) {
    // Helper function for drawing circles and circular objects
    int f = 1 - r;
    int ddF_x = 1;
    int ddF_y = -2 * r;
    int x = 0;
    int y = r;

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;
        if (cornername & 0x4) {
            drawPixel(x0 + x, y0 + y, color);
            drawPixel(x0 + y, y0 + x, color);
        }
        if (cornername & 0x2) {
            drawPixel(x0 + x, y0 - y, color);
            drawPixel(x0 + y, y0 - x, color);
        }
        if (cornername & 0x8) {
            drawPixel(x0 - y, y0 + x, color);
            drawPixel(x0 - x, y0 + y, color);
        }
        if (cornername & 0x1) {
            drawPixel(x0 - y, y0 - x, color);
            drawPixel(x0 - x, y0 - y, color);
        }
    }
}

void drawCircle(int x0, int y0, int r, char color) {
    /* Draw a circle outline with center (x0,y0) and radius r, with given color
     * Parameters:
     *      x0: x-coordinate of center of circle. The top-left of the screen
     *          has x-coordinate 0 and increases to the right
     *      y0: y-coordinate of center of circle. The top-left of the screen
     *          has y-coordinate 0 and increases to the bottom
     *      r:  radius of circle
     *      color: 4-bit color value for the circle. Note that the circle
     *          isn't filled. So, this is the color of the outline of the circle
     * Returns: Nothing
     */
    int f = 1 - r;
    int ddF_x = 1;
    int ddF_y = -2 * r;
    int x = 0;
    int y = r;

    drawPixel(x0, y0 + r, color);
    drawPixel(x0, y0 - r, color);
    drawPixel(x0 + r, y0, color);
    drawPixel(x0 - r, y0, color);

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;

        drawPixel(x0 + x, y0 + y, color);
        drawPixel(x0 - x, y0 + y, color);
        drawPixel(x0 + x, y0 - y, color);
        drawPixel(x0 - x, y0 - y, color);
        drawPixel(x0 + y, y0 + x, color);
        drawPixel(x0 - y, y0 + x, color);
        drawPixel(x0 + y, y0 - x, color);
        drawPixel(x0 - y, y0 - x, color);
    }
}

static void fillCircleHelper(int x0, int y0, int r, unsigned char cornername, int delta,
                      char color) {
    // Helper function for drawing filled circles
    int f = 1 - r;
    int ddF_x = 1;
    int ddF_y = -2 * r;
    int x = 0;
    int y = r;

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;

        if (cornername & 0x1) {
            drawVLine(x0 + x, y0 - y, 2 * y + 1 + delta, color);
            drawVLine(x0 + y, y0 - x, 2 * x + 1 + delta, color);
        }
        if (cornername & 0x2) {
            drawVLine(x0 - x, y0 - y, 2 * y + 1 + delta, color);
            drawVLine(x0 - y, y0 - x, 2 * x + 1 + delta, color);
        }
    }
}

void fillCircle(int x0, int y0, int r, char color) {
    /* Draw a filled circle with center (x0,y0) and radius r, with given color
     * Parameters:
     *      x0: x-coordinate of center of circle. The top-left of the screen
     *          has x-coordinate 0 and increases to the right
     *      y0: y-coordinate of center of circle. The top-left of the screen
     *          has y-coordinate 0 and increases to the bottom
     *      r:  radius of circle
     *      color: 4-bit color value for the circle
     * Returns: Nothing
     */
    drawVLine(x0, y0 - r, 2 * r + 1, color);
    fillCircleHelper(x0, y0, r, 3, 0, color);
}

// Draw a rounded rectangle
void drawRoundRect(int x, int y, int w, int h, int r, char color) {
    /* Draw a rounded rectangle outline with top left vertex (x,y), width w,
     * height h and radius of curvature r at given color
     * Parameters:
     *      x:  x-coordinate of top-left vertex. The x-coordinate of
     *          the top-left of the screen is 0. It increases to the right.
     *      y:  y-coordinate of top-left vertex. The y-coordinate of
     *          the top-left of the screen is 0. It increases to the bottom.
     *      w:  width of the rectangle
     *      h:  height of the rectangle
     *      color:  4-bit color of the rectangle outline
     * Returns: Nothing
     */
    // smarter version
    drawHLine(x + r, y, w - 2 * r, color);         // Top
    drawHLine(x + r, y + h - 1, w - 2 * r, color); // Bottom
    drawVLine(x, y + r, h - 2 * r, color);         // Left
    drawVLine(x + w - 1, y + r, h - 2 * r, color); // Right
    // draw four corners
    drawCircleHelper(x + r, y + r, r, 1, color);
    drawCircleHelper(x + w - r - 1, y + r, r, 2, color);
    drawCircleHelper(x + w - r - 1, y + h - r - 1, r, 4, color);
    drawCircleHelper(x + r, y + h - r - 1, r, 8, color);
}

// Fill a rounded rectangle
void fillRoundRect(int x, int y, int w, int h, int r, char color) {
    // smarter version
    fillRect(x + r, y, w - 2 * r, h, color);

    // draw four corners
    fillCircleHelper(x + w - r - 1, y + r, r, 1, h - 2 * r - 1, color);
    fillCircleHelper(x + r, y + r, r, 2, h - 2 * r - 1, color);
}

// fill a rectangle
void fillRect(int x, int y, int w, int h, char color) {
    /* Draw a filled rectangle with starting top-left vertex (x,y),
     *  width w and height h with given color
     * Parameters:
     *      x:  x-coordinate of top-left vertex; top left of screen is x=0
     *              and x increases to the right
     *      y:  y-coordinate of top-left vertex; top left of screen is y=0
     *              and y increases to the bottom
     *      w:  width of rectangle
     *      h:  height of rectangle
     *      color:  4-bit color value
     * Returns:     Nothing
     */

    // rudimentary clipping (drawChar w/big text requires this)
    // if((x >= SCREENWIDTH) || (y >= SCREENHEIGHT)) return;
    // if((x + w - 1) >= SCREENWIDTH)  w = SCREENWIDTH  - x;
    // if((y + h - 1) >= SCREENHEIGHT) h = SCREENHEIGHT - y;

    // tft_setAddrWindow(x, y, x+w-1, y+h-1);

    for (int i = x; i < (x + w); i++) {
        for (int j = y; j < (y + h); j++) {
            drawPixel(i, j, color);
        }
    }
}

// Draw a character
void drawChar(int x, int y, unsigned char c, char color, char bg,
              unsigned char size) {
    char px, py;
    if ((x >= SCREENWIDTH) ||                     // Clip right
        (y >= SCREENHEIGHT) ||                    // Clip bottom
        ((x + FONTWIDTH * size - 1) < 0) || // Clip left
        ((y + FONTHEIGHT * size - 1) < 0))  // Clip top
        return;

    for (py = 0; py < FONTHEIGHT; py++) {
        unsigned char line;
        line = pgm_read_byte(font + (c * FONTHEIGHT) + py);
        for (px = 0; px < FONTWIDTH; px++) {
            if (line & 0x80) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, color);
                else { // big size
                    fillRect(x + (px * size), y + (py * size), size, size, color);
                }
            } else if (bg != color) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, bg);
                else { // big size
                    fillRect(x + px * size, y + py * size, size, size, bg);
                }
            }
            line <<= 1;
        }
    }
}

inline void setCursor(int x, int y) {
    /* Set cursor for text to be printed
     * Parameters:
     *      x = x-coordinate of top-left of text starting
     *      y = y-coordinate of top-left of text starting
     * Returns: Nothing
     */
    cursor_x = x;
    cursor_y = y;
}

inline void setTextSize(unsigned char s) {
    /*Set size of text to be displayed
     * Parameters:
     *      s = text size (1 being smallest)
     * Returns: nothing
     */
    textsize = (s > 0) ? s : 1;
}

inline void setTextColor(char c) {
    // For 'transparent' background, we'll set the bg
    // to the same as fg instead of using a flag
    textcolor = textbgcolor = c;
}

inline void setTextColor2(char c, char b) {
    /* Set color of text to be displayed
     * Parameters:
     *      c = 4-bit color of text
     *      b = 4-bit color of text background
     */
    textcolor = c;
    textbgcolor = b;
}

inline void setTextWrap(char w) { wrap = w; }

static void tft_write(unsigned char c) {
    if (c == '\n') {
        cursor_y += textsize * FONTHEIGHT;
        cursor_x = 0;
    } else if (c == '\r') {
        // skip em
    } else if (c == '\t') {
        int new_x = cursor_x + tabspace;
        if (new_x < SCREENWIDTH) {
            cursor_x = new_x;
        }
    } else {
        drawChar(cursor_x, cursor_y, c, textcolor, textbgcolor, textsize);
        cursor_x += textsize * FONTWIDTH;
        if (wrap && (cursor_x > (SCREENWIDTH - textsize * FONTWIDTH))) {
            cursor_y += textsize * FONTHEIGHT;
            cursor_x = 0;
        }
    }
}

inline void writeString(unsigned char *str) {
    /* Print text onto screen
     * Call tft_setCursor(), tft_setTextColor(), tft_setTextSize()
     *  as necessary before printing
     */
    while (*str) {
        tft_write(*str++);
    }
}

// Terminal Mode functions
//   Long term goal is vt52/vt100 emulation where we recv an
//   ASCII char and print it out if printable or else honor
//   the escape code. In this mode we map the bitmap screen
//   to a 80x30 terminal, with the current cursor indicated
//   by tcurs_x and tcurs_y (column and row)

void Scroll (void) {
    dma_memcpy(address_pointer, address_pointer + textrow_size, TXCOUNT - textrow_size);
    dma_memset(address_pointer + TXCOUNT - textrow_size, 0, textrow_size);
}

void setTxtCursor(int x, int y) {
    tcurs_x = x;
    if (tcurs_x > max_tcurs_x)
        tcurs_x = max_tcurs_x;
    tcurs_y = y;
    if (tcurs_y > max_tcurs_y)
        tcurs_y = max_tcurs_y;
}

void printChar(unsigned char c) {
    if (tcurs_x > max_tcurs_x) {
        // End of line
        tcurs_x = 0;
        tcurs_y++;
        if (tcurs_y > max_tcurs_y) {
            tcurs_y = max_tcurs_y;
            // scroll here
        }
    }
    if (c == '\n') {
        tcurs_y++;
        if (tcurs_y > max_tcurs_y) {
            tcurs_y = max_tcurs_y;
            // scroll
        }
        tcurs_x = 0;
    } else if (c == '\r') {
        // skip em
    } else if (c == '\t') {
        tcurs_x += tabspace;
        if (tcurs_x > max_tcurs_x) {
            // Scroll here? Wrap around?
            tcurs_x = max_tcurs_x;
        }
    } else {
        drawChar(tcurs_x * FONTWIDTH, tcurs_y * FONTHEIGHT, c, textcolor, textbgcolor, textsize);
        tcurs_x++;
    }
}

inline void printString(unsigned char *str) {
    while (*str) {
        printChar(*str++);
    }
}
