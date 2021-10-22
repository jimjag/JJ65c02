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

.export VIDEO_RAM
.export CLK_SPD
.export ISR_VECTOR
.export POSITION_MENU
.export POSITION_CURSOR
.export DDRAM
.export VRAM_OFFSETS

.export USER_INPUT
.export RECVB

;===================================================================

.segment "BSS"

USER_INPUT: .res UI_BUFSIZE, NULL
RECVB:      .res 132

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

MINIOS_STATUS:   .res 1
ACIA_SPTR:       .res 2
LCD_SPTR:        .res 2
TEXT_BLK:        .res 2
USER_INPUT_PTR:  .res 2

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
POSITION_MENU:      .res 1              ; initialize positions for menu and cursor in RAM
POSITION_CURSOR:    .res 1

;===================================================================

