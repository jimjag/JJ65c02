// escape sequence state
#define ESC_READY    0
#define SAW_ESC      1
#define ESC_COLLECT  2

#define MAX_ESC_PARAMS          5
static int esc_state = ESC_READY;
static int esc_parameters[MAX_ESC_PARAMS];
static bool parameter_q;
static int esc_parameter_count;
static unsigned char esc_c1;
static unsigned char esc_final_byte;

// Clear escape sequence parameters
static void clear_escape_parameters() {
    for (int i = 0; i < MAX_ESC_PARAMS; i++) {
        esc_parameters[i] = 0;
    }
    esc_parameter_count = 0;
}

// Reset escape sequence processing
static void reset_escape_sequence() {
    clear_escape_parameters();
    esc_state = ESC_READY;
    esc_c1 = 0;
    esc_final_byte = 0;
    parameter_q = false;
}

static void not_implemented() {}

// Treat ESC sequence received
/*
// these should now be populated:
    static int esc_parameters[MAX_ESC_PARAMS];
    static int esc_parameter_count;
    static unsigned char esc_c1;
    static unsigned char esc_final_byte;       
*/
static void esc_sequence_received() {
    int n,m; 

    if (esc_c1 == '[') {
        // CSI
        switch(esc_final_byte){
            case 'A':
            // Cursor Up
            //Moves the cursor n (default 1) cells
                n = esc_parameters[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y -= n;
                checkCursor();
                break;
            case 'B':
            // Cursor Down
            //Moves the cursor n (default 1) cells
                n = esc_parameters[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.y += n;
                checkCursor();
                break;
            case 'C':
            // Cursor Forward
            //Moves the cursor n (default 1) cells
                n = esc_parameters[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.x += n;
                checkCursor();
                break;
            case 'D':
            // Cursor Backward
            //Moves the cursor n (default 1) cells
                n = esc_parameters[0];
                if (n == 0) {
                    n = 1;
                }
                tcurs.x -= n;
                checkCursor();
                break;
            case 'H':
            // Moves the cursor to row n, column m
            // The parameters are 1-based, and default to 1
            // these are zero based
                tcurs.x = esc_parameters[0]-1;
                tcurs.y = esc_parameters[1]-1;
                checkCursor();
                break;
            case 'K':
            // Erases part of the line. If n is 0 (or missing), clear from cursor to the end of the line. 
            // If n is 1, clear from cursor to beginning of the line. If n is 2, clear entire line. 
            // Cursor position does not change.
                switch(esc_parameters[0]){
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
                switch(esc_parameters[0]){
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
                n = esc_parameters[0];
                if (n == 0) {
                    n = 1;
                }
                if (n >= (maxTcurs.y + 1)) {
                    clearScreen();
                } else {
                    termScroll(n);
                }
                break;
            case 'h':
                if (parameter_q && (esc_parameters[0]==25)) {
                    // show cursor
                    not_implemented();
                }
                break;
            case 'l':
                if (parameter_q && (esc_parameters[0]==25)) {
                    // hide cursor
                    not_implemented();
                }
                break;
            case 'm':
                // Sets colors and style of the characters following this code
                n = esc_parameters[0];
                if (n == 0) {
                    // reset / normal
                    textfgcolor = WHITE;
                    textbgcolor = BLACK;
                } else if (n == 7) {
                    // reverse
                    unsigned char aux = textfgcolor;
                    textfgcolor = textbgcolor;
                    textbgcolor = aux;
                } else if ((n >= 30) && (n <= 37)) {
                    // set foreground to ANSI color
                    textfgcolor = ansi_pallet[n-30];
                } else if ((n == 38) && (esc_parameters[1] == 5)) {
                    // set foreground to rgb color
                    textfgcolor = esc_parameters[2] & 0xFF;
                } else if ((n >= 40) && (n <= 47)) {
                    // set background to ANSI color
                    textbgcolor = ansi_pallet[n-40];
                } else if ((n == 48) && (esc_parameters[1] == 5)) {
                    // set background to rgb color
                    textbgcolor = esc_parameters[2] & 0xFF;
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
            default:
                break;
        }
    }
    else {
        // ignore everything else
    }

    // our work here is done
    reset_escape_sequence();
}

// Collect escape sequence info
bool collect_sequence(unsigned char chrx) {
    // waiting on parameter character, semicolon or final byte
    if((chrx >= '0') && (chrx <= '9')) { 
        // parameter value
        if(esc_parameter_count < MAX_ESC_PARAMS) {
            esc_parameters[esc_parameter_count] *= 10;
            esc_parameters[esc_parameter_count] += chrx - 0x30;
        }
    } 
    else if (chrx == ';') { 
        // move to next param
        if (esc_parameter_count < MAX_ESC_PARAMS) {
            esc_parameter_count++;
        }
    }
    else if (chrx == '?') { 
        parameter_q=true;
    }
    else if ((chrx >= 0x40) && (chrx < 0x7E)) { 
        // final byte, register and handle
        esc_final_byte = chrx;
        esc_sequence_received();
    }
    else {
        // Huh? Makes no sense. Punt and print
        return false;
    }
    return true;
}

