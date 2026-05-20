/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
// VGA Graphics functions — beam-chasing architecture.
// All display output is rendered per-scanline from layer data
// (terminal buffer, tilemap, sprites). No framebuffer.

// Convert RGB332 value to our internal 4-bit color
unsigned char convertRGB332(unsigned char color) {
    unsigned char c;
    switch (color) {
        case BLACK:         c = BLACK_INT; break;
        case RED:           c = RED_INT; break;
        case GREEN:         c = GREEN_INT; break;
        case YELLOW:        c = YELLOW_INT; break;
        case BLUE:          c = BLUE_INT; break;
        case MAGENTA:       c = MAGENTA_INT; break;
        case CYAN:          c = CYAN_INT; break;
        case LIGHT_GREY:    c = LIGHT_GREY_INT; break;
        case GREY:          c = GREY_INT; break;
        case LIGHT_RED:     c = LIGHT_RED_INT; break;
        case LIGHT_GREEN:   c = LIGHT_GREEN_INT; break;
        case LIGHT_YELLOW:  c = LIGHT_YELLOW_INT; break;
        case LIGHT_BLUE:    c = LIGHT_BLUE_INT; break;
        case LIGHT_MAGENTA: c = LIGHT_MAGENTA_INT; break;
        case LIGHT_CYAN:    c = LIGHT_CYAN_INT; break;
        case WHITE:         c = WHITE_INT; break;
        default:            c = TRANSPARENT_INT; break;
    }
    return c;
}

// ============================================================
// Graphics primitives — write to the background pixel layer.
// These are visible in RENDER_TILEMAP mode as layer 0.
// ============================================================

static inline void drawPixelFast(int x, int y, unsigned char color) {
    int pixel = SCREENWIDTH * y + x;
    unsigned char *cell = &_bg_pixels[pixel >> 1];
    if (pixel & 1)
        *cell = (*cell & TOPMASK) | (color << 4);
    else
        *cell = (*cell & BOTTOMMASK) | color;
}

void drawPixel(int x, int y, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    if (x < 0 || x >= SCREENWIDTH || y < 0 || y >= SCREENHEIGHT) return;
    drawPixelFast(x, y, color);
}

void drawVLine(int x, int y, int h, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    if (x < 0 || x >= SCREENWIDTH) return;
    if (y < 0) { h += y; y = 0; }
    if (y + h > SCREENHEIGHT) h = SCREENHEIGHT - y;
    if (h <= 0) return;
    int byte = (SCREENWIDTH * y + x) >> 1;
    if (x & 1) {
        unsigned char val = color << 4;
        for (int i = 0; i < h; i++, byte += scanline_size)
            _bg_pixels[byte] = (_bg_pixels[byte] & TOPMASK) | val;
    } else {
        for (int i = 0; i < h; i++, byte += scanline_size)
            _bg_pixels[byte] = (_bg_pixels[byte] & BOTTOMMASK) | color;
    }
}

void drawHLine(int x, int y, int w, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    if (y < 0 || y >= SCREENHEIGHT) return;
    if (x < 0) { w += x; x = 0; }
    if (x + w > SCREENWIDTH) w = SCREENWIDTH - x;
    if (w <= 0) return;
    int pixel = SCREENWIDTH * y + x;
    if (pixel & 1) {
        _bg_pixels[pixel >> 1] = (_bg_pixels[pixel >> 1] & TOPMASK) | (color << 4);
        pixel++; w--;
    }
    int middle = w >> 1;
    if (middle > 0) {
        dma_memset(&_bg_pixels[pixel >> 1], color | (color << 4), middle, true);
        pixel += middle * 2;
        w -= middle * 2;
    }
    if (w == 1)
        _bg_pixels[pixel >> 1] = (_bg_pixels[pixel >> 1] & BOTTOMMASK) | color;
}

void drawLine(int x0, int y0, int x1, int y1, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    int steep = abs(y1 - y0) > abs(x1 - x0);
    if (steep) { swap(x0, y0); swap(x1, y1); }
    if (x0 > x1) { swap(x0, x1); swap(y0, y1); }
    int dx = x1 - x0, dy = abs(y1 - y0);
    int err = dx / 2, ystep = (y0 < y1) ? 1 : -1;
    for (; x0 <= x1; x0++) {
        if (steep) drawPixel(y0, x0, color, false);
        else       drawPixel(x0, y0, color, false);
        err -= dy;
        if (err < 0) { y0 += ystep; err += dx; }
    }
}

void drawRect(int x, int y, int w, int h, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawHLine(x, y, w, color, false);
    drawHLine(x, y + h - 1, w, color, false);
    drawVLine(x, y, h, color, false);
    drawVLine(x + w - 1, y, h, color, false);
}

void drawFilledRect(int x, int y, int w, int h, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    for (int j = y; j < y + h; j++)
        drawHLine(x, j, w, color, false);
}

static void drawCircleHelper(int x0, int y0, int r, unsigned char cornername, unsigned char color) {
    int f = 1 - r, ddF_x = 1, ddF_y = -2 * r, x = 0, y = r;
    while (x < y) {
        if (f >= 0) { y--; ddF_y += 2; f += ddF_y; }
        x++; ddF_x += 2; f += ddF_x;
        if (cornername & 0x4) { drawPixelFast(x0 + x, y0 + y, color); drawPixelFast(x0 + y, y0 + x, color); }
        if (cornername & 0x2) { drawPixelFast(x0 + x, y0 - y, color); drawPixelFast(x0 + y, y0 - x, color); }
        if (cornername & 0x8) { drawPixelFast(x0 - y, y0 + x, color); drawPixelFast(x0 - x, y0 + y, color); }
        if (cornername & 0x1) { drawPixelFast(x0 - y, y0 - x, color); drawPixelFast(x0 - x, y0 - y, color); }
    }
}

void drawCircle(int x0, int y0, int r, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    int f = 1 - r, ddF_x = 1, ddF_y = -2 * r, x = 0, y = r;
    drawPixel(x0, y0 + r, color, false);
    drawPixel(x0, y0 - r, color, false);
    drawPixel(x0 + r, y0, color, false);
    drawPixel(x0 - r, y0, color, false);
    while (x < y) {
        if (f >= 0) { y--; ddF_y += 2; f += ddF_y; }
        x++; ddF_x += 2; f += ddF_x;
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

static void fillCircleHelper(int x0, int y0, int r, unsigned char cornername, int delta, char color) {
    int f = 1 - r, ddF_x = 1, ddF_y = -2 * r, x = 0, y = r;
    while (x < y) {
        if (f >= 0) { y--; ddF_y += 2; f += ddF_y; }
        x++; ddF_x += 2; f += ddF_x;
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
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawVLine(x0, y0 - r, 2 * r + 1, color, false);
    fillCircleHelper(x0, y0, r, 3, 0, color);
}

void drawRoundRect(int x, int y, int w, int h, int r, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawHLine(x + r, y, w - 2 * r, color, false);
    drawHLine(x + r, y + h - 1, w - 2 * r, color, false);
    drawVLine(x, y + r, h - 2 * r, color, false);
    drawVLine(x + w - 1, y + r, h - 2 * r, color, false);
    drawCircleHelper(x + r, y + r, r, 1, color);
    drawCircleHelper(x + w - r - 1, y + r, r, 2, color);
    drawCircleHelper(x + w - r - 1, y + h - r - 1, r, 4, color);
    drawCircleHelper(x + r, y + h - r - 1, r, 8, color);
}

void drawFilledRoundRect(int x, int y, int w, int h, int r, unsigned char color, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    drawFilledRect(x + r, y, w - 2 * r, h, color, false);
    fillCircleHelper(x + w - r - 1, y + r, r, 1, h - 2 * r - 1, color);
    fillCircleHelper(x + r, y + r, r, 2, h - 2 * r - 1, color);
}

void vgaFillScreen(unsigned char color) {
    if (color == TRANSPARENT_INT) return;
    dma_memset(_bg_pixels, (color & 0x0F) | (color << 4), sizeof(_bg_pixels), true);
}

// ============================================================
// Text and color functions
// ============================================================

void setTextColor(char c) {
    textfgcolor = convertRGB332(c);
}

void setTextColor2(char c, char b) {
    textfgcolor = convertRGB332(c);
    textbgcolor = convertRGB332(b);
}

void setFont(char n) {
    switch (n) {
        case 4: font = font_verite;  txtfont = 4; break;
        case 3: font = font_sperry;  txtfont = 3; break;
        case 2: font = font_toshiba; txtfont = 2; break;
        case 1: font = font_acm;     txtfont = 1; break;
        default: font = font_sweet16; txtfont = 0; break;
    }
}

inline void setCursor(int x, int y) {
    cursor_x = x;
    cursor_y = y;
}

inline void setTextSize(unsigned char s) {
    textsize = (s > 0) ? s : 1;
}

// drawChar writes the character into the terminal buffer at the equivalent
// cell position. The beam renderer displays it on the next frame.
void drawChar(int x, int y, unsigned char chrx, unsigned char color, char bg,
              unsigned char size, bool colorIsRGB332) {
    if (colorIsRGB332) color = convertRGB332(color);
    if (color == TRANSPARENT_INT) return;
    int col = x / FONTWIDTH;
    int row = y / FONTHEIGHT;
    if (col < 0 || col > maxTcurs.x || row < 0 || row > maxTcurs.y) return;
    int idx = col + (row * textrow_size);
    terminal[idx] = chrx;
    term_attr[idx] = ((unsigned char)bg << 4) | (color & 0x0F);
}

// drawString writes characters into terminal[] at the graphics cursor position.
static void tft_write(unsigned char chrx) {
    if (chrx == '\n') {
        cursor_y += textsize * FONTHEIGHT;
        cursor_x = 0;
    } else if (chrx == '\r') {
        // skip
    } else if (chrx == '\t') {
        int new_x = cursor_x + tabspace;
        if (new_x < SCREENWIDTH) cursor_x = new_x;
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
    while (*str) {
        tft_write(*str++);
    }
}

// Terminal Mode functions
void setTextWrap(bool w) { wrap = w; }
void setCr2Crlf(bool w) { cr2crlf = w; }
void setLf2Crlf(bool w) { lf2crlf = w; }

void termScrollUp(int rows) {
    bool was = enableCurs(false);
    if (rows <= 0) rows = 1;
    if (rows > maxTcurs.y) rows = maxTcurs.y;
    rows *= textrow_size;
    dma_memcpy(terminal, terminal + rows, terminal_size - rows, true);
    dma_memset(terminal + terminal_size - rows, ' ', rows, true);
    dma_memcpy(term_attr, term_attr + rows, terminal_size - rows, true);
    dma_memset(term_attr + terminal_size - rows, ((unsigned char)textbgcolor << 4) | ((unsigned char)textfgcolor & 0x0F), rows, true);
    enableCurs(was);
}

static void checkCursor(void) {
    if (tcurs.x > maxTcurs.x) tcurs.x = maxTcurs.x;
    else if (tcurs.x < 0) tcurs.x = 0;
    if (tcurs.y > maxTcurs.y) tcurs.y = maxTcurs.y;
    else if (tcurs.y < 0) tcurs.y = 0;
}

void setTxtCursor(int x, int y) {
    bool was = enableCurs(false);
    tcurs.x = x;
    tcurs.y = y;
    checkCursor();
    enableCurs(was);
}

void writeChar(unsigned char chrx) {
    bool was = enableCurs(false);
    int idx = tcurs.x + (tcurs.y * textrow_size);
    terminal[idx] = chrx;
    term_attr[idx] = ((unsigned char)textbgcolor << 4) | ((unsigned char)textfgcolor & 0x0F);
    tcurs.x++;
    if (tcurs.x > maxTcurs.x) {
        tcurs.x = 0;
        tcurs.y++;
        if (tcurs.y > maxTcurs.y) {
            tcurs.y = maxTcurs.y;
            termScrollUp(1);
        }
    }
    enableCurs(was);
}

static void printChar(unsigned char chrx) {
    char x, y;
    switch (chrx) {
        case '\n':
            tcurs.y++;
            if (tcurs.y > maxTcurs.y) { tcurs.y = maxTcurs.y; termScrollUp(1); }
            if (cr2crlf) tcurs.x = 0;
            break;
        case '\r':
            tcurs.x = 0;
            if (lf2crlf) { tcurs.y++; if (tcurs.y > maxTcurs.y) { tcurs.y = maxTcurs.y; termScrollUp(1); } }
            break;
        case '\t':
            tcurs.x += tabspace;
            if (tcurs.x > maxTcurs.x) tcurs.x = maxTcurs.x;
            break;
        case '\b':
            tcurs.x--;
            if (tcurs.x < 0) { tcurs.y--; if (tcurs.y < 0) tcurs.y = 0; tcurs.x = maxTcurs.x; }
            x = tcurs.x; y = tcurs.y;
            writeChar(' ');
            setTxtCursor(x, y);
            break;
        case 0x11: tcurs.y--; checkCursor(); break;
        case 0x12: tcurs.y++; checkCursor(); break;
        case 0x13: tcurs.x++; checkCursor(); break;
        case 0x14: tcurs.x--; checkCursor(); break;
        case '\a': beep(); break;
        default: writeChar(chrx); break;
    }
}

void clearScreen(void) {
    dma_memset(terminal, ' ', terminal_size, true);
    dma_memset(term_attr, ((unsigned char)textbgcolor << 4) | ((unsigned char)textfgcolor & 0x0F), terminal_size, true);
}

void printString(char *str) {
    while (*str) {
        handleByte(*str++);
    }
}

// Handle ESC sequences
#include "escape_seq.c"

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
                if ((chrx >= 'N') && (chrx < '_')) {
                    if (chrx == '[') {
                        esc_c1 = chrx;
                        esc_state = ESC_COLLECT;
                        clear_escape_parameters();
                    } else {
                        reset_escape_sequence();
                        printChar(chrx);
                    }
                } else {
                    reset_escape_sequence();
                    printChar(chrx);
                }
                break;
            case ESC_COLLECT:
                if (!collect_sequence(chrx)) {
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
 * Sprite loading — creates bitmap and mask arrays with odd/even X variants.
 * No background storage needed: the beam renderer composites live.
 */
void loadSprite(uint sn, short width, short height, unsigned char *sdata) {
    if (sn >= MAXSPRITES) return;
    if (sprites[sn]) return;
    if (width != SPRITE32_WIDTH) width = SPRITE16_WIDTH;
    sprite_t *n = malloc(sizeof(sprite_t));
    bool needFree = false;
    if (!sdata) {
        int chunk = width * height;
        sdata = malloc(chunk);
        for (int i = 0; i < chunk;) {
            unsigned char cx;
            if (!getByte(&cx)) continue;
            sdata[i++] = cx;
        }
        needFree = true;
    }
    n->bitmap[0][0] = malloc(sizeof(uint64_t) * height);
    n->bitmap[0][1] = malloc(sizeof(uint64_t) * height);
    n->mask[0][0] = malloc(sizeof(uint64_t) * height);
    n->mask[0][1] = malloc(sizeof(uint64_t) * height);
    if (width == SPRITE32_WIDTH) {
        n->bitmap[1][0] = malloc(sizeof(uint64_t) * height);
        n->bitmap[1][1] = malloc(sizeof(uint64_t) * height);
        n->mask[1][0] = malloc(sizeof(uint64_t) * height);
        n->mask[1][1] = malloc(sizeof(uint64_t) * height);
    }
    int chunks = width / SPRITE16_WIDTH;
    for (int i = 0; i < height; i++) {
        for (int k = 0; k < chunks; k++) {
            uint64_t mask = 0;
            uint64_t bitmap = 0;
            unsigned char cx;
            for (int j = SPRITE16_WIDTH - 1; j >= 0; j--) {
                mask <<= 4;
                bitmap <<= 4;
                cx = sdata[j + (i * width) + (k * SPRITE16_WIDTH)];
                cx = convertRGB332(cx);
                if (cx == TRANSPARENT_INT) mask |= TOPMASK;
                bitmap |= (TOPMASK & cx);
            }
            n->bitmap[k][0][i] = bitmap;
            n->mask[k][0][i] = mask;
        }
        if (width == SPRITE32_WIDTH) {
            uint64_t carry;
            carry = (n->bitmap[0][0][i] & MSN64) >> 60;
            n->bitmap[1][1][i] = (n->bitmap[1][0][i] << 4) | carry;
            carry = (n->mask[0][0][i] & MSN64) >> 60;
            n->mask[1][1][i] = (n->mask[1][0][i] << 4) | carry;
        }
        n->bitmap[0][1][i] = (n->bitmap[0][0][i] << 4) | LSN64;
        n->mask[0][1][i] = (n->mask[0][0][i] << 4) | LSN64;
    }
    n->x = 0;
    n->y = 0;
    n->height = height;
    n->width = width;
    sprites[sn] = n;
    if (needFree) free(sdata);
}

// Move sprite to new position. Rendering happens in the scanline ISR path.
void moveSprite(uint sn, short x, short y) {
    if (sn >= MAXSPRITES || !sprites[sn]) return;
    sprites[sn]->x = x;
    sprites[sn]->y = y;
}

// Tile loading
void loadTile(uint sn, short width, short height, unsigned char *sdata) {
    if (sn >= MAXTILES) return;
    if (tiles[sn]) return;
    if (width != TILE32_WIDTH) width = TILE16_WIDTH;
    tile_t *n = malloc(sizeof(tile_t));
    bool needFree = false;
    if (!sdata) {
        int chunk = width * height;
        sdata = malloc(chunk);
        for (int i = 0; i < chunk;) {
            unsigned char cx;
            if (!getByte(&cx)) continue;
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
    int chunks = width / TILE16_WIDTH;
    for (int i = 0; i < height; i++) {
        for (int k = 0; k < chunks; k++) {
            uint64_t bitmap = 0;
            unsigned char cx;
            for (int j = TILE16_WIDTH - 1; j >= 0; j--) {
                bitmap <<= 4;
                cx = sdata[j + (i * width) + (k * TILE16_WIDTH)];
                cx = convertRGB332(cx);
                bitmap |= (TOPMASK & cx);
            }
            n->bitmap[k][0][i] = bitmap;
        }
        if (width == TILE32_WIDTH) {
            uint64_t carry;
            carry = (n->bitmap[0][0][i] & MSN64) >> 60;
            n->bitmap[1][1][i] = (n->bitmap[1][0][i] << 4) | carry;
        }
        n->bitmap[0][1][i] = (n->bitmap[0][0][i] << 4) | LSN64;
    }
    n->height = height;
    n->width = width;
    tiles[sn] = n;
    if (needFree) free(sdata);
}
