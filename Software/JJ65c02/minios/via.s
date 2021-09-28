.include "minios.inc"
.include "via.h"
.include "lib.inc"

.export VIA_configure_ddrs
.export VIA_read_mini_keyboard

; Actual start of ROM code
.segment "CODE"

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

    lda PORTA                                   ; load current key status from VIA
    ror                                         ; normalize the input to $1, $2, $4 and $8
    and #$0f                                    ; ignore first 4 bits
    ;eor #$0f                                   ; deactivate / comment this line, if your keyboard
                                                ; is built with buttons tied normal low, when
                                                ; pushed turning high (in contrast to Ben's schematics)

    beq @waiting                                ; no
    rts

;================================================================================
;
;   VIA_configure_ddrs - configures data direction registers of the VIA chip
;
;   Expects one byte per register with bitwise setup input/output directions
;   ————————————————————————————————————
;   Preparatory Ops: .A: Byte for DDRB
;                    .X: Byte for DDRA
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

VIA_configure_ddrs:
    sta DDRB                                    ; configure data direction for port B from A reg.
    stx DDRA                                    ; configure data direction for port A from X reg.
    rts
