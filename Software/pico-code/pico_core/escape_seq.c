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
}

static void not_implemented(void) {}

// Treat ESC sequence received
/*
// these should now be populated:
    static int escP[MAX_ESC_PARAMS];
    static int esc_parameter_count;
    static unsigned char esc_c1;
    static unsigned char esc_final_byte;
*/
static void esc_sequence_received(void) {
    int n,m;

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
            case 'H':
            // Moves the cursor to row n, column m
            // The parameters are 1-based, and default to 1
            // Recall internally our text cursors are zero based
                tcurs.x = escP[0] - 1;
                tcurs.y = escP[1] - 1;
                checkCursor();
                break;
            case 'K':
            // Erases part of the line. If n is 0 (or missing), clear from cursor to the end of the line.
            // If n is 1, clear from cursor to beginning of the line. If n is 2, clear entire line.
            // Cursor position does not change.
                switch(escP[0]){
                    case 0:
                        // clear from cursor to the end of the line
                        not_implemented();
                        break;
                    case 1:
                        // clear from cursor to beginning of the line
                        not_implemented();
                        break;
                    case 2:
                        // clear entire line
                        not_implemented();
                        break;
                }
                break;
            case 'J':
                switch(escP[0]){
                    case 0:
                        // clear from cursor to end of screen
                        not_implemented();
                        break;
                    case 1:
                        // clear from cursor to beginning of the screen
                        not_implemented();
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
                    termScroll(n);
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
                // Sets colors and style of the characters following this code
                n = escP[0];
                if (n == 0) {
                    // reset / normal
                    textfgcolor = WHITE_INT;
                    textbgcolor = BLACK_INT;
                } else if (n == 7) {
                    // reverse
                    swap(textfgcolor, textbgcolor);
                } else if ((n >= 30) && (n <= 37)) {
                    // set foreground to ANSI color
                    textfgcolor = ansi_pallet[n-30];
                } else if ((n == 38) && (escP[1] == 5)) {
                    // set foreground to rgb color
                    textfgcolor = escP[2] & 0xff;
                } else if ((n >= 40) && (n <= 47)) {
                    // set background to ANSI color
                    textbgcolor = ansi_pallet[n-40];
                } else if ((n == 48) && (escP[1] == 5)) {
                    // set background to rgb color
                    textbgcolor = escP[2] & 0xff;
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
            case 'Z':  // Extended: Basic graphics
                       // NOTE: <char> is the character __in decimal__!
                switch (escP[0]) {
                    case 0: // Write a raw character: Esc[Z;<char>Z
                        writeChar(escP[1]);
                        break;
                    case 1: // Sound function - send <val> to sound routine (see soundTask() for codes) Esc[Z1;<val>Z
                        multicore_fifo_push_blocking((uint32_t)escP[1]);
                        break;
                    case 2: // Set fg color: Esc[Z2;<color>Z
                        textfgcolor = convertRGB332(escP[1]);
                        break;
                    case 3: // Set bg color: Esc[Z3;<color>Z
                        textbgcolor = convertRGB332(escP[1]);
                        break;
                    case 4: // Draw Pixel at x,y: Esc[Z4;x;yZ
                        drawPixel(escP[1], escP[2], textfgcolor, false);
                        break;
                    case 5: // Draw character <char> at x,y: Esc[Z5;x;y;<char>Z
                        drawChar(escP[1], escP[2], escP[3], textfgcolor, textbgcolor, 1, false);
                        break;
                    case 6: // Draw a line: Esc[Z6;x1;y1;x2;y2Z
                        drawLine(escP[1], escP[2], escP[3], escP[4], textfgcolor, false);
                        break;
                    case 7: // Draw an empty rect: Esc[Z7;x;y;w;hZ
                        drawRect(escP[1], escP[2], escP[3], escP[4], textfgcolor, false);
                        break;
                    case 8: // Draw a filled rect: Esc[Z8;x;y;w;hZ
                        drawFilledRect(escP[1], escP[2], escP[3], escP[4], textfgcolor, false);
                        break;
                    case 9: // Draw an empty circle: Esc[Z9;x;y;rZ
                        drawCircle(escP[1], escP[2], escP[3], textfgcolor, false);
                        break;
                    case 10: // Draw an filled circle: Esc[Z10;x;y;rZ
                        drawFilledCircle(escP[1], escP[2], escP[3], textfgcolor, false);
                        break;
                    case 11: // Draw an empty rounded rect: Esc[Z11;x;y;w;h;rZ
                        drawRoundRect(escP[1], escP[2], escP[3], escP[4], escP[5], textfgcolor, false);
                        break;
                    case 12: // Draw a filled rounded rect: Esc[Z12;x;y;w;h;rZ
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
