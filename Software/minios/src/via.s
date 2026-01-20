.setcpu "w65c02"

.include "minios.inc"
.include "sysram.inc"
.include "via.h"
.include "lib.inc"

.export VIA_init
.export VIA_ihandler

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   VIA_init - initializes the VIA chip
;              Setup read interrupt on VIA CA1/CA2

;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

VIA_init:
    ; Basic I/O
    lda #%00000111              ; set lower 3 pins on port B to output
    sta VIA1_DDRB               ; configure data direction for port B from A reg.
    stz VIA1_DDRA               ; Port A are all input
    stz VIA1_SR                 ; clear all others
    stz VIA1_ACR
    stz VIA1_PCR
    stz VIA1_T2CL
    stz VIA1_T2CH
    lda VIA1_PCR                ; Clear Flags
    and #$0f
    ora #(VIA_PCR_CA1_INTERRUPT_POSITIVE)
    sta VIA1_PCR
    lda #(VIA_IER_SET_FLAGS | VIA_IER_CA1_FLAG) ; Enable interrupt on CA1
    sta VIA1_IER
    rts

;================================================================================
;
;   CON_ihandler - IRQ Handler
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

VIA_ihandler:
    pha
    phx
    lda VIA1_PORTA
    ldx PS2IN_WPTR
    sta INPUT_BUFFER,x          ; Store in rx buffer
    inc PS2IN_WPTR              ; Increase write buffer pointer
    bmi @done
    lda #$80
    sta PS2IN_WPTR
@done:
    plx
    pla
    rts
