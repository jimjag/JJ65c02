.include "minios.inc"
.include "via.h"
.include "lib.inc"
.include "sound.h"

.export SND_on
.export SND_set_note
.export SND_set_octave
.export SND_off

; Actual start of ROM code
.segment "CODE"

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
    sta VIA1_ACR
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
    sta VIA1_T2CL
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
    sta VIA1_SR
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
    stz VIA1_ACR
    rts
