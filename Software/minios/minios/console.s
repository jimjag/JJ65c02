.include "minios.inc"
.include "sysram.inc"
.include "console.h"
.include "lib.inc"

.export CON_init
.export CON_read_byte

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   CON_initialize - Setup read interrupt on VIA CA1/CA2
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

CON_init:
    lda #$80
    sta PS2IN_RPTR
    sta PS2IN_WPTR
    rts

;================================================================================
;
;   CAN_read_byte - Return one byte from RX buffer in .A
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A, C flag (set if data exist, cleared if no data)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

CON_read_byte:
    jsr LIB_have_ps2data
    bcs @read_it
    clc                 ; just in case
    rts
@read_it:
    phx
    ldx PS2IN_RPTR
    lda INPUT_BUFFER,x
    inc PS2IN_RPTR
    bmi @done
    ldx #$80
    stx PS2IN_RPTR
@done:
    plx
    sec
    rts