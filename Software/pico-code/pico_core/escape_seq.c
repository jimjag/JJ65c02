/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */
// escape sequence state
enum escape_state{ESC_READY, MAYBE_ESC_SEQ, ESC_COLLECT};

#define MAX_ESC_PARAMS 6
enum escape_state esc_state = ESC_READY;
static int escP[MAX_ESC_PARAMS];
static bool parameter_q;
static bool hex_entry;
static int esc_parameter_count = 0;
static unsigned char esc_c1;
static unsigned char esc_final_byte;

// Clear escape sequence parameters
static void clear_escape_parameters(void) {
    for (int i = 0; i < MAX_ESC_PARAMS; i++) {
        escP[i] = 0;
    }
    esc_parameter_count = 0;
}

// Reset escape sequence processing
static void reset_escape_sequence(void) {
    clear_escape_parameters();
    esc_state = ESC_READY;
    esc_c1 = 0;
    esc_final_byte = 0;
    parameter_q = false;
    hex_entry = false;
}

static bool text_bold;

static void eraseCells(int row, int col_start, int col_end) {
    int ncols = col_end - col_start + 1;
    int idx = col_start + row * textrow_size;
    dma_memset(terminal + idx, ' ', ncols, true);
    drawFilledRect(col_start * FONTWIDTH, row * FONTHEIGHT, ncols * FONTWIDTH, FONTHEIGHT, textbgcolor, false);
}

static void esc_sequence_received(void) {
    int n,m;
    int start,end;

    if (esc_c1 == '[') {
        // CSI
        switch(esc_final_byte){
            case 'A':
            // Cursor Up
            //Moves the cursor n (default 1) cells
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y -= n;
                checkCursor();
                break;
            case 'B':
            // Cursor Down
            //Moves the cursor n (default 1) cells
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y += n;
                checkCursor();
                break;
            case 'C':
            // Cursor Forward
            //Moves the cursor n (default 1) cells
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.x += n;
                checkCursor();
                break;
            case 'D':
            // Cursor Backward
            //Moves the cursor n (default 1) cells
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.x -= n;
                checkCursor();
                break;
            case 'E':
            // Cursor Next Line - move down n lines, to column 0
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y += n;
                tcurs.x = 0;
                checkCursor();
                break;
            case 'F':
            // Cursor Previous Line - move up n lines, to column 0
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y -= n;
                tcurs.x = 0;
                checkCursor();
                break;
            case 'H':
            // Moves the cursor to row n, column m
            // The parameters are 1-based, and default to 1
            // Recall internally our text cursors are zero based
                n = escP[0] ? escP[0] : 1;
                m = escP[1] ? escP[1] : 1;
                tcurs.y = n - 1;
                tcurs.x = m - 1;
                checkCursor();
                break;
            case 'K':
            // Erases part of the line.
            // Cursor position does not change.
                switch(escP[0]){
                    case 0:
                        eraseCells(tcurs.y, tcurs.x, maxTcurs.x);
                        break;
                    case 1:
                        eraseCells(tcurs.y, 0, tcurs.x);
                        break;
                    case 2:
                        eraseCells(tcurs.y, 0, maxTcurs.x);
                        break;
                }
                break;
            case 'J':
                switch(escP[0]){
                    case 0:
                        // clear from cursor to end of screen
                        eraseCells(tcurs.y, tcurs.x, maxTcurs.x);
                        for (int row = tcurs.y + 1; row <= maxTcurs.y; row++) {
                            eraseCells(row, 0, maxTcurs.x);
                        }
                        break;
                    case 1:
                        // clear from cursor to beginning of the screen
                        for (int row = 0; row < tcurs.y; row++) {
                            eraseCells(row, 0, maxTcurs.x);
                        }
                        eraseCells(tcurs.y, 0, tcurs.x);
                        break;
                    case 2:
                    case 3:
                        // clear entire screen
                        clearScreen();
                        setTxtCursor(0,0);
                        break;
                }
                break;
            case 'S':
            // Scroll whole page up by n (default 1) lines. New lines are added at the bottom.
                n = escP[0];
                if (n == 0) {
                    n = 1;
                }
                if (n >= (maxTcurs.y + 1)) {
                    clearScreen();
                } else {
                    termScrollUp(n);
                }
                break;
            case 'h': // SM - Set Mode
                if (parameter_q && (escP[0] == 25)) {
                    // show cursor
                    enableCurs(true);
                }
                if (parameter_q && (escP[0] == 4)) {
                    // show cursor
                    enableSmoothScroll(true);
                }
                break;
            case 'l': // RM - Reset Mode
                if (parameter_q && (escP[0] == 25)) {
                    // hide cursor
                    enableCurs(false);
                }
                if (parameter_q && (escP[0] == 4)) {
                    // show cursor
                    enableSmoothScroll(false);
                }
                break;
            case 'm': // SGR - Select Graphic Rendition
                for (int i = 0; i <= esc_parameter_count && i < MAX_ESC_PARAMS; i++) {
                    n = escP[i];
                    if (n == 0) {
                        textfgcolor = WHITE_INT;
                        textbgcolor = BLACK_INT;
                        text_bold = false;
                    } else if (n == 1) {
                        text_bold = true;
                    } else if (n == 7) {
                        swap(textfgcolor, textbgcolor);
                    } else if (n == 22) {
                        text_bold = false;
                    } else if ((n >= 30) && (n <= 37)) {
                        textfgcolor = ansi_pallet[n-30];
                        if (text_bold) textfgcolor += 8;
                    } else if ((n == 38) && ((i+2) <= esc_parameter_count) && (i+2 < MAX_ESC_PARAMS) && (escP[i+1] == 5)) {
                        textfgcolor = escP[i+2] & 0x0f;
                        i += 2;
                    } else if (n == 39) {
                        textfgcolor = WHITE_INT;
                    } else if ((n >= 40) && (n <= 47)) {
                        textbgcolor = ansi_pallet[n-40];
                    } else if ((n == 48) && ((i+2) <= esc_parameter_count) && (i+2 < MAX_ESC_PARAMS) && (escP[i+1] == 5)) {
                        textbgcolor = escP[i+2] & 0x0f;
                        i += 2;
                    } else if (n == 49) {
                        textbgcolor = BLACK_INT;
                    } else if ((n >= 90) && (n <= 97)) {
                        textfgcolor = ansi_pallet[n-90] + 8;
                    } else if ((n >= 100) && (n <= 107)) {
                        textbgcolor = ansi_pallet[n-100] + 8;
                    }
                }
                break;
            case 'u':
            // move to saved cursor position
                tcurs.x = savedTcurs.x;
                tcurs.y = savedTcurs.y;
                break;
            case 's':
            // save cursor position
                savedTcurs.x = tcurs.x;
                savedTcurs.y = tcurs.y;
                break;
            case 'Z':  // Extended commands
                switch (escP[0]) {
                    // --- Utility (0-11) ---
                    case 0: // Write a raw character: Esc[Z0;<char>Z
                        writeChar(escP[1]);
                        break;
                    case 1: // Sound: Esc[Z1;<val>Z
                        multicore_fifo_push_blocking((uint32_t)escP[1]);
                        break;
                    case 2: // Set fg color: Esc[Z2;<color>Z
                        textfgcolor = escP[1] & 0x0f;
                        break;
                    case 3: // Set bg color: Esc[Z3;<color>Z
                        textbgcolor = escP[1] & 0x0f;
                        break;
                    case 4: // VRAM copy: Esc[Z4;<x1>;<y1>;<x2>;<y2>;<len>Z
                        start = (escP[2] * SCREENWIDTH + escP[1]) >> 1;
                        end = (escP[4] * SCREENWIDTH + escP[3]) >> 1;
                        dma_memcpy(&vga_data_array[db_draw][end], &vga_data_array[db_draw][start], escP[5]>>1, true);
                        break;
                    case 5: // VRAM set: Esc[Z5;<x>;<y>;<byte>;<len>Z
                        start = (escP[2] * SCREENWIDTH + escP[1]) >> 1;
                        dma_memset(&vga_data_array[db_draw][start], escP[3], escP[4]>>1, true);
                        break;
                    case 6: // VGA scroll up: Esc[Z6;<lines>Z
                        vgaScrollUp(escP[1]);
                        break;
                    case 7: // VGA scroll left: Esc[Z7;<pixels>Z
                        vgaScrollLeft(escP[1]);
                        break;
                    case 8: // Copy show to draw buffer: Esc[Z8Z
                        show2drawDB();
                        break;
                    case 9: // Switch double buffer: Esc[Z9Z
                        switchDB();
                        break;
                    case 10: // Enable double buffering: Esc[Z10;<mode>Z
                             // mode 1 = pointer-swap, 0/absent = copy (default)
                        setDBSwap(escP[1] == 1);
                        enableDB();
                        break;
                    case 11: // Disable double buffering: Esc[Z11Z
                        disableDB();
                        break;
                    // --- Sprites and Tiles (12-19) ---
                    // Coordinates are biased by 1000 (send x+1000, y+1000)
                    // to allow negative positions for off-screen clipping.
                    case 12: // Load sprite: Esc[Z12;<sn>;<width>;<height>Z + raw bytes
                        loadSprite(escP[1], escP[2], escP[3], NULL);
                        break;
                    case 13: // Draw sprite: Esc[Z13;<sn>;<x+1000>;<y+1000>;<erase>Z
                        drawSprite(escP[1], escP[2] - 1000, escP[3] - 1000, escP[4] != 0);
                        break;
                    case 14: // Erase sprite: Esc[Z14;<sn>Z
                        eraseSprite(escP[1]);
                        break;
                    case 15: // Move sprite: Esc[Z15;<sn>;<x+1000>;<y+1000>Z
                        moveSprite(escP[1], escP[2] - 1000, escP[3] - 1000);
                        break;
                    case 16: // Hide sprite: Esc[Z16;<sn>Z
                        hideSprite(escP[1]);
                        break;
                    case 17: // Refresh all sprites: Esc[Z17Z
                        refreshSprites();
                        break;
                    case 18: // Load tile: Esc[Z18;<sn>;<width>;<height>Z + raw bytes
                        loadTile(escP[1], escP[2], escP[3], NULL);
                        break;
                    case 19: // Draw tile: Esc[Z19;<sn>;<x+1000>;<y+1000>Z
                        drawTile(escP[1], escP[2] - 1000, escP[3] - 1000);
                        break;
                    // --- Graphics primitives (20-28) ---
                    case 20: // Draw pixel: Esc[Z20;<x>;<y>Z
                        drawPixel(escP[1], escP[2], textfgcolor, false);
                        break;
                    case 21: // Draw character: Esc[Z21;<x>;<y>;<char>Z
                        drawChar(escP[1], escP[2], escP[3], textfgcolor, textbgcolor, 1, false);
                        break;
                    case 22: // Draw line: Esc[Z22;<x1>;<y1>;<x2>;<y2>[;<color>]Z
                        drawLine(escP[1], escP[2], escP[3], escP[4],
                            esc_parameter_count > 4 ? escP[5] & 0x0f : textfgcolor, false);
                        break;
                    case 23: // Draw rect: Esc[Z23;<x>;<y>;<w>;<h>[;<color>]Z
                        drawRect(escP[1], escP[2], escP[3], escP[4],
                            esc_parameter_count > 4 ? escP[5] & 0x0f : textfgcolor, false);
                        break;
                    case 24: // Draw filled rect: Esc[Z24;<x>;<y>;<w>;<h>[;<color>]Z
                        drawFilledRect(escP[1], escP[2], escP[3], escP[4],
                            esc_parameter_count > 4 ? escP[5] & 0x0f : textfgcolor, false);
                        break;
                    case 25: // Draw circle: Esc[Z25;<x>;<y>;<r>[;<color>]Z
                        drawCircle(escP[1], escP[2], escP[3],
                            esc_parameter_count > 3 ? escP[4] & 0x0f : textfgcolor, false);
                        break;
                    case 26: // Draw filled circle: Esc[Z26;<x>;<y>;<r>[;<color>]Z
                        drawFilledCircle(escP[1], escP[2], escP[3],
                            esc_parameter_count > 3 ? escP[4] & 0x0f : textfgcolor, false);
                        break;
                    case 27: // Draw rounded rect: Esc[Z27;<x>;<y>;<w>;<h>;<r>Z
                        drawRoundRect(escP[1], escP[2], escP[3], escP[4], escP[5], textfgcolor, false);
                        break;
                    case 28: // Draw filled rounded rect: Esc[Z28;<x>;<y>;<w>;<h>;<r>Z
                        drawFilledRoundRect(escP[1], escP[2], escP[3], escP[4], escP[5], textfgcolor, false);
                        break;
                }
                break;
            default:
                break;
        }
    }
    else {
        ; // ignore everything else
    }
    // our work here is done
    reset_escape_sequence();
}

// Collect escape sequence info
static bool collect_sequence(unsigned char chrx) {
    // waiting on parameter character, semicolon or final byte
    if (chrx=='Z' && esc_parameter_count==0) {
        ;  // nop
    } else if (chrx=='z' && esc_parameter_count==0) {
        hex_entry = true;  // nop
    } else if (hex_entry && isxdigit(chrx)) {
        // esc_parameter_count can legally equal MAX_ESC_PARAMS after a
        // trailing ';' — ignore further digits (as the decimal path does)
        if (esc_parameter_count < MAX_ESC_PARAMS) {
            escP[esc_parameter_count] <<= 4;
            if (isdigit(chrx)) {
                escP[esc_parameter_count] |= chrx - '0';
            } else {
                escP[esc_parameter_count] |= toupper(chrx) - 'A' + 10;
            }
        }
    } else if (isdigit(chrx)) {
        // parameter value
        if(esc_parameter_count < MAX_ESC_PARAMS) {
            escP[esc_parameter_count] *= 10;
            escP[esc_parameter_count] += chrx - '0';
        }
    } else if (chrx == ';') {
        // move to next param
        if (esc_parameter_count < MAX_ESC_PARAMS) {
            esc_parameter_count++;
        }
    } else if (chrx == '?') {
        parameter_q=true;
    } else if ((chrx >= '@') && (chrx < '~')) {
        // final byte, register and handle
        esc_final_byte = chrx;
        esc_sequence_received();
    } else {
        // Huh? Makes no sense. Punt and print
        return false;
    }
    return true;
}
