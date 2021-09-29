.ifndef _TTY_INC_
_TTY_INC_ = 1

.import TTY_setup_term
.import TTY_read
.import TTY_clear_screen
.import TTY_reset_user_input
.import welcome_msg

.include "tty.h"

.macro TTY_writeln str_addr
    lda #<str_addr
    sta ptr1
    lda #>str_addr
    sta ptr1+1
    jsr ACIA_write_string
.endmacro

.endif
