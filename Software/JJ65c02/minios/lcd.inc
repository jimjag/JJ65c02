.ifndef _LCD_INC_
_LCD_INC_ = 1

.import LCD_clear_video_ram
.import LCD_print
.import LCD_print_with_offset
.import LCD_print_text
.import LCD_initialize
.import LCD_clear_screen
.import LCD_set_cursor
.import LCD_render
.import LCD_wait_busy
.import LCD_send_instruction
.import LCD_send_data

.import VRAM_OFFSETS

.macro LCD_writeln str_addr
    lda #<str_addr
    ldy #>str_addr
    jsr LCD_print
.endmacro


.include "lcd.h"

.endif
