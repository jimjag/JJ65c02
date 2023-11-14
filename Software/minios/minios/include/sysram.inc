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
.importzp LCD_SPTR
.importzp USER_INPUT_PTR
.importzp TEXT_BLK
.importzp INPUT_RRPTR
.importzp INPUT_RWPTR


.import VIDEO_RAM
.import CLK_SPD
.import ISR_VECTOR

.import USER_BUFFLEN
.import SYS_TTY_BUFFER
.import RECVB

.import POSITION_MENU
.import POSITION_CURSOR

.import DDRAM
.import VRAM_OFFSETS

.import INPUT_RDBUFF

.include "sysram.h"
.endif
