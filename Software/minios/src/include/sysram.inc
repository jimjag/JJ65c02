.ifndef _SYSRAM_INC_
_SYSRAM_INC_ = 1

.importzp Z0
.importzp Z1
.importzp Z2
.importzp Z3
.importzp Z4
.importzp Z5
.importzp Z6
.importzp Z7
.importzp MINIOS_STATUS
.importzp ACIA_SPTR
.importzp CON_SPTR
.importzp USER_INPUT_PTR
.importzp TEXT_BLK
.importzp SERIN_RPTR
.importzp SERIN_WPTR
.importzp PS2IN_RPTR
.importzp PS2IN_WPTR
.importzp XAML
.importzp XAMH
.importzp STL
.importzp STH
.importzp L
.importzp H
.importzp YSAV
.importzp MODE

.import CLK_SPD
.import ISR_VECTOR

.import USER_BUFFLEN
.import YMBUF

.import INPUT_BUFFER

.import welcome_msg
.import panic_msg
.import x_home_position
.import x_up
.import x_down
.import x_right
.import x_left
.import x_backspace
.import x_erase_display
.import x_erase_line
.import prompt

.include "sysram.h"
.endif
