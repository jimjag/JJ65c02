.ifndef _CONSOLE_INC_
_CONSOLE_INC_ = 1

.import CON_init
.import CON_read_byte
.import CON_write_byte
.import CON_write_string

.include "console.h"

.macro CON_writeln str_addr
    lda #<str_addr
    sta CON_SPTR
    lda #>str_addr
    sta CON_SPTR+1
    jsr CON_write_string
.endmacro

.endif