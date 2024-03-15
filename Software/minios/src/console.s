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
;   CON_readln - read up to $USER_BUFFLEN chars from serial input and store in buffer
;              NOTE: We do NOT echo any rec'd chars back to the console
;
;   ————————————————————————————————————
;   Preparatory Ops: .A is Lo Address of buffer; .X is high; .Y is size of buffer
;
;   Returned Values: none
;
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

;
CON_readln:
    sta USER_INPUT_PTR          ; Lo address
    stx USER_INPUT_PTR+1        ; Hi address
    sty USER_BUFFLEN
    jsr CON_reset_user_input
    dec USER_BUFFLEN
    ldy #$00                    ; Counter used for tracking where we are in buffer
@read_next:
    jsr CON_read_byte
@enter_pressed:
    cmp #(TTY_char_CR)           ; User pressed enter?
    beq @read_done               ; Yes, don't save the CR
    cmp #(TTY_char_BS)
    beq @is_backspace
    cmp #(TTY_char_DEL)
    bne @save_char
@is_backspace:
    cpy #$00                     ; Already at the start of the buffer?
    beq @read_next               ; Yep
    dey                          ; Back up a position in our buffer, need to check for $00
    lda #(TTY_char_NULL)
    sta (USER_INPUT_PTR),y       ; Delete the character in our buffer
    bra @read_next               ; Get the next character
@save_char:
    sta (USER_INPUT_PTR),y       ; And save it
    cpy USER_BUFFLEN             ; Our char buffer full? (incl null)
    beq @read_done               ; Yes, get out of here
    iny                          ; Otherwise, move to the next position in the buffer
    bra @read_next               ; And read the next key
@read_done:
    iny                          ; Add a NULL in the next position
    lda #(TTY_char_NULL)
    sta (USER_INPUT_PTR),y       ; Make sure the last char is null
    rts

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
    lda #(TTY_char_NULL)
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
