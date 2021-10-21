.ifndef _LCD_INC_
_LCD_INC_ = 1

.import LCD_clear_video_ram
.import LCD_write_string
.import LCD_write_string_with_offset
.import LCD_write_text
.import LCD_initialize
.import LCD_clear_screen
.import LCD_set_cursor
.import LCD_render
.import LCD_wait_busy
.import LCD_send_instruction
.import LCD_send_data

.macro LCD_writeln str_addr
    lda #<str_addr
    sta LCD_SPTR
    lda #>str_addr
    sta LCD_SPTR+1
    jsr LCD_write_string
.endmacro

.macro LCD_writetxt str_addr
    lda #<str_addr
    sta TEXT_BLK
    lda #>str_addr
    sta TEXT_BLK+1
    jsr LCD_write_text
.endmacro


.include "lcd.h"

.endif
