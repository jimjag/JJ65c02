.setcpu "w65c02"

.export LOADINTEL

.include "minios.inc"
.include "sysram.inc"
.include "lib.inc"
.include "acia.inc"
.include "tty.inc"

STL = R1    ; Store address Low
STH = R1+1    ; Store address High
COUNTER = Z2
CRC = Z3
CRCCHECK = Z4
L = Z5
EOL = Z6

IN    = YMBUF                          ; Input buffer
;-------------------------------------------------------------------------
; Load a program in Intel Hex Format.
;-------------------------------------------------------------------------

LOADINTEL:
    TTY_writeln IHEX_tstart
    ldy #$00
    ldx #$00                    ; Zero in X for use in Indexed Indirect addressing
    stz CRCCHECK                ; If CRCCHECK=0, all is good
@INTELLINE:
    jsr TTY_read_char           ; Get char
    sta IN,y                    ; Store it
    iny                         ; Next
    cmp #TTY_char_ESC           ; Escape ?
    bne @KEEPGOING
    jmp @INTELDONE              ; Yes, abort
@KEEPGOING:
    cmp #TTY_char_LF            ; Did we find a new line ?
    beq @SCAN                   ; Yes, scan line
    cmp #TTY_char_CR            ; Did we find a CR ?
    beq @SCAN                   ; Yes, scan line
    cpy #(YMBUF_SIZE-1)         ; Check that we still have space
    blt @INTELLINE              ; We have space, get next char
    lda #50                     ; wait a bit, say 5s
    jsr LIB_delay100ms
    TTY_writeln IHEX_overflow
    rts
@SCAN:
    sty EOL
    ldy #$FF                    ; Start at beginning of line
@FINDCOL:
    iny
    cpy EOL                     ; Have we reached the end of the line?
    bge @INTELLINE              ; Ignore this line then
    lda IN,y
    cmp #':'                    ; Is it Colon ?
    bne @FINDCOL                ; Nope, try next
    iny                         ; Skip colon
    stz CRC                     ; Zero Check sum
    jsr @GETHEX                 ; Get Number of bytes
    sta COUNTER                 ; Number of bytes in Counter
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    sta CRC                     ; Store it
    jsr @GETHEX                 ; Get Hi byte
    sta STH                     ; Store it
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    sta CRC                     ; Store it
    jsr @GETHEX                 ; Get Lo byte
    sta STL                     ; Store it
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    sta CRC                     ; Store it
    lda #'.'                    ; Load "."
    jsr TTY_write_char          ; Print it to indicate activity
@NODOT:
    jsr @GETHEX                 ; Get Control byte
; We assume either anything other than x01 is data - Not quite right, but so what
    cmp #$01                    ; Is it a Termination record ?
    beq @INTELDONE              ; Yes, we are done
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    sta CRC                     ; Store it
@INTELSTORE:
    jsr @GETHEX                 ; Get Data Byte
    sta (STL,x)                 ; Store it - x is always 0
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    sta CRC                     ; Store it
    inc STL                     ; Next Address
    bne @TESTCOUNT              ; Test to see if Hi byte needs INC
    inc STH                     ; If so, INC it
@TESTCOUNT:
    dec COUNTER                 ; Count down
    bne @INTELSTORE             ; Next byte
    jsr @GETHEX                 ; Get Checksum
    ldy #$00                    ; Zero Y
    clc                         ; Clear carry
    adc CRC                     ; Add CRC
    bne @CHECKSUMERR            ; Checksum NOK
    jmp @INTELLINE              ; Checksum OK
@CHECKSUMERR:
    lda #$01                    ; Flag CRC error
    sta CRCCHECK                ; Store it
    jmp @INTELLINE              ; Process next line

@INTELDONE:
    lda CRCCHECK                ; Test if everything is OK
    beq @OKMESS                 ; Show OK message
    lda #50                     ; wait a bit, say 5s
    jsr LIB_delay100ms
    TTY_writeln IHEX_importnok
    rts

@OKMESS:
    lda #50                     ; wait a bit, say 5s
    jsr LIB_delay100ms
    TTY_writeln IHEX_importok
    rts

@GETHEX:
    lda IN,y                    ; Get first char
    eor #$30
    cmp #$0A
    bcc @DONEFIRST
    adc #$08
@DONEFIRST:
    asl
    asl
    asl
    asl
    sta L
    iny
    lda IN,y                    ; Get next char
    eor #$30
    cmp #$0A
    bcc @DONESECOND
    adc #$08
@DONESECOND:
    and #$0F
    ora L
    iny                         ; and setup for next
    rts

.segment "RODATA"
IHEX_tstart:      .asciiz "Start Intel Hex code Transfer."
IHEX_importok:    .asciiz "Intel Hex Imported OK."
IHEX_importnok:   .asciiz "Intel Hex Imported with checksum error."
IHEX_overflow:    .asciiz "Intel Hex Import aborted with overflow error."
