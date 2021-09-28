.include "lcd.inc"

;
; SYSRAM variables intended to be global
;
.exportzp Z0
.exportzp Z1
.exportzp Z2
.exportzp Z3
.export VIDEO_RAM
.export CLK_SPD
.export ISR_VECTOR


.segment "ZEROPAGE"

Z0:     .res 1
Z1:     .res 1
Z2:     .res 1
Z3:     .res 1

.segment "SYSRAM"
    
VIDEO_RAM:      .res LCD_SIZE       ; Video RAM for 80 char (max) LCD display
CLK_SPD:        .res 1              ; Clock speed, in MHz
ISR_VECTOR:     .res 2              ; Store true ISR vector ($0206, $0207)
