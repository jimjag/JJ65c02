/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
// Core VGA Graphics functions
//

void vgaFillScreen(uint16_t color) {
    if (color == TRANSPARENT) return;
    dma_memset(vga_data_array, (color) | (color << 4), txcount);
}

// A function for drawing a pixel with a specified color.
// Note that because information is passed to the PIO state machines through
// a DMA channel, we only need to modify the contents of the array and the
// pixels will be automatically updated on the screen.
void drawPixel(int x, int y, char color) {
    if (color == TRANSPARENT) return;
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
        vga_data_array[pixel >> 1] = (vga_data_array[pixel >> 1] & TOPMASK) | (color << 4);
    } else {
        vga_data_array[pixel >> 1] = (vga_data_array[pixel >> 1] & BOTTOMMASK) | (color);
    }
}

void drawVLine(int x, int y, int h, char color) {
    if (color == TRANSPARENT) return;
    for (int i = y; i < (y + h); i++) {
        drawPixel(x, i, color);
    }
}

void drawHLine(int x, int y, int w, char color) {
    if (color == TRANSPARENT) return;
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
     *      color: 4-bit color value for line
     */
    if (color == TRANSPARENT) return;
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
    if (color == TRANSPARENT) return;
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
    if (color == TRANSPARENT) return;
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

void drawFilledCircle(int x0, int y0, int r, char color) {
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
    if (color == TRANSPARENT) return;
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
    if (color == TRANSPARENT) return;
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
void drawFilledRoundRect(int x, int y, int w, int h, int r, char color) {
    // smarter version
    drawFilledRect(x + r, y, w - 2 * r, h, color);

    // draw four corners
    fillCircleHelper(x + w - r - 1, y + r, r, 1, h - 2 * r - 1, color);
    fillCircleHelper(x + r, y + r, r, 2, h - 2 * r - 1, color);
}

// fill a rectangle
void drawFilledRect(int x, int y, int w, int h, char color) {
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
    if (color == TRANSPARENT) return;
    for (int i = x; i < (x + w); i++) {
        for (int j = y; j < (y + h); j++) {
            drawPixel(i, j, color);
        }
    }
}

// Draw a character
void drawChar(int x, int y, unsigned char chrx, char color, char bg,
              unsigned char size) {
    char px, py;
    if ((x >= SCREENWIDTH) ||                     // Clip right
        (y >= SCREENHEIGHT) ||                    // Clip bottom
        ((x + FONTWIDTH * size - 1) < 0) || // Clip left
        ((y + FONTHEIGHT * size - 1) < 0))  // Clip top
        return;

    for (py = 0; py < FONTHEIGHT; py++) {
        unsigned char line;
        line = pgm_read_byte(font + (chrx * FONTHEIGHT) + py);
        for (px = 0; px < FONTWIDTH; px++) {
            if (line & 0x80) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, color);
                else { // big size
                    drawFilledRect(x + (px * size), y + (py * size), size, size, color);
                }
            } else if (bg != color) {
                if (size == 1) // default size
                    drawPixel(x + px, y + py, bg);
                else { // big size
                    drawFilledRect(x + px * size, y + py * size, size, size, bg);
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

inline char safeColor(char c) {
    if (c < BLACK)
        c = BLACK;
    else if (c > WHITE)
        c = TRANSPARENT;
    return c;
}

inline void setTextColor(char c) {
    // For 'transparent' background, we'll set the bg
    // to the same as fg instead of using a flag
    textfgcolor = safeColor(c);
}

inline void setTextColor2(char c, char b) {
    /* Set color of text to be displayed
     * Parameters:
     *      c = 4-bit color of text
     *      b = 4-bit color of text background
     */
    textfgcolor = safeColor(c);
    textbgcolor = safeColor(b);
}

inline void setFont(char n) {
    switch (n) {
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
        drawChar(cursor_x, cursor_y, chrx, textfgcolor, textbgcolor, textsize);
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

bool enableCurs(bool flag) {
    bool was = cursorOn;
    if (flag && !cursorOn) { // turning it on when off
        bon = true;
        alarm_pool_add_repeating_timer_ms(apool, 500, cursor_callback, NULL, &ctimer);
    } else if (!flag && cursorOn) { // turning it off when on
        cancel_repeating_timer(&ctimer);
        unsigned char oldChar = (terminal[tcurs.x + (tcurs.y * textrow_size)]) ? terminal[tcurs.x + (tcurs.y * textrow_size)] : ' ';
        drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, oldChar, textfgcolor, textbgcolor, textsize);
    }
    cursorOn = flag;
    return was;
}

void vgaScroll (int scanlines) {
    if (scanlines <= 0) scanlines = FONTHEIGHT;
    if (scanlines >= SCREENHEIGHT) scanlines = SCREENHEIGHT - 1;
    if (!smooth_scroll) {
        scanlines *= scanline_size;
        dma_memcpy(vga_data_array, vga_data_array + scanlines, txcount - scanlines);
        dma_memset(vga_data_array + txcount - scanlines, (textbgcolor) | (textbgcolor << 4), scanlines);
    }  else {
        for (int i = 0; i < scanlines; i++) {
            dma_memcpy(vga_data_array, vga_data_array + scanline_size, txcount - scanline_size);
            dma_memset(vga_data_array + txcount - scanline_size, (textbgcolor) | (textbgcolor << 4), scanline_size);
        }
    }
}

void termScroll (int rows) {
    bool was = enableCurs(false);
    int orows = rows;
    if (rows <= 0) rows = 1;
    if (rows > maxTcurs.y) rows = maxTcurs.y;
    rows *= textrow_size;
    dma_memcpy(terminal, terminal + rows, terminal_size - rows);
    dma_memset(terminal + terminal_size - rows, ' ', rows);
    vgaScroll(orows * FONTHEIGHT);
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
    terminal[tcurs.x + (tcurs.y * textrow_size)] = chrx;
    drawChar(tcurs.x * FONTWIDTH, tcurs.y * FONTHEIGHT, chrx, textfgcolor, textbgcolor, textsize);
    tcurs.x++;
    if (tcurs.x > maxTcurs.x) {
        // End of line
        tcurs.x = 0;
        tcurs.y++;
        if (tcurs.y > maxTcurs.y) {
            tcurs.y = maxTcurs.y;
            termScroll(1);
        }
    }
    enableCurs(was);
}

// See if the character is special in any way
static void doChar(unsigned char chrx) {
    char x,y;
    switch (chrx) {
        // Handle "special" characters.
        case '\n':
            tcurs.y++;
            if (tcurs.y > maxTcurs.y) {
                tcurs.y = maxTcurs.y;
                termScroll(1);
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
                    termScroll(1);
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
    vgaFillScreen(textbgcolor);
    dma_memset(vga_data_array, (textbgcolor) | (textbgcolor << 4), txcount);
    dma_memset(terminal, ' ', terminal_size);
}


void printString(char *str) {
    while (*str) {
        printChar(*str++);
    }
}

void fill_sprite(uint sn);

// Handle ESC sequences
#include "escape_seq.c"

// Print the character and check for Esc sequences. We use
// this for input from the PS/2 or elsewhere that may
// be terminal related. If we want/need to print the
// graphics characters, use writeChar()
void printChar(unsigned char chrx) {
    bool was = enableCurs(false);
    if (esc_state == ESC_READY) {
        if (chrx == ESC) {
            esc_state = SAW_ESC;
        } else {
            doChar(chrx);
        }
    } else {
        switch(esc_state) {
            case SAW_ESC:
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
                        doChar(chrx);
                    }
                }
                else {
                    // unrecognised character after escape.
                    reset_escape_sequence();
                    doChar(chrx);
                }
                break;
            case ESC_COLLECT:
                if (!collect_sequence(chrx)) {
                    // Weird ending char
                    reset_escape_sequence();
                    doChar(chrx);
                }
                break;
            default:
                reset_escape_sequence();
                doChar(chrx);
                break;
        }
    }
    enableCurs(was);
}

void fillSprite16(uint sn) {
    unsigned char cx;
    unsigned char sdata[SPRITESIZE * SPRITESIZE];
    if (sn >= MAXSPRITES)
        return;
    if (sprites[sn])    // already exists
        return;
    sprite_t *n = malloc(sizeof(sprite_t));
    for (int i = 0; i < sizeof(sdata); ) {
        if (!getByte(&cx))
            continue;
        sdata[i++] = cx;
    }
    // NOW CREATE bitmap, mask, etc... for this sprite
    // (which was designed to be at an even X-coordinate)
    // and its odd X-coord twin.
    for (int i = 0; i < SPRITESIZE; i++) {
        uint64_t mask = 0;
        uint64_t bitmap = 0;
        for (int j = SPRITESIZE-1; j >= 0; j--) {
            mask<<=4;
            bitmap<<=4;
            cx = sdata[j + (i * SPRITESIZE)];
            if (cx == TRANSPARENT) {
                mask |= TOPMASK;
            }
            bitmap |= (TOPMASK & cx);
        }
        n->bitmap[0][i] = bitmap;
        n->mask[0][i] = mask;
        n->bitmap[1][i] = (bitmap << 4) | 0xf;
        n->mask[1][i] = (mask << 4) | 0xf;
    }
    n->bgValid = false;
    sprites[sn] = n;
}

void drawSprite16(int x, int y, uint sn, bool erase) {
    if (erase) eraseSprite16(sn);
    if (x <= -SPRITESIZE || x >= SCREENWIDTH || y >= SCREENHEIGHT || y <= -SPRITESIZE) return;
    uint64_t masked_screen, new_screen;
    uint64_t bgrnd, mask, bitmap;
    int yend = y + SPRITESIZE;
    int len = 8;
    int shifts = 0;
    bool shift_left = true;
    int maxx = SCREENWIDTH - SPRITESIZE;
    int j = 0;
    // Handle moving off screen left or right
    if (x > maxx) {
        shifts = x - maxx;
        x = maxx;
    } else if (x < 0) {
        shifts = -x;
        x = 0;
        shift_left = false;
    }
    for (int y1 = y; y1 < yend; y1++, j++) {
        if (y1 < 0 || y1 >= SCREENHEIGHT) continue;
        int pixel = ((SCREENWIDTH * y1) + x);
        int w = x&0x1;
        dma_memcpy(&bgrnd, &vga_data_array[pixel >> 1], len);
        sprites[sn]->bgrnd[j] = bgrnd;
        mask = sprites[sn]->mask[w][j];
        bitmap = sprites[sn]->bitmap[w][j];
        // Yes, this does take time and so one could argue that these
        // should be part of the stored sprite data (ala the odd/even
        // variants). But (1) that is a lot of space and (2) this is
        // only a factor when the sprite intersects with the left or
        // right border, which is rare (and in most cases never even
        // happens). So keep for now.
        for (int i = 0; i < shifts; i++) {
            if (shift_left) {
                bitmap = (bitmap << 4) | 0xf;
                mask = (mask << 4) | 0xf;
            } else {
                bitmap = (bitmap >> 4) | 0xf000000000000000;
                mask = (mask >> 4) | 0xf000000000000000;
            }
        }
        masked_screen = mask & bgrnd;
        new_screen = masked_screen | (~mask & bitmap);
        dma_memcpy(&vga_data_array[pixel >> 1], &new_screen, len);
    }
    sprites[sn]->x = x;
    sprites[sn]->y = y;
    sprites[sn]->len = len;
    sprites[sn]->bgValid = true;
}

void eraseSprite16(uint sn) {
    // Restore background (original screen)
    if (!sprites[sn]->bgValid)
        return;
    int yend = sprites[sn]->y + SPRITESIZE;
    int j = 0;
    for (int y1 = sprites[sn]->y; y1 < yend; y1++, j++) {
        if (y1 < 0 || y1 >= SCREENHEIGHT) continue;
        int pixel = ((SCREENWIDTH * y1) + sprites[sn]->x);
        dma_memcpy(&vga_data_array[pixel >> 1], &sprites[sn]->bgrnd[j], sprites[sn]->len);
    }
    sprites[sn]->bgValid = false;
}
