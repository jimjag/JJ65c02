.include "lcd.inc"

;
; System variables intended to be global
;
.exportzp Z0
.exportzp Z1
.exportzp Z2
.exportzp Z3
.exportzp MINIOS_STATUS
.export VIDEO_RAM
.export CLK_SPD
.export ISR_VECTOR
.export POSITION_MENU
.export POSITION_CURSOR



.segment "ZEROPAGE"

Z0:     .res 1
Z1:     .res 1
Z2:     .res 1
Z3:     .res 1
MINIOS_STATUS:   .res 1

.segment "SYSRAM"

VIDEO_RAM:      .res LCD_SIZE       ; Video RAM for 80 char (max) LCD display
CLK_SPD:        .res 1              ; Clock speed, in MHz
ISR_VECTOR:     .res 2              ; Store true ISR vector
POSITION_MENU:      .res 1              ; initialize positions for menu and cursor in RAM
POSITION_CURSOR:    .res 1
