.include "lcd.h"
.include "tty.h"

;
; System variables intended to be global
;
.exportzp Z0
.exportzp Z1
.exportzp Z2
.exportzp Z3
.exportzp Z4
.exportzp Z5
.exportzp Z6
.exportzp Z7
.exportzp MINIOS_STATUS
.exportzp ACIA_SPTR
.exportzp LCD_SPTR
.exportzp USER_INPUT_PTR
.exportzp TEXT_BLK
.exportzp INPUT_RRPTR
.exportzp INPUT_RWPTR

.export VIDEO_RAM
.export CLK_SPD
.export ISR_VECTOR
.export POSITION_MENU
.export POSITION_CURSOR
.export DDRAM
.export VRAM_OFFSETS

.export USER_BUFFLEN
.export SYS_TTY_BUFFER
.export RECVB

.export INPUT_RDBUFF

;===================================================================

.segment "ZEROPAGE"

Z0:     .res 1
Z1:     .res 1
Z2:     .res 1
Z3:     .res 1
Z4:     .res 1
Z5:     .res 1
Z6:     .res 1
Z7:     .res 1

MINIOS_STATUS:  .res 1      ; miniOS Status Register
INPUT_RRPTR:     .res 1      ; Read index pointer
INPUT_RWPTR:     .res 1      ; Write index point
ACIA_SPTR:      .res 2      ; String pointer - ACIA/TTY I/O
LCD_SPTR:       .res 2      ; String pointer - LCD I/O
TEXT_BLK:       .res 2      ; Scrollable text pointer
USER_INPUT_PTR: .res 2      ; buffer pointer

;===================================================================

.segment "RODATA"

DDRAM:
    .byte $00
    .byte $40
    .byte LCD_COLS
    .byte $40+LCD_COLS
VRAM_OFFSETS:
    .byte 0, LCD_COLS, 2*LCD_COLS, 3*LCD_COLS, 4*LCD_COLS, 5*LCD_COLS
    .byte 6*LCD_COLS, 7*LCD_COLS, 8*LCD_COLS, 9*LCD_COLS, 10*LCD_COLS

;===================================================================

.segment "SYSRAM"

VIDEO_RAM:      .res LCD_SIZE       ; Video RAM for 80 char (max) LCD display
CLK_SPD:        .res 1              ; Clock speed, in MHz
ISR_VECTOR:     .res 2              ; Store true ISR vector
POSITION_MENU:      .res 1          ; initialize positions for menu and cursor in RAM
POSITION_CURSOR:    .res 1
USER_BUFFLEN:     .res 1
SYS_TTY_BUFFER:    .res SYS_TTY_BUFFERLEN
RECVB:          .res 132
INPUT_RDBUFF:    .res    $FF

;===================================================================

