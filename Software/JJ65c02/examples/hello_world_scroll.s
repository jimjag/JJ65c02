.include "minios.inc"
.include "sysram.inc"
.include "lcd.inc"

; Actual start of RAM code
.segment "PROG"

main:
    LCD_writetxt scroll         ; function import done above
    rts

.segment "RWDATA"
scroll:
    .addr c1, c2, c3, c4, c5, c6, $0000
c1: .asciiz "miniOS RAM program"
c2: .asciiz "      ---         "
c3: .asciiz "Loaded via ymodem"
c4: .asciiz "into $0500"
c5: .asciiz "and run from there."
c6: .asciiz "Pretty cool, huh?"
