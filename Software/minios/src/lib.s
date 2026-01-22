.setcpu "w65c02"

.include "minios.inc"
.include "sysram.inc"
.include "console.inc"
.include "via.h"

.export LIB_delay1ms
.export LIB_delay100ms
.export LIB_bin_to_hex
.export LIB_have_serialdata
.export LIB_have_ps2data
.export LIB_flush_serbuf
.export LIB_flush_ps2buf
.export LIB_byte2str
.export LIB_short2str
.export LIB_setrambank
.export LIB_getrambank
.export LIB_PUSH
.export LIB_PULL

.export GRA_print_char
.export GRA_set_fgcolor
.export GRA_set_bgcolor

; Actual start of ROM code
.segment "CODE"

; *** Various miniOS Library (utility) and Graphics subroutines

;================================================================================
;
;   LIB_bin_to_hex: CONVERT BINARY BYTE TO HEX ASCII CHARS - THX Woz!
;
;   Slighty modified version - original from Steven Wozniak for Apple I
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte to convert
;
;   Returned Values: .A: LSN ASCII char
;                    .X: MSN ASCII char
;   ————————————————————————————————————
;
;================================================================================

LIB_bin_to_hex:
    phy
    ldy #$ff                                    ; state for output switching #TODO
    pha                                         ; save A for LSD
    lsr
    lsr
    lsr
    lsr                                         ; MSD to LSD position
    jsr @to_hex                                 ; output hex digit, using internal recursion
    pla                                         ; restore A
@to_hex:
    and #%00001111                              ; mask LSD for hex print
    ora #'0'                                    ; add '0'
    cmp #'9'+1                                  ; is it a decimal digit?
    bcc @output                                 ; yes! output it
    adc #6                                      ; add offset for letter A-F
@output:
    iny                                         ; set switch for second nibble processing
    bne @return                                 ; did we process second nibble already? yes
    tax                                         ; no
@return:
    ply
    rts

;================================================================================
;
;   LIB_delay1ms - "sleeps" for about 1ms
;
;   The routine does not actually sleep, but delays by burning cycles in TWO(!)
;   nested loops. The user must configure the number 1ms delays in .A
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing the sleep duration
;
;   Returned Values: none
;
;   Destroys:       none
;   ————————————————————————————————————
;
;================================================================================

LIB_delay1ms:
    pha
    phx                                         ; save .X
    phy                                         ; and .Y
@sleep_3:
    ldy CLK_SPD
@sleep_2:
    ldx #142
@sleep_1:
    nop                                         ; 2 cycles
    dex                                         ; 2 cycles
    bne @sleep_1                                ; 3 cycles
    dey
    bne @sleep_2
    dec                                         ; dec .A !
    bne @sleep_3
    ply
    plx
    pla
    rts


;================================================================================
;
;   LIB_delay100ms - "sleeps" for about 100ms
;
;   The user must configure the number 100ms delays in .A
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing the sleep duration
;
;   Returned Values: none
;
;   Destroys:       none
;   ————————————————————————————————————
;
;================================================================================

LIB_delay100ms:
    pha
    phx
    tax
@loop:
    lda #100
    jsr LIB_delay1ms
    dex
    bne @loop
    plx
    pla
    rts

;================================================================================
;
;   LIB_have_serialdata - Carry Set if we have Serial READ data in buffer,
;   Clear otherwise
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LIB_have_serialdata:
    lda SERIN_WPTR
    cmp SERIN_RPTR
    beq @no_data_found
    sec
    rts
@no_data_found:
    clc
    rts

;================================================================================
;
;   LIB_flush_serbuf - "Flush" the serial read buffer
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .X
;   ————————————————————————————————————
;
;================================================================================

LIB_flush_serbuf:
    ldx #0
@flush:
    stz INPUT_BUFFER,x
    inx
    bpl @flush
LIB_reset_serbuf:
    stz SERIN_WPTR
    stz SERIN_RPTR
    rts

;================================================================================
;
;   LIB_flush_ps2buf - "Flush" the PS/2 read buffer
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .X
;   ————————————————————————————————————
;
;================================================================================

LIB_flush_ps2buf:
    ldx #80
@flush:
    stz INPUT_BUFFER,x
    inx
    bne @flush
LIB_reset_ps2buf:
    pha
    lda #80
    sta PS2IN_WPTR
    sta PS2IN_RPTR
    pla
    rts

;================================================================================
;
;   LIB_have_ps2data - Carry Set if we have PS/2 READ data in buffer,
;   Clear otherwise
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LIB_have_ps2data:
    lda PS2IN_WPTR
    cmp PS2IN_RPTR
    beq @no_data_found
    sec
    rts
@no_data_found:
    clc
    rts

;================================================================================
;
;   LIB_short2str - Convert and print the 2 byte value at R0 to Ascii number (eg: "2562")
;
;   ————————————————————————————————————
;   Preparatory Ops: R0
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LIB_short2str:
    sed
    stz Z2
    stz Z1
    stz Z0
    ldx #16
    ldy #0          ; Our skipped starting 0s flag
@loop:
    asl R0          ; Shift out one bit
    rol R0+1
    lda Z0          ; And add into result
    adc Z0
    sta Z0
    lda Z1          ; propagating any carry
    adc Z1
    sta Z1
    lda Z2          ; ... thru whole result
    adc Z2
    sta Z2
    dex             ; And repeat for next bit
    bne @loop
    cld             ; Back to binary

    lda Z2          ; 10k place
    and #%00001111
    adc #'0'
    cmp #'0'
    bne @w10000
    ldy #1          ; We have skipped a zero
    bra @thou
@w10000:
    jsr CON_write_byte

@thou:
    lda Z1          ; 1k place
    pha
    lsr
    lsr
    lsr
    lsr
    adc #'0'
    cpy #1          ; Are we still checking for starting 0s?
    bne @w1000
    cmp #'0'
    beq @hund
    ldy #0
@w1000:
    jsr CON_write_byte

@hund:
    pla             ; 100s place
    and #%00001111
    adc #'0'
    cpy #1          ; Still??
    bne @w100
    cmp #'0'
    beq @tens
    ldy #0
@w100:
    jsr CON_write_byte

@tens:
    lda Z0          ; 10s place
    pha
    lsr
    lsr
    lsr
    lsr
    adc #'0'
    cpy #1          ; C'mon!
    bne @w10
    cmp #'0'
    beq @ones
@w10:
    jsr CON_write_byte

@ones:
    pla             ; 1s place
    and #%00001111
    adc #'0'        ; Write no matter what
    jmp CON_write_byte
    ;rts

;================================================================================
;
;   LIB_byte2str - Convert and print the 1 byte value at R0 to Ascii number (eg: "254")
;
;   ————————————————————————————————————
;   Preparatory Ops: R0
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y, Z0, Z1
;   ————————————————————————————————————
;
;================================================================================

LIB_byte2str:
    sed
    stz Z1
    stz Z0
    stz R0+1
    ldx #8
    ldy #0          ; Our skipped starting 0s flag
@loop:
    asl R0          ; Shift out one bit
    rol R0+1
    lda Z0          ; And add into result
    adc Z0
    sta Z0
    lda Z1          ; propagating any carry
    adc Z1
    sta Z1
    dex             ; And repeat for next bit
    bne @loop
    cld             ; Back to binary

    lda Z1             ; 100s place
    and #%00001111
    adc #'0'
    cmp #'0'
    bne @w100
    ldy #1
    bra @tens
@w100:
    jsr CON_write_byte

@tens:
    lda Z0          ; 10s place
    pha
    lsr
    lsr
    lsr
    lsr
    adc #'0'
    cpy #1          ; C'mon!
    bne @w10
    cmp #'0'
    beq @ones
@w10:
    jsr CON_write_byte

@ones:
    pla             ; 1s place
    and #%00001111
    adc #'0'        ; Write no matter what
    jmp CON_write_byte
    ;rts

;================================================================================
;
;   LIB_setrambank - Set the RAM bank value
;   LIB_getrambank - Get current RAM bank value in .A
;
;   ————————————————————————————————————
;   Preparatory Ops: .A
;
;   Returned Values: none
;
;   Destroys: .A (LIB_getrambank)
;   ————————————————————————————————————
;
;================================================================================

LIB_setrambank:
    sta BANK_NUM
    sta VIA1_PORTB
    rts

LIB_getrambank:
    lda BANK_NUM
    rts

;================================================================================
;
;   GRA_print_char - Print out the character stored in GCHAR (R0)
;       "ESC[Z;<c>Z"
;   ————————————————————————————————————
;   Preparatory Ops: GCHAR
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================
GRA_print_char:
    CON_writeln x_escZ_prefix
    lda #';'
    jsr CON_write_byte
    jsr LIB_byte2str
    lda #'Z'
    jmp CON_write_byte
    ;rts

;================================================================================
;
;   GRA_set_fgcolor:
;       "ESC[Z8;<color>Z"
;   ————————————————————————————————————
;   Preparatory Ops: GCOLOR (R0)
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================
GRA_set_fgcolor:
    CON_writeln x_escZ_prefix
    lda #'8'
    jsr CON_write_byte
    lda #';'
    jsr CON_write_byte
    jsr LIB_byte2str
    lda #'Z'
    jmp CON_write_byte
    ;rts

;================================================================================
;
;   GRA_set_bgcolor:
;       "ESC[Z9;<color>Z"
;   ————————————————————————————————————
;   Preparatory Ops: GCOLOR (R0)
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================
GRA_set_bgcolor:
    CON_writeln x_escZ_prefix
    lda #'9'
    jsr CON_write_byte
    lda #';'
    jsr CON_write_byte
    jsr LIB_byte2str
    lda #'Z'
    jmp CON_write_byte
    ;rts

;================================================================================
; Our Mini Extra Stack
;   Push or Pull A to the mini stack
LIB_PUSH:
    phy
    pha
    ldy MESP
    sta MES,y
    iny
    tya
    and #$0f
    sta MESP
    pla
    ply
    rts

LIB_PULL:
    phy
    ldy MESP
    dey
    tya
    and #$0f
    tay
    sty MESP
    lda MES,y
    ply
    rts
