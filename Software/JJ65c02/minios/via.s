.include "minios.inc"
.include "via.h"
.include "lib.inc"

.export VIA_initialize
.export VIA_read_mini_keyboard
.export SND_on
.export SND_set_note
.export SND_set_octave
.export SND_off

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
    lda #%11111111                              ; set all pins on port B to output
    sta VIA1DDRB                                ; configure data direction for port B from A reg.
    lda #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    sta VIA1DDRA                                ; configure data direction for port A from X reg.
    stz VIA1SR
    stz VIA1ACR
    stz VIA1PCR
    stz VIA1T2CL
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

    lda VIA1PORTA                               ; load current key status from VIA
    ror                                         ; normalize the input to $1, $2, $4 and $8
    and #$0f                                    ; ignore first 4 bits
    ;eor #$0f                                   ; deactivate / comment this line, if your keyboard
                                                ; is built with buttons tied normal low, when
                                                ; pushed turning high (in contrast to Ben's schematics)

    beq @waiting                                ; no
    rts

;================================================================================
;
;   SND_on - Turns sound/speaker "on"
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

SND_on:
    lda #$10
    sta VIA1ACR
    rts

;================================================================================
;
;   VIA_initialize - initializes the VIA chip
;
;   ————————————————————————————————————
;   Preparatory Ops: .A contains value of "note"
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

SND_set_note:
    sta VIA1T2CL
    rts

;================================================================================
;
;   SND_set_octave - Sets the octave of the note to be played.
;                    Negative is low; 0 is mid; positive is high
;
;   ————————————————————————————————————
;   Preparatory Ops: .A contains the octave
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

SND_set_octave:
    cmp #$00
    beq @mid
    bmi @low
    lda #$55
    bra @setit
@mid:
    lda #$33
    bra @setit
@low:
    lda #$0f
@setit:
    sta VIA1SR
    rts

;================================================================================
;
;   SND_off - Turns sound/speaker "off"
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

SND_off:
    stz VIA1ACR
    rts
