.ifndef _TTY_INC_
_TTY_INC_ = 1

.import TTY_setup_term
.import TTY_readln
.import TTY_clear_screen
.import TTY_reset_user_input
.import TTY_send_newline
.import TTY_send_backspace

.import welcome_msg

.include "tty.h"

.define TTY_write_char ACIA_write_byte
.define TTY_read_char ACIA_read_byte
.define TTY_writeln ACIA_writeln

.macro TTY_read_line buffer, buffer_size
    pha
    phx
    phy
    lda #<buffer
    ldx #>buffer
    ldy #(buffer_size)
    jsr TTY_readln
    ply
    plx
    pla
.endmacro

.endif
