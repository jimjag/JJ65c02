.ifndef _TTY_INC_
_TTY_INC_ = 1

.import TTY_setup_term
.import TTY_readln
.import TTY_clear_screen
.import TTY_reset_user_input
.import welcome_msg

.include "tty.h"

.define TTY_write_char ACIA_write_byte
.define TTY_read_char ACIA_read_byte

.macro TTY_writeln str_addr
    lda #<str_addr
    sta ACIA_SPTR
    lda #>str_addr
    sta ACIA_SPTR+1
    jsr ACIA_write_string
.endmacro

.endif
