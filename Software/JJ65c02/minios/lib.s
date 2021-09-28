.include "minios.inc"

.import CLK_SPD

.export LIB_delay1ms
.export LIB_delay100ms
.export LIB_bin_to_hex

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

