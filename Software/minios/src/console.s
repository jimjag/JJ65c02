.setcpu "w65c02"

.include "minios.inc"
.include "sysram.inc"
.include "lib.inc"
.include "tty.h"
.include "console.h"

.export CON_init
.export CON_read_byte
.export CON_read_byte_blk
.export CON_write_byte
.export CON_write_string
.export CON_reset_user_input
.export CON_read_blk_write_byte


; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   CON_init - Setup PS/2 buffer
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

;================================================================================
;
;   CAN_read_byte_blk - Return one byte from RX buffer in .A. Block until we have it
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

CON_read_byte_blk:
@tryagain:
    jsr LIB_have_ps2data
    bcc @tryagain
    jmp CON_read_byte

;================================================================================
;
;   CON_reset_user_input - clean out console input buffer
;
;   ————————————————————————————————————
;   Preparatory Ops: USER_INPUT_PTR, UI_BUFSIZE must be set
;
;   Returned Values: none
;
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

CON_reset_user_input:
    ldy #0
@clear_user_input_loop:
    lda #TTY_char_NULL
    sta (USER_INPUT_PTR),y      ; Zero it out
    cpy USER_BUFFLEN
    beq @reset_user_input_done
    iny
    bra @clear_user_input_loop
@reset_user_input_done:
    ; reset pointers
    lda #$80
    sta PS2IN_RPTR
    sta PS2IN_WPTR
    rts

;================================================================================
;
;   CON_write_byte - Write one byte to PICO/VGA
;
;   ————————————————————————————————————
;   Preparatory Ops: .A input in accumulator
;
;   Returned Values: none
;
;   Destroys:        .none
;   ————————————————————————————————————
;
;================================================================================

CON_write_byte:
    sta PICO_ADDR
    rts

;================================================================================
;
;   CON_write_string - Write null-terminated string
;
;   ————————————————————————————————————
;   Preparatory Ops: CON_SPTR, CON_SPTR+1 string pointer
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

CON_write_string:
    pha
    phx
    phy
    ldy #$00
@string_loop:
    lda (CON_SPTR),y
    beq @end_loop
    jsr CON_write_byte
    iny
    beq @cross_page
    bne @string_loop
@cross_page:
    inc CON_SPTR+1
    bra @string_loop
@end_loop:
    ply
    plx
    pla
    rts

;================================================================================

CON_read_blk_write_byte:
    jsr CON_read_byte_blk
    jsr CON_write_byte
    sec
    rts
