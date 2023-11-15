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

.import VIDEO_RAM
.import CLK_SPD
.import ISR_VECTOR

.import USER_BUFFLEN
.import RECVB

.import INPUT_BUFFER

.include "sysram.h"
.endif
