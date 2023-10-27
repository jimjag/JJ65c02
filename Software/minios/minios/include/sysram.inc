.ifndef _SYSRAM_INC_
_SYSRAM_INC_ = 1

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $04ff      RAM: miniOS set-aside / Page 2-4
;      . $0500 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8010 - $8fff      IO Blk: 4k
;      . $8010 - $801f      ACIA:
;      . $8020 - $802f      VIA1:
;    $9000 - $ffff      ROM: 28K
;--------

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