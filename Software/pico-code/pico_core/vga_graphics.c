/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
// Core VGA Graphics functions
//
// Pixel storage convention — IMPORTANT, easy to get wrong:
//   - Two 4-bit pixels are packed per byte in vga_data_array[].
//   - Pixel index P = (SCREENWIDTH * y) + x. Byte index = P >> 1.
//   - Even-indexed pixel (P & 1 == 0) -> LOW  nibble of the byte.
//     Update via (byte & HIGH_NIBBLE_MASK 0xF0) | color
//   - Odd-indexed pixel  (P & 1 == 1) -> HIGH nibble of the byte.
//     Update via (byte & LOW_NIBBLE_MASK 0x0F) | (color << 4)
//   - LOW_NIBBLE_MASK keeps the low nibble (clears high so we can write it);
//     HIGH_NIBBLE_MASK keeps the high nibble. The PIO scanout emits the LOW
//     nibble first, then the HIGH nibble.
//   - Because SCREENWIDTH (640) is even, (P & 1) == (x & 1). Some code
//     paths (drawVLine) rely on this — revisit if SCREENWIDTH changes.
//   - dma_memset writes one constant byte; to fill a run of same-color
//     pixels use byte = (color & 0x0F) | ((color & 0x0F) << 4).

void vgaFillScreen(unsigned char color) {
    color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    dma_memset(vga_data_array[db_draw], (color) | (color << 4), txcount, true);
}

// Caller must guarantee 0 <= x < SCREENWIDTH, 0 <= y < SCREENHEIGHT,
// and color != TRANSPARENT_INT. No range or transparency checks.
static inline void drawPixelFast(int x, int y, unsigned char color) {
    int pixel = SCREENWIDTH * y + x;
    unsigned char *cell = &vga_data_array[db_draw][pixel >> 1];
    if (pixel & 1) {
        *cell = (*cell & LOW_NIBBLE_MASK) | (color << 4);
    } else {
        *cell = (*cell & HIGH_NIBBLE_MASK) | color;
    }
}

// A function for drawing a pixel with a specified color.
// Note that because information is passed to the PIO state machines through
// a DMA channel, we only need to modify the contents of the array and the
// pixels will be automatically updated on the screen.
void drawPixel(int x, int y, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    // Range checks (640x480 display)
    if ( (x > (SCREENWIDTH - 1)) ||
        (x < 0) ||
        (y < 0) ||
        (y > (SCREENHEIGHT - 1)) ) {
        return;
    }

    // Which pixel is it?
    int pixel = ((SCREENWIDTH * y) + x);

    // Is this pixel stored in the first 4 bits
    // of the vga data array index, or the second
    // 4 bits? Check, then mask.
    if (pixel & 1) {
        vga_data_array[db_draw][pixel >> 1] = (vga_data_array[db_draw][pixel >> 1] & LOW_NIBBLE_MASK) | (color << 4);
    } else {
        vga_data_array[db_draw][pixel >> 1] = (vga_data_array[db_draw][pixel >> 1] & HIGH_NIBBLE_MASK) | (color);
    }
}

void drawVLine(int x, int y, int h, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    if (x < 0 || x >= SCREENWIDTH) return;
    if (y < 0) { h += y; y = 0; }
    if (y + h > SCREENHEIGHT) h = SCREENHEIGHT - y;
    if (h <= 0) return;
    unsigned char *buf = vga_data_array[db_draw];
    int byte = (SCREENWIDTH * y + x) >> 1;
    if (x & 1) {
        for (int i = 0; i < h; i++, byte += scanline_size)
            buf[byte] = (buf[byte] & LOW_NIBBLE_MASK) | (color << 4);
    } else {
        for (int i = 0; i < h; i++, byte += scanline_size)
            buf[byte] = (buf[byte] & HIGH_NIBBLE_MASK) | color;
    }
}

void drawHLine(int x, int y, int w, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    if (y < 0 || y >= SCREENHEIGHT) return;
    if (x < 0) { w += x; x = 0; }
    if (x + w > SCREENWIDTH) w = SCREENWIDTH - x;
    if (w <= 0) return;
    unsigned char *buf = vga_data_array[db_draw];
    int pixel = SCREENWIDTH * y + x;
    // Leading odd pixel: writes high nibble
    if (pixel & 1) {
        buf[pixel >> 1] = (buf[pixel >> 1] & LOW_NIBBLE_MASK) | (color << 4);
        pixel++;
        w--;
    }
    // Aligned middle: pack two pixels per byte and DMA-fill
    int middle = w >> 1;
    if (middle > 0) {
        dma_memset(&buf[pixel >> 1], color | (color << 4), middle, true);
        pixel += middle * 2;
        w -= middle * 2;
    }
    // Trailing pixel: writes low nibble
    if (w == 1) {
        buf[pixel >> 1] = (buf[pixel >> 1] & HIGH_NIBBLE_MASK) | color;
    }
}

// Bresenham's algorithm - thx wikipedia and thx Bruce!
void drawLine(int x0, int y0, int x1, int y1, unsigned char color, bool colorIsRGB332) {
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
     *      color: 4-bit color value for line
     */
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
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
            drawPixel(y0, x0, color, false);
        } else {
            drawPixel(x0, y0, color, false);
        }
        err -= dy;
        if (err < 0) {
            y0 += ystep;
            err += dx;
        }
    }
}

// Draw a rectangle
void drawRect(int x, int y, int w, int h, unsigned char color, bool colorIsRGB332) {
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
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawHLine(x, y, w, color, false);
    drawHLine(x, y + h - 1, w, color, false);
    drawVLine(x, y, h, color, false);
    drawVLine(x + w - 1, y, h, color, false);
}

static void drawCircleHelper(int x0, int y0, int r, unsigned char cornername, unsigned char color) {
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
            drawPixel(x0 + x, y0 + y, color, false);
            drawPixel(x0 + y, y0 + x, color, false);
        }
        if (cornername & 0x2) {
            drawPixel(x0 + x, y0 - y, color, false);
            drawPixel(x0 + y, y0 - x, color, false);
        }
        if (cornername & 0x8) {
            drawPixel(x0 - y, y0 + x, color, false);
            drawPixel(x0 - x, y0 + y, color, false);
        }
        if (cornername & 0x1) {
            drawPixel(x0 - y, y0 - x, color, false);
            drawPixel(x0 - x, y0 - y, color, false);
        }
    }
}

void drawCircle(int x0, int y0, int r, unsigned char color, bool colorIsRGB332) {
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
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    int f = 1 - r;
    int ddF_x = 1;
    int ddF_y = -2 * r;
    int x = 0;
    int y = r;

    bool inside = (r >= 0) && (x0 - r >= 0) && (x0 + r < SCREENWIDTH) &&
                  (y0 - r >= 0) && (y0 + r < SCREENHEIGHT);
    if (inside) {
        drawPixelFast(x0, y0 + r, color);
        drawPixelFast(x0, y0 - r, color);
        drawPixelFast(x0 + r, y0, color);
        drawPixelFast(x0 - r, y0, color);
        while (x < y) {
            if (f >= 0) { y--; ddF_y += 2; f += ddF_y; }
            x++; ddF_x += 2; f += ddF_x;
            drawPixelFast(x0 + x, y0 + y, color);
            drawPixelFast(x0 - x, y0 + y, color);
            drawPixelFast(x0 + x, y0 - y, color);
            drawPixelFast(x0 - x, y0 - y, color);
            drawPixelFast(x0 + y, y0 + x, color);
            drawPixelFast(x0 - y, y0 + x, color);
            drawPixelFast(x0 + y, y0 - x, color);
            drawPixelFast(x0 - y, y0 - x, color);
        }
        return;
    }

    drawPixel(x0, y0 + r, color, false);
    drawPixel(x0, y0 - r, color, false);
    drawPixel(x0 + r, y0, color, false);
    drawPixel(x0 - r, y0, color, false);

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;

        drawPixel(x0 + x, y0 + y, color, false);
        drawPixel(x0 - x, y0 + y, color, false);
        drawPixel(x0 + x, y0 - y, color, false);
        drawPixel(x0 - x, y0 - y, color, false);
        drawPixel(x0 + y, y0 + x, color, false);
        drawPixel(x0 - y, y0 + x, color, false);
        drawPixel(x0 + y, y0 - x, color, false);
        drawPixel(x0 - y, y0 - x, color, false);
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
            drawVLine(x0 + x, y0 - y, 2 * y + 1 + delta, color, false);
            drawVLine(x0 + y, y0 - x, 2 * x + 1 + delta, color, false);
        }
        if (cornername & 0x2) {
            drawVLine(x0 - x, y0 - y, 2 * y + 1 + delta, color, false);
            drawVLine(x0 - y, y0 - x, 2 * x + 1 + delta, color, false);
        }
    }
}

void drawFilledCircle(int x0, int y0, int r, unsigned char color, bool colorIsRGB332) {
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
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawVLine(x0, y0 - r, 2 * r + 1, color, false);
    fillCircleHelper(x0, y0, r, 3, 0, color);
}

// Draw a rounded rectangle
void drawRoundRect(int x, int y, int w, int h, int r, unsigned char color, bool colorIsRGB332) {
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
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawHLine(x + r, y, w - 2 * r, color, false);         // Top
    drawHLine(x + r, y + h - 1, w - 2 * r, color, false); // Bottom
    drawVLine(x, y + r, h - 2 * r, color, false);         // Left
    drawVLine(x + w - 1, y + r, h - 2 * r, color, false); // Right
    // draw four corners
    drawCircleHelper(x + r, y + r, r, 1, color);
    drawCircleHelper(x + w - r - 1, y + r, r, 2, color);
    drawCircleHelper(x + w - r - 1, y + h - r - 1, r, 4, color);
    drawCircleHelper(x + r, y + h - r - 1, r, 8, color);
}

// Fill a rounded rectangle
void drawFilledRoundRect(int x, int y, int w, int h, int r, unsigned char color, bool colorIsRGB332) {
    // smarter version
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawFilledRect(x + r, y, w - 2 * r, h, color, false);

    // draw four corners
    fillCircleHelper(x + w - r - 1, y + r, r, 1, h - 2 * r - 1, color);
    fillCircleHelper(x + r, y + r, r, 2, h - 2 * r - 1, color);
}

// fill a rectangle
void drawFilledRect(int x, int y, int w, int h, unsigned char color, bool isColorRGB332) {
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
    if (isColorRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    for (int j = y; j < (y + h); j++) {
        drawHLine(x, j, w, color, false);
    }
}

// Draw a character
void drawChar(int x, int y, unsigned char chrx, unsigned char color, char bg,
              unsigned char size, bool colorIsRGB332) {
    char px, py;
    if ((x >= SCREENWIDTH) ||                     // Clip right
        (y >= SCREENHEIGHT) ||                    // Clip bottom
        ((x + FONTWIDTH * size - 1) < 0) || // Clip left
        ((y + FONTHEIGHT * size - 1) < 0))  // Clip top
        return;
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    for (py = 0; py < FONTHEIGHT; py++) {
        unsigned char line;
        line = pgm_read_byte(font + (chrx * FONTHEIGHT) + py);
        for (px = 0; px < FONTWIDTH; px++) {
            if (line & 0x80) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, color, false);
                else { // big size
                    drawFilledRect(x + (px * size), y + (py * size), size, size, color, false);
                }
            } else if (bg != color) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, bg, false);
                else { // big size
                    drawFilledRect(x + px * size, y + py * size, size, size, bg, false);
                }
            }
            line <<= 1;
        }
    }
}

inline void setCursor(int x, int y) {
    /* Set cursor for graphics text to be printed
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

// Convert RGB332 value to our internal value, used to set the VGA pins
unsigned char convertRGB332(unsigned char color) {
    unsigned char c;
    switch (color) {
        //  RGB332             Our Internal Value         Regular RGB
        case BLACK:         c = BLACK_INT; break;         // 0x000000
        case RED:           c = RED_INT; break;           // 0xc00000
        case GREEN:         c = GREEN_INT; break;         // 0x00c000
        case YELLOW:        c = YELLOW_INT; break;        // 0xc0c000
        case BLUE:          c = BLUE_INT; break;          // 0x0000c0
        case MAGENTA:       c = MAGENTA_INT; break;       // 0xc000c0
        case CYAN:          c = CYAN_INT; break;          // 0x00c0c0
        case LIGHT_GREY:    c = LIGHT_GREY_INT; break;    // 0xc0c0c0
        case GREY:          c = GREY_INT; break;          // 0x808080
        case LIGHT_RED:     c = LIGHT_RED_INT; break;     // 0xff0000
        case LIGHT_GREEN:   c = LIGHT_GREEN_INT; break;   // 0x00ff00
        case LIGHT_YELLOW:  c = LIGHT_YELLOW_INT; break;  // 0xffff00
        case LIGHT_BLUE:    c = LIGHT_BLUE_INT; break;    // 0x0080ff
        case LIGHT_MAGENTA: c = LIGHT_MAGENTA_INT; break; // 0xff00ff
        case LIGHT_CYAN:    c = LIGHT_CYAN_INT; break;    // 0x00ffff
        case WHITE:         c = WHITE_INT; break;         // 0xffffff
        default:            c = TRANSPARENT_INT; break;   // 0xffc0cb, 0xfb, et.al.
    }
    return c;
}

void setTextColor(char c) {
    // For 'transparent' background, we'll set the bg
    // to the same as fg instead of using a flag
    textfgcolor = convertRGB332(c);
}

void setTextColor2(char c, char b) {
    /* Set color of text to be displayed
     * Parameters:
     *      c = 4-bit color of text
     *      b = 4-bit color of text background
     */
    textfgcolor = convertRGB332(c);
    textbgcolor = convertRGB332(b);
}

void setFont(char n) {
    switch (n) {
        case 4:
            font = font_verite;
            txtfont = 4;
            break;
        case 3:
            font = font_sperry;
            txtfont = 3;
            break;
        case 2:
            font = font_toshiba;
            txtfont = 2;
            break;
        case 1:
            font = font_acm;
            txtfont = 1;
            break;
        default:
            font = font_sweet16;
            txtfont = 0;
            break;
    }
}

static void tft_write(unsigned char chrx) {
    if (chrx == '\n') {
        cursor_y += textsize * FONTHEIGHT;
        cursor_x = 0;
    } else if (chrx == '\r') {
        // skip em
    } else if (chrx == '\t') {
        int new_x = cursor_x + tabspace;
        if (new_x < SCREENWIDTH) {
            cursor_x = new_x;
        }
    } else {
        drawChar(cursor_x, cursor_y, chrx, textfgcolor, textbgcolor, textsize, false);
        cursor_x += textsize * FONTWIDTH;
        if (wrap && (cursor_x > (SCREENWIDTH - textsize * FONTWIDTH))) {
            cursor_y += textsize * FONTHEIGHT;
            cursor_x = 0;
        }
    }
}

inline void drawString(unsigned char *str) {
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
//   by tcurs.x and tcurs.y (column and row)
//
//   NOTE: Here we use 0,0 as the 1st element (ie: zero indexed)
//         but externally we use one-indexed (ie, 1,1)


void setTextWrap(bool w) { wrap = w; }

void setCr2Crlf(bool w) { cr2crlf = w; }

void setLf2Crlf(bool w) { lf2crlf = w; }

void enableSmoothScroll(bool flag) { smooth_scroll = flag; }

void vgaScrollLeft (int pixels) {
    if (pixels <= 0 || pixels >= SCREENWIDTH - 1) return;
    int scanlines = SCREENHEIGHT;
    int xfer = (SCREENWIDTH - pixels) >> 1;
    int maxxfer = (SCREENWIDTH - 1) >> 1;
    for (int y = 0; y < scanlines; y++) {
        int pixel = (y * SCREENWIDTH + pixels) >> 1;
        int col0 = (y * SCREENWIDTH) >> 1;
        if (!smooth_scroll) { // At standard speeds, the difference is hardly noticeable
            dma_memcpy(&vga_data_array[db_draw][col0], &vga_data_array[db_draw][pixel], xfer, true);
        } else {
            int counter = pixel - col0;
            for (int i = 0; i < counter; i++) {
                dma_memcpy(&vga_data_array[db_draw][col0], &vga_data_array[db_draw][col0+1], maxxfer, true);
            }
        }
    }
}

void vgaScrollUp (int scanlines) {
    if (scanlines <= 0) scanlines = FONTHEIGHT;
    if (scanlines >= SCREENHEIGHT) scanlines = SCREENHEIGHT - 1;
    if (!smooth_scroll) {
        int bytes = scanlines * scanline_size;
        dma_memcpy(vga_data_array[db_draw], vga_data_array[db_draw] + bytes, txcount - bytes, true);
        dma_memset(vga_data_array[db_draw] + txcount - bytes, (textbgcolor) | (textbgcolor << 4), bytes, true);
    } else {
        for (int i = 0; i < scanlines; i++) {
            dma_memcpy(vga_data_array[db_draw], vga_data_array[db_draw] + scanline_size, txcount - scanline_size, true);
            dma_memset(vga_data_array[db_draw] + txcount - scanline_size, (textbgcolor) | (textbgcolor << 4), scanline_size, true);
        }
    }
}

void termScrollUp (int rows) {
    bool was = enableCurs(false);
    int orows = rows;
    if (rows <= 0) rows = 1;
    if (rows > maxTcurs.y) rows = maxTcurs.y;
    rows *= textrow_size;
    dma_memcpy(terminal, terminal + rows, terminal_size - rows, true);
    dma_memset(terminal + terminal_size - rows, ' ', rows, true);
    vgaScrollUp(orows * FONTHEIGHT);
    enableCurs(was);
}

static void checkCursor(void) {
    if (tcurs.x > maxTcurs.x)
        tcurs.x = maxTcurs.x;
    else if (tcurs.x < 0)
        tcurs.x = 0;

    if (tcurs.y > maxTcurs.y)
        tcurs.y = maxTcurs.y;
    else if (tcurs.y < 0)
        tcurs.y = 0;
}

void setTxtCursor(int x, int y) {
    bool was = enableCurs(false);
    tcurs.x = x;
    tcurs.y = y;
    checkCursor();
    enableCurs(was);
}

// Print the raw character byte (as-is, as rec'd) to the screen and terminal
void writeChar(unsigned char chrx) {
    bool was = enableCurs(false);
    int idx = tcurs.x + (tcurs.y * textrow_size);
    terminal[idx] = chrx;
    drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, chrx, textfgcolor, textbgcolor, textsize, false);
    tcurs.x++;
    if (tcurs.x > maxTcurs.x) {
        // End of line
        tcurs.x = 0;
        tcurs.y++;
        if (tcurs.y > maxTcurs.y) {
            tcurs.y = maxTcurs.y;
            termScrollUp(1);
        }
    }
    enableCurs(was);
}

// Print the text character provided, handling special chars
static void printChar(unsigned char chrx) {
    char x,y;
    switch (chrx) {
        // Handle "special" characters.
        case '\n':
            tcurs.y++;
            if (tcurs.y > maxTcurs.y) {
                tcurs.y = maxTcurs.y;
                termScrollUp(1);
            }
            if (cr2crlf) {
                tcurs.x = 0;
            }
            break;
        case '\r':
            tcurs.x = 0;
            if (lf2crlf) {
                tcurs.y++;
                if (tcurs.y > maxTcurs.y) {
                    tcurs.y = maxTcurs.y;
                    termScrollUp(1);
                }
            }
            break;
        case '\t':
            tcurs.x += tabspace;
            if (tcurs.x > maxTcurs.x) {
                // vgaScroll here? Wrap around?
                tcurs.x = maxTcurs.x;
            }
            break;
        case '\b':   // Backspace and Delete
            tcurs.x--;
            if (tcurs.x < 0) {
                // If we hit the left edge, we need to go up a row
                tcurs.y--;
                if (tcurs.y < 0) tcurs.y = 0; // We hit the top!
                tcurs.x = maxTcurs.x;
            }
            // Store where we are
            x = tcurs.x;
            y = tcurs.y;
            writeChar(' ');
            setTxtCursor(x,y);
            break;
            // These 4 cases are special to us
        case 0x11:  // Up Arrow, aka Esc[A
            tcurs.y--;
            checkCursor();
            break;
        case 0x12:  // Down Arrow, aka Esc[B
            tcurs.y++;
            checkCursor();
            break;
        case 0x13:  // Right Arrow, aka Esc[C
            tcurs.x++;
            checkCursor();
            break;
        case 0x14:  // Left Arrow, aka Esc[D
            tcurs.x--;
            checkCursor();
            break;
        case '\a':
            beep();
            break;
        default:
            writeChar(chrx);
            break;
    }
}

void clearScreen(void) {
    dma_memset(vga_data_array[db_draw], (textbgcolor) | (textbgcolor << 4), txcount, true);
    dma_memset(terminal, ' ', terminal_size, true);
}


void printString(char *str) {
    while (*str) {
        handleByte(*str++);
    }
}

// Handle ESC sequences
#include "escape_seq.c"

// Interpret the byte and check for Esc sequences. We use
// this for input from the 6502 or elsewhere that may
// be terminal related. If we want/need to print the
// char as-is, use writeChar()
void handleByte(unsigned char chrx) {
    bool was = enableCurs(false);
    if (esc_state == ESC_READY) {
        if (chrx == ESC) {
            esc_state = MAYBE_ESC_SEQ;
        } else {
            printChar(chrx);
        }
    } else {
        switch(esc_state) {
            case MAYBE_ESC_SEQ:
                // waiting on c1 character
                if ((chrx >= 'N') && (chrx < '_')) {
                    if(chrx=='[') {
                        esc_c1 = chrx;
                        esc_state = ESC_COLLECT;
                        clear_escape_parameters();
                    }
                    else {
                        // punt
                        reset_escape_sequence();
                        printChar(chrx);
                    }
                }
                else {
                    // unrecognised character after escape.
                    reset_escape_sequence();
                    printChar(chrx);
                }
                break;
            case ESC_COLLECT:
                if (!collect_sequence(chrx)) {
                    // Weird ending char
                    reset_escape_sequence();
                    printChar(chrx);
                }
                break;
            default:
                reset_escape_sequence();
                printChar(chrx);
                break;
        }
    }
    enableCurs(was);
}

/*
 * The Sprite code seems complicated at first, but this is mostly
 * due to the RP2040 being a little endian machine. What does this
 * mean? Say we want to display the following hex code:
 *     0x0f020500   (White Pixel, Green Pixel, Magenta Pixel, Black Pixel)
 * Because we store the bitmaps in integer based variables, these are
 * stored *in memory* as:
 *     0x00 0x05 0x02 0x0f
 * that is, the address of the variable points to the least significant
 * byte. So even though it looks like we may want to shift the bitmap
 * to the right, to add space to the left of the image, we actually
 * need to shift left (and vice versa).
 *
 * So why not use char[] instead? Because we need to do bitwise operations
 * for masking, and one can only do that on integer based values. Moving
 * to a char[] would be looping through each byte of the array and
 * doing the bitwise ops on the unsigned char/uint8_t type and those
 * loops can be expensive.
 *
 * And YES, things would be much easier if the RP2040 SDK supported 128bit
 * values directly.
 */
sprite_t *sprites[MAXSPRITES];

// Draw-order list: sprites are drawn in draw_order[0..draw_order_count-1].
// Earlier indices are "below" later indices.
static int draw_order[MAXSPRITES];
static int draw_order_count = 0;

static inline bool sprites_overlap(int a, int b) {
    if (!sprites[a] || !sprites[b]) return false;
    if (!sprites[a]->bgValid || !sprites[b]->bgValid) return false;
    return !(sprites[a]->x + sprites[a]->width  <= sprites[b]->x ||
             sprites[b]->x + sprites[b]->width  <= sprites[a]->x ||
             sprites[a]->y + sprites[a]->height <= sprites[b]->y ||
             sprites[b]->y + sprites[b]->height <= sprites[a]->y);
}

static int draw_order_find(int sn) {
    for (int i = 0; i < draw_order_count; i++)
        if (draw_order[i] == sn) return i;
    return -1;
}

static void draw_order_remove(int sn) {
    int idx = draw_order_find(sn);
    if (idx < 0) return;
    for (int i = idx; i < draw_order_count - 1; i++)
        draw_order[i] = draw_order[i + 1];
    draw_order_count--;
}

static void draw_order_append(int sn) {
    if (draw_order_find(sn) >= 0) return;
    if (draw_order_count < MAXSPRITES)
        draw_order[draw_order_count++] = sn;
}

void loadSprite(uint sn, short width, short height, unsigned char *sdata) {
    if (sn >= MAXSPRITES)
        return;
    if (sprites[sn])    // already exists
        return;
    if (width != SPRITE32_WIDTH) width = SPRITE16_WIDTH;
    sprite_t *n = calloc(1, sizeof(sprite_t));
    if (!n) return;
    bool needFree = false;
    if (!sdata) {
        int chunk = width * height;
        sdata = malloc(chunk);
        if (!sdata) { free(n); return; }
        for (int i = 0; i < chunk;) {
            unsigned char cx;
            if (!getByte(&cx))
                continue;
            sdata[i++] = cx;
        }
        needFree = true;
    }
    // NOW CREATE bitmap, invmask, etc... for this sprite
    // (which was designed to be at an even X-coordinate)
    // and its odd X-coord twin.
    //
    // invmask: opaque nibble = 0xF, transparent nibble = 0x0
    // opaque[k][oe]: bit i = 1 if row i is fully opaque (no transparency)
    //
    n->bitmap[0][0] = malloc(sizeof(uint64_t) * height);
    n->bitmap[0][1] = malloc(sizeof(uint64_t) * height);
    n->invmask[0][0] = malloc(sizeof(uint64_t) * height);
    n->invmask[0][1] = malloc(sizeof(uint64_t) * height);
    n->bgrnd[0] = malloc(sizeof(uint64_t) * height);
    if (width == SPRITE32_WIDTH) {
        n->bitmap[1][0] = malloc(sizeof(uint64_t) * height);
        n->bitmap[1][1] = malloc(sizeof(uint64_t) * height);
        n->invmask[1][0] = malloc(sizeof(uint64_t) * height);
        n->invmask[1][1] = malloc(sizeof(uint64_t) * height);
        n->bgrnd[1] = malloc(sizeof(uint64_t) * height);
    }
    if (!n->bitmap[0][0] || !n->bitmap[0][1] ||
        !n->invmask[0][0] || !n->invmask[0][1] || !n->bgrnd[0] ||
        (width == SPRITE32_WIDTH &&
         (!n->bitmap[1][0] || !n->bitmap[1][1] ||
          !n->invmask[1][0] || !n->invmask[1][1] || !n->bgrnd[1]))) {
        free(n->bitmap[0][0]); free(n->bitmap[0][1]);
        free(n->invmask[0][0]); free(n->invmask[0][1]);
        free(n->bgrnd[0]);
        free(n->bitmap[1][0]); free(n->bitmap[1][1]);
        free(n->invmask[1][0]); free(n->invmask[1][1]);
        free(n->bgrnd[1]);
        if (needFree) free(sdata);
        free(n);
        return;
    }
    int chunks = width / SPRITE16_WIDTH;
    for (int i = 0; i < height; i++) {
        for (int k = 0; k < chunks; k++) {
            uint64_t invmask = 0;
            uint64_t bitmap = 0;
            unsigned char cx;
            for (int j = SPRITE16_WIDTH - 1; j >= 0; j--) {
                invmask <<= 4;
                bitmap <<= 4;
                cx = sdata[j + (i * width) + (k * SPRITE16_WIDTH)];  // Read in the RGB332 value
                cx = convertRGB332(cx);                           // And convert it
                if (cx != TRANSPARENT_INT) {
                    invmask |= LOW_NIBBLE_MASK;
                    bitmap |= (LOW_NIBBLE_MASK & cx);
                }
            }
            n->bitmap[k][0][i] = bitmap;
            n->invmask[k][0][i] = invmask;
            // For opaque row detection, all nibbles must be 0xF
            if (invmask == UINT64_MAX && i < 64)
                n->opaque[k][0] |= ((uint64_t)1 << i);
        }
        // We now generate, and store, the image shifted right by 1 pixel, for
        // when the image starts at an odd X-coord. Why? We store 2 pixels
        // per byte, so we need to straddle odd x-coords.
        //
        // NOTE: We could remove all this complication if we are OK with
        //       restricting Sprites and Tiles to even X-coords.
        //       Alternatively, we could go with 1 pixel per byte
        //       which would balloon the size of the bitmap display
        //       memory allocation. Trade-offs.
        //
        // Generate the odd-x variant by shifting right by 1 pixel.
        // The rightmost pixel (MSN of highest chunk) is shifted out;
        // force it to transparent in the odd variant so no visible
        // pixel is lost. We do NOT mutate the even-x base data.
        if (width == SPRITE32_WIDTH) {
            uint64_t carry;
            uint64_t bm1 = (n->bitmap[1][0][i] & ~MSN64); // clear rightmost pixel
            uint64_t im1 = (n->invmask[1][0][i] & ~MSN64); // mark it transparent (clear invmask MSN)
            carry = (n->bitmap[0][0][i] & MSN64) >> 60; // "top" 4 bits of unshifted bitmap[0]; this is what will be shifted out
            n->bitmap[1][1][i] = (bm1 << 4) | carry; // now shift bitmap[1] and fold in bitmap[0] shifted out 4 bits
            carry = (n->invmask[0][0][i] & MSN64) >> 60; // "top" 4 bits of unshifted invmask[0]
            n->invmask[1][1][i] = (im1 << 4) | carry;
            if (n->invmask[1][1][i] == UINT64_MAX && i < 64)
                n->opaque[1][1] |= ((uint64_t)1 << i);
        }
        // For chunk[0], clear the rightmost pixel before shifting so it
        // is guaranteed transparent when shifted out (16-wide) or into
        // the carry position (32-wide, already handled above).
        uint64_t bm0 = (n->bitmap[0][0][i] & ~MSN64);
        uint64_t im0 = (n->invmask[0][0][i] & ~MSN64);
        n->bitmap[0][1][i] = (bm0 << 4);       // low nibble = 0 (transparent)
        n->invmask[0][1][i] = (im0 << 4);      // low nibble = 0 (transparent in invmask)
        if (n->invmask[0][1][i] == UINT64_MAX && i < 64)
            n->opaque[0][1] |= ((uint64_t)1 << i);
    }
    n->bgValid = false;
    n->height = height;
    n->width = width;
    sprites[sn] = n;
    if (needFree) free(sdata);
}

void eraseSprite(uint sn) {
    if (sn >= MAXSPRITES || !sprites[sn]) return;
    // Restore background (original screen)
    if (!sprites[sn]->bgValid)
        return;
    int yend = sprites[sn]->y + sprites[sn]->height;
    int j = 0;
    int chunks = sprites[sn]->width / SPRITE16_WIDTH;
    for (int y1 = sprites[sn]->y; y1 < yend; y1++, j++) {
        if (y1 < 0 || y1 >= SCREENHEIGHT) continue;
        for (int k = 0; k < chunks; k++) {
            int pixel = ((SCREENWIDTH * y1) + sprites[sn]->x + (k * SPRITE16_WIDTH));
            memcpy(&vga_data_array[db_draw][pixel >> 1], &sprites[sn]->bgrnd[k][j], 8);
        }
    }
    sprites[sn]->bgValid = false;
}

void drawSprite(uint sn, short x, short y, bool erase) {
    if (sn >= MAXSPRITES || !sprites[sn]) return;
    if (erase) eraseSprite(sn);
    if (x <= -sprites[sn]->width || x >= SCREENWIDTH || y >= SCREENHEIGHT || y <= -sprites[sn]->height) {
        sprites[sn]->x = x;
        sprites[sn]->y = y;
        return;
    }
    uint64_t newScreen;
    uint64_t bgrnd, invmask[2], bitmap[2];
    int yend = y + sprites[sn]->height;
    int shifts = 0;
    bool shift_right = true;
    int maxx = SCREENWIDTH - sprites[sn]->width;
    int chunks = sprites[sn]->width / SPRITE16_WIDTH;
    // Handle moving off screen left or right
    if (x > maxx) {
        shifts = x - maxx;
        x = maxx;
    } else if (x < 0) {
        shifts = -x;
        x = 0;
        shift_right = false;
    }
    int oddeven = x & 0x1;
    int j = 0;
    for (int y1 = y; y1 < yend; y1++, j++) {
        if (y1 < 0 || y1 >= SCREENHEIGHT) continue;
        invmask[0] = sprites[sn]->invmask[0][oddeven][j];
        bitmap[0] = sprites[sn]->bitmap[0][oddeven][j];
        if (sprites[sn]->width == SPRITE32_WIDTH) {
            invmask[1] = sprites[sn]->invmask[1][oddeven][j];
            bitmap[1] = sprites[sn]->bitmap[1][oddeven][j];
        }
        // Shift invmask and bitmap when sprite overlaps screen edge.
        // For invmask, shifted-in nibbles are 0x0 (transparent).
        if (shifts > 0) {
            int shift_bits = shifts * 4;
            if (shift_right) {
                if (sprites[sn]->width == SPRITE32_WIDTH && shift_bits >= 64) {
                    int sb = shift_bits - 64;
                    bitmap[1] = sb ? (bitmap[0] << sb) : bitmap[0];
                    invmask[1] = sb ? (invmask[0] << sb) : invmask[0];
                    bitmap[0] = 0;
                    invmask[0] = 0;
                } else if (sprites[sn]->width == SPRITE32_WIDTH) {
                    bitmap[1] = (bitmap[1] << shift_bits) | (bitmap[0] >> (64 - shift_bits));
                    invmask[1] = (invmask[1] << shift_bits) | (invmask[0] >> (64 - shift_bits));
                    bitmap[0] = (bitmap[0] << shift_bits);
                    invmask[0] = (invmask[0] << shift_bits);
                } else {
                    bitmap[0] = (bitmap[0] << shift_bits);
                    invmask[0] = (invmask[0] << shift_bits);
                }
            } else {
                if (sprites[sn]->width == SPRITE32_WIDTH && shift_bits >= 64) {
                    int sb = shift_bits - 64;
                    bitmap[0] = sb ? (bitmap[1] >> sb) : bitmap[1];
                    invmask[0] = sb ? (invmask[1] >> sb) : invmask[1];
                    bitmap[1] = 0;
                    invmask[1] = 0;
                } else if (sprites[sn]->width == SPRITE32_WIDTH) {
                    bitmap[0] = (bitmap[0] >> shift_bits) | (bitmap[1] << (64 - shift_bits));
                    invmask[0] = (invmask[0] >> shift_bits) | (invmask[1] << (64 - shift_bits));
                    bitmap[1] = (bitmap[1] >> shift_bits);
                    invmask[1] = (invmask[1] >> shift_bits);
                } else {
                    bitmap[0] = (bitmap[0] >> shift_bits);
                    invmask[0] = (invmask[0] >> shift_bits);
                }
            }
        }
        for (int k = 0; k < chunks; k++) {
            int pixel = ((SCREENWIDTH * y1) + x + (k * SPRITE16_WIDTH));
            memcpy(&bgrnd, &vga_data_array[db_draw][pixel >> 1], 8);
            sprites[sn]->bgrnd[k][j] = bgrnd;
            // Fast path: fully opaque row — skip masking entirely
            if (j < 64 && !shifts && (sprites[sn]->opaque[k][oddeven] & ((uint64_t)1 << j))) {
                newScreen = bitmap[k];
            } else {
                newScreen = bgrnd ^ ((bgrnd ^ bitmap[k]) & invmask[k]);
            }
            memcpy(&vga_data_array[db_draw][pixel >> 1], &newScreen, 8);
        }
    }
    sprites[sn]->x = x;
    sprites[sn]->y = y;
    sprites[sn]->bgValid = true;
    draw_order_append(sn);
}

void hideSprite(uint sn) {
    if (sn >= MAXSPRITES || !sprites[sn]) return;
    eraseSprite(sn);
    draw_order_remove(sn);
}

static inline bool dest_overlaps_sprite(short x, short y, short w, short h, int s) {
    if (!sprites[s] || !sprites[s]->bgValid) return false;
    return !(x + w  <= sprites[s]->x ||
             sprites[s]->x + sprites[s]->width  <= x ||
             y + h <= sprites[s]->y ||
             sprites[s]->y + sprites[s]->height <= y);
}

void moveSprite(uint sn, short x, short y) {
    if (sn >= MAXSPRITES || !sprites[sn]) return;
    if (!sprites[sn]->bgValid) {
        drawSprite(sn, x, y, false);
        return;
    }

    int sn_idx = draw_order_find(sn);
    short sw = sprites[sn]->width;
    short sh = sprites[sn]->height;

    // Fast path: no higher-z overlap at source AND no higher-z overlap at destination.
    // Only higher-z sprites matter at source: lower-z sprites are stored in sn->bgrnd
    // and restore correctly without a full erase/redraw cycle.
    bool has_src_overlap = false;
    for (int i = sn_idx + 1; i < draw_order_count; i++) {
        int s = draw_order[i];
        if (sprites_overlap(s, sn)) {
            has_src_overlap = true;
            break;
        }
    }
    if (!has_src_overlap) {
        bool has_dest_higher = false;
        for (int i = sn_idx + 1; i < draw_order_count; i++) {
            int s = draw_order[i];
            if (dest_overlaps_sprite(x, y, sw, sh, s)) {
                has_dest_higher = true;
                break;
            }
        }
        if (!has_dest_higher) {
            drawSprite(sn, x, y, true);
            return;
        }
    }

    // Full path: build the complete erase/redraw set.
    // Seed with sn, add source overlaps and dest overlaps,
    // then compute transitive closure (any sprite that overlaps
    // something already in the set must also be included).
    //
    // (uint64_t)1 rather than 1u: sprite numbers run 0..(MAXSPRITES-1).
    // If MAXSPRITES is ever raised above 32, shifting a 32-bit 1u by 32+
    // is UB in C. uint64_t keeps this safe up to 63 sprites without
    // requiring any other changes here.
    uint64_t erase_set = (uint64_t)1 << sn;

    // Add higher-z sprites that overlap sn's destination
    for (int i = sn_idx + 1; i < draw_order_count; i++) {
        int s = draw_order[i];
        if (sprites[s] && sprites[s]->bgValid && dest_overlaps_sprite(x, y, sw, sh, s))
            erase_set |= ((uint64_t)1 << s);
    }

    // Transitive closure: keep adding sprites that overlap anything
    // already in the set until stable.
    bool changed;
    do {
        changed = false;
        for (int i = 0; i < draw_order_count; i++) {
            int s = draw_order[i];
            if (erase_set & ((uint64_t)1 << s)) continue;
            if (!sprites[s] || !sprites[s]->bgValid) continue;
            for (int j = 0; j < draw_order_count; j++) {
                int es = draw_order[j];
                if (!(erase_set & ((uint64_t)1 << es))) continue;
                if (sprites_overlap(s, es)) {
                    erase_set |= ((uint64_t)1 << s);
                    changed = true;
                    break;
                }
            }
        }
    } while (changed);

    // Erase in reverse draw order
    for (int i = draw_order_count - 1; i >= 0; i--) {
        int s = draw_order[i];
        if (erase_set & ((uint64_t)1 << s))
            eraseSprite(s);
    }

    // Update position of the moved sprite
    sprites[sn]->x = x;
    sprites[sn]->y = y;

    // Redraw all affected sprites in forward draw order
    for (int i = 0; i < draw_order_count; i++) {
        int s = draw_order[i];
        if (erase_set & ((uint64_t)1 << s))
            drawSprite(s, sprites[s]->x, sprites[s]->y, false);
    }
}

void refreshSprites(void) {
    // Erase all visible sprites in reverse draw order
    for (int i = draw_order_count - 1; i >= 0; i--) {
        int s = draw_order[i];
        if (sprites[s] && sprites[s]->bgValid)
            eraseSprite(s);
    }
    // Redraw all in forward draw order
    for (int i = 0; i < draw_order_count; i++) {
        int s = draw_order[i];
        if (sprites[s])
            drawSprite(s, sprites[s]->x, sprites[s]->y, false);
    }
}

//

tile_t *tiles[MAXTILES];
void loadTile(uint sn, short width, short height, unsigned char *sdata) {
    if (sn >= MAXTILES)
        return;
    if (tiles[sn])    // already exists
        return;
    if (width != TILE32_WIDTH) width = TILE16_WIDTH;
    tile_t *n = calloc(1, sizeof(tile_t));
    if (!n) return;
    bool needFree = false;
    if (!sdata) {
        int chunk = width * height;
        sdata = malloc(chunk);
        if (!sdata) { free(n); return; }
        for (int i = 0; i < chunk;) {
            unsigned char cx;
            if (!getByte(&cx))
                continue;
            sdata[i++] = cx;
        }
        needFree = true;
    }

    n->bitmap[0][0] = malloc(sizeof(uint64_t) * height);
    n->bitmap[0][1] = malloc(sizeof(uint64_t) * height);
    if (width == TILE32_WIDTH) {
        n->bitmap[1][0] = malloc(sizeof(uint64_t) * height);
        n->bitmap[1][1] = malloc(sizeof(uint64_t) * height);
    }
    if (!n->bitmap[0][0] || !n->bitmap[0][1] ||
        (width == TILE32_WIDTH &&
         (!n->bitmap[1][0] || !n->bitmap[1][1]))) {
        free(n->bitmap[0][0]); free(n->bitmap[0][1]);
        free(n->bitmap[1][0]); free(n->bitmap[1][1]);
        if (needFree) free(sdata);
        free(n);
        return;
    }
    int chunks = width / TILE16_WIDTH;
    for (int i = 0; i < height; i++) {
        for (int k = 0; k < chunks; k++) {
            uint64_t bitmap = 0;
            unsigned char cx;
            for (int j = TILE16_WIDTH - 1; j >= 0; j--) {
                bitmap <<= 4;
                cx = sdata[j + (i * width) + (k * TILE16_WIDTH)];  // Read in the RGB332 value
                cx = convertRGB332(cx);                           // And convert it
                bitmap |= (LOW_NIBBLE_MASK & cx);
            }
            n->bitmap[k][0][i] = bitmap;
        }
        // Generate the odd-x variant by shifting right by 1 pixel.
        // The rightmost pixel (MSN of highest chunk) is replaced with
        // the background fill color (LSN64) so no pixel is lost.
        if (width == TILE32_WIDTH) {
            uint64_t carry;
            uint64_t bm1 = (n->bitmap[1][0][i] & ~MSN64);
            carry = (n->bitmap[0][0][i] & MSN64) >> 60;
            n->bitmap[1][1][i] = (bm1 << 4) | carry;
        }
        uint64_t bm0 = (n->bitmap[0][0][i] & ~MSN64);
        n->bitmap[0][1][i] = (bm0 << 4) | LSN64;
    }
    n->height = height;
    n->width = width;
    tiles[sn] = n;
    if (needFree) free(sdata);
}

void drawTile(uint sn, short x, short y) {
    if (sn >= MAXTILES || !tiles[sn]) return;
    if (x <= -tiles[sn]->width || x >= SCREENWIDTH || y >= SCREENHEIGHT || y <= -tiles[sn]->height) return;
    uint64_t bitmap[2];
    int shifts = 0;
    bool shift_right = true;
    int maxx = SCREENWIDTH - tiles[sn]->width;
    // Handle moving off screen left or right
    if (x > maxx) {
        shifts = x - maxx;
        x = maxx;
    } else if (x < 0) {
        shifts = -x;
        x = 0;
        shift_right = false;
    }
    int oddeven = x & 0x1;
    int yend = y + tiles[sn]->height;
    int chunks = tiles[sn]->width / TILE16_WIDTH;
    int j = 0;
    for (int y1 = y; y1 < yend; y1++, j++) {
        if (y1 < 0 || y1 >= SCREENHEIGHT) continue;
        bitmap[0] = tiles[sn]->bitmap[0][oddeven][j];
        if (tiles[sn]->width == TILE32_WIDTH) {
            bitmap[1] = tiles[sn]->bitmap[1][oddeven][j];
        }
        if (shifts > 0) {
            int shift_bits = shifts * 4;
            if (shift_right) {
                if (tiles[sn]->width == TILE32_WIDTH && shift_bits >= 64) {
                    int sb = shift_bits - 64;
                    bitmap[1] = sb ? ((bitmap[0] << sb) | (((uint64_t)1 << sb) - 1)) : bitmap[0];
                    bitmap[0] = UINT64_MAX;
                } else if (tiles[sn]->width == TILE32_WIDTH) {
                    uint64_t fill = ((uint64_t)1 << shift_bits) - 1;
                    bitmap[1] = (bitmap[1] << shift_bits) | (bitmap[0] >> (64 - shift_bits));
                    bitmap[0] = (bitmap[0] << shift_bits) | fill;
                } else {
                    uint64_t fill = ((uint64_t)1 << shift_bits) - 1;
                    bitmap[0] = (bitmap[0] << shift_bits) | fill;
                }
            } else {
                if (tiles[sn]->width == TILE32_WIDTH && shift_bits >= 64) {
                    int sb = shift_bits - 64;
                    uint64_t hi1 = sb ? ~(((uint64_t)1 << (64 - sb)) - 1) : 0;
                    bitmap[0] = (bitmap[1] >> sb) | hi1;
                    bitmap[1] = UINT64_MAX;
                } else if (tiles[sn]->width == TILE32_WIDTH) {
                    uint64_t hi_fill = ~(((uint64_t)1 << (64 - shift_bits)) - 1);
                    bitmap[0] = (bitmap[0] >> shift_bits) | (bitmap[1] << (64 - shift_bits));
                    bitmap[1] = (bitmap[1] >> shift_bits) | hi_fill;
                } else {
                    uint64_t hi_fill = ~(((uint64_t)1 << (64 - shift_bits)) - 1);
                    bitmap[0] = (bitmap[0] >> shift_bits) | hi_fill;
                }
            }
        }

        for (int k = 0; k < chunks; k++) {
            int pixel = ((SCREENWIDTH * y1) + x + (k * TILE16_WIDTH));
            memcpy(&vga_data_array[db_draw][pixel >> 1], &bitmap[k], 8);
        }
    }
    tiles[sn]->x = x;
    tiles[sn]->y = y;
}
