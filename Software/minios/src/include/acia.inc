.ifndef _ACIA_INC_
_ACIA_INC_ = 1

.import ACIA_init
.import ACIA_read_byte
.import ACIA_read_byte_blk
.import ACIA_write_byte
.import ACIA_write_string
.import ACIA_ihandler

.macro ACIA_writeln str_addr
    lda #<str_addr
    sta ACIA_SPTR
    lda #>str_addr
    sta ACIA_SPTR+1
    jsr ACIA_write_string
.endmacro

.include "acia.h"

.endif
