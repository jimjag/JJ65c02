.include "minios.inc"
.include "sysram.inc"

.import CLK_SPD

.export LIB_delay1ms
.export LIB_delay100ms
.export LIB_bin_to_hex
.export LIB_have_serialdata
.export LIB_flush_serbuf
.export LIB_reset_rbuff

; Actual start of ROM code
.segment "CODE"

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
    ora #'0'                                    ; add "0"
    cmp #'9'+1                                  ; is it a decimal digit?
    bcc @output                                 ; yes! output it
    adc #6                                      ; add offset for letter A-F
@output:
    iny                                         ; set switch for second nibble processing
    bne @return                                 ; did we process second nibble already? yes
    tax                                         ; no
@return:
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

