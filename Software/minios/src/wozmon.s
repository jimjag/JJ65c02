
.setcpu "65c02"

.export WOZMON

.include "minios.inc"
.include "sysram.inc"
.include "console.inc"

.segment "ZEROPAGE"
; WOZMON vars
XAML:  .res 1   ; Last "opened" location Low
XAMH:  .res 1   ; Last "opened" location High
STL:  .res 1    ; Store address Low
STH:  .res 1    ; Store address High
L:  .res 1      ; Hex value parsing Low
H:  .res 1      ; Hex value parsing High
YSAV:  .res 1   ; Used to see if hex value is given
MODE:  .res 1   ; $00=XAM, $7F=STOR, $AE=BLOCK XAM

IN    = YMBUF                          ; Input buffer

.segment "CODE"
WOZMON:
    CON_writeln new_line
    cld                ; just in case
    lda #$A7
    ldy #$7F

@NOTCR:
    cmp #$08           ; Backspace key?
    beq @BACKSPACE     ; Yes.
    cmp #$1B           ; ESC?
    beq @ESCAPE        ; Yes.
    cmp #'Q'           ; Quit?
    bne @NOQUIT
    jmp @ECHO
@NOQUIT:
    iny                ; Advance text index.
    bpl @NEXTCHAR      ; Auto ESC if line longer than 127.

@ESCAPE:
    lda #'\'           ; "\".
    jsr @ECHO          ; Output it.

@GETLINE:
    lda #$0D           ; Send CR
    jsr @ECHO

    ldy #$01           ; Initialize text index.
@BACKSPACE:
    dey                ; Back up text index.
    bmi @GETLINE       ; Beyond start of line, reinitialize.

@NEXTCHAR:
    jsr CON_read_byte_blk
    ; TODO: Convert lower case to upper case, internally
    sta IN,Y           ; Add to text buffer.
    jsr @ECHO          ; Display character.
    cmp #$0D           ; CR?
    bne @NOTCR         ; No.

    ldy #$FF           ; Reset text index.
    lda #$00           ; For XAM mode.
    tax                ; X=0.
@SETBLOCK:
    asl
@SETSTOR:
    asl                ; Leaves $7B if setting STOR mode.
    sta MODE           ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.
@BLSKIP:
    iny                ; Advance text index.
@NEXTITEM:
    lda IN,Y           ; Get character.
    cmp #$0D           ; CR?
    beq @GETLINE       ; Yes, done this line.
    cmp #'.'           ; "."?
    bcc @BLSKIP        ; Skip delimiter.
    beq @SETBLOCK      ; Set BLOCK XAM mode.
    cmp #':'           ; ":"?
    beq @SETSTOR       ; Yes, set STOR mode.
    cmp #'R'           ; "R"?
    beq @RUN           ; Yes, run user program.
    stx L              ; $00 -> L.
    stx H              ;    and H.
    sty YSAV           ; Save Y for comparison

@NEXTHEX:
    lda IN,Y           ; Get character for hex test.
    eor #'0'           ; Map digits to $0-9.
    cmp #$0A           ; Digit?
    bcc @DIG           ; Yes.
    adc #$88           ; Map letter "A"-"F" to $FA-FF.
    cmp #$FA           ; Hex letter?
    bcc @NOTHEX        ; No, character not hex.
@DIG:
    asl
    asl                ; Hex digit to MSD of A.
    asl
    asl

    ldx #$04           ; Shift count.
@NEXTSHIFT:
    asl                ; Hex digit left, MSB to carry.
    rol L              ; Rotate into LSD.
    rol H              ; Rotate into MSD's.
    dex                ; Done 4 shifts?
    bne @NEXTSHIFT     ; No, loop.
    iny                ; Advance text index.
    bne @NEXTHEX       ; Always taken. Check next character for hex.

@NOTHEX:
    cpy YSAV           ; Check if L, H empty (no hex digits).
    beq @ESCAPE        ; Yes, generate ESC sequence.

    bit MODE           ; Test MODE byte.
    bvc @NOTSTOR       ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

    lda L              ; LSD's of hex data.
    sta (STL,X)        ; Store current 'store index'.
    inc STL            ; Increment store index.
    bne @NEXTITEM      ; Get next item (no carry).
    inc STH            ; Add carry to 'store index' high order.
@TONEXTITEM:
    jmp @NEXTITEM      ; Get next command item.

@RUN:
    jmp (XAML)         ; Run at current XAM index.

@NOTSTOR:
    bmi @XAMNEXT       ; B7 = 0 for XAM, 1 for BLOCK XAM.

    ldx #$02           ; Byte count.
@SETADR:
    lda L-1,X          ; Copy hex data to
    sta STL-1,X        ;  'store index'.
    sta XAML-1,X       ; And to 'XAM index'.
    dex                ; Next of 2 bytes.
    bne @SETADR        ; Loop unless X = 0.

@NXTPRNT:
    bne @PRDATA        ; NE means no address to print.
    lda #$0D           ; CR.
    jsr @ECHO          ; Output it.
    lda XAMH           ; 'Examine index' high-order byte.
    jsr @PRBYTE        ; Output it in hex format.
    lda XAML           ; Low-order 'examine index' byte.
    jsr @PRBYTE        ; Output it in hex format.
    lda #$3A           ; ":".
    jsr @ECHO          ; Output it.

@PRDATA:
    lda #' '           ; Blank.
    jsr @ECHO          ; Output it.
    lda (XAML,X)       ; Get data byte at 'examine index'.
    jsr @PRBYTE        ; Output it in hex format.
@XAMNEXT:
    stx MODE           ; 0 -> MODE (XAM mode).
    lda XAML
    cmp L              ; Compare 'examine index' to hex data.
    lda XAMH
    sbc H
    bcs @TONEXTITEM    ; Not less, so no more data to output.

    inc XAML
    bne @MOD8CHK       ; Increment 'examine index'.
    inc XAMH

@MOD8CHK:
    lda XAML           ; Check low-order 'examine index' byte
    and #$0F           ; For MOD 8 = 0 (Actually, MOD 16)
    bpl @NXTPRNT       ; Always taken.

@PRBYTE:
    pha                ; Save A for LSD.
    lsr
    lsr
    lsr                ; MSD to LSD position.
    lsr
    jsr @PRHEX         ; Output hex digit.
    pla                ; Restore A.

@PRHEX:
    and #$0F           ; Mask LSD for hex print.
    ora #'0'           ; Add "0".
    cmp #$3A           ; Digit?
    bcc @ECHO          ; Yes, output it.
    adc #$06           ; Add offset for letter.

@ECHO:
    ; Auto convert CR to CRLF
    jsr CON_write_byte
    cmp #$0D
    bne @WEDONE
    lda #$0A
    jsr CON_write_byte
    lda #$0D
@WEDONE:
    rts                ; Return.
