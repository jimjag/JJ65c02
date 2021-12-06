.include "minios.inc"
.include "via.h"
.include "lib.inc"

.export VIA_initialize
.export VIA_read_mini_keyboard

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   VIA_initialize - initializes the VIA chip
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X
;   ————————————————————————————————————
;
;================================================================================

VIA_initialize:
    ; First VIA1: LCD display and mini keyboard
    lda #%11111111                              ; set all pins on port B to output
    sta VIA1_DDRB                               ; configure data direction for port B from A reg.
    lda #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    sta VIA1_DDRA                               ; configure data direction for port A from X reg.
    stz VIA1_SR                                 ; clear all others
    stz VIA1_ACR
    stz VIA1_PCR
    stz VIA1_T2CL
    stz VIA1_T2CH

    ; Now VIA2: Keyboard and sound
    stz VIA2_DDRA                               ; Port A all input (keyboard)
    stz VIA2_PORTA
    stz VIA2_PCR
    rts


;================================================================================
;
;   VIA_read_mini_keyboard - returns 4-key keyboard inputs
;
;   Input is read, normalized and returned to the caller. We wait until
;   they actually *enter* something
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A: (UP: $1, DOWN: $2, LEFT: $4, RIGHT: $8)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

VIA_read_mini_keyboard:
@waiting:
    lda #(DEBOUNCE)                             ; debounce
    jsr LIB_delay1ms                            ; ~150ms

    lda VIA1_PORTA                              ; load current key status from VIA
    ror                                         ; normalize the input to $1, $2, $4 and $8
    and #$0f                                    ; ignore first 4 bits
    ;eor #$0f                                   ; deactivate / comment this line, if your keyboard
                                                ; is built with buttons tied normal low, when
                                                ; pushed turning high (in contrast to Ben's schematics)

    beq @waiting                                ; no
    rts
