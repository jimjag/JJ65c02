.ifndef _ACIA_INC_
_ACIA_INC_ = 1

.import ACIA_init
.import ACIA_read_byte
.import ACIA_write_byte
.import ACIA_write_string
.importzp ptr1


.macro ACIA_writeln str_addr
    lda #<str_addr
    sta ptr1
    lda #>str_addr
    sta ptr1+1
    jsr ACIA_write_string
.endmacro

.include "acia.h"

.endif
