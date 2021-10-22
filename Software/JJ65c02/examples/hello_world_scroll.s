.include "../minios/minios.inc"
.include "../minios/sysram.inc"
.include "../minios/lcd.inc"

; Actual start of RAM code
.segment "PROG"

main:
    LCD_writetxt scroll
    rts

.segment "RWDATA"
scroll:
    .addr c1, c2, c3, c4, c5, c6, $0000
c1: .asciiz "miniOS RAM program"
c2: .asciiz "      ---         "
c3: .asciiz "Loaded via xmodem"
c4: .asciiz "into $0300"
c5: .asciiz "and run from there."
c6: .asciiz "Pretty cool, huh?"
