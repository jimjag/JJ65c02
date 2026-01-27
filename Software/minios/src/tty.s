.setcpu "w65c02"

.include "minios.inc"
.include "sysram.inc"
.include "acia.inc"
.include "tty.h"

.export TTY_setup_term
.export TTY_readln
.export TTY_clear_screen
.export TTY_reset_user_input
.export TTY_send_newline
.export TTY_send_backspace

.segment "CODE"

;================================================================================
;
;   TTY_setup_term - routine to initialize the TTY system
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

TTY_setup_term:
    jmp TTY_clear_screen
    rts

; Code below has been cribbed from
; https://www.grappendorf.net/projects/6502-home-computer/acia-serial-interface-hello-world.html

;================================================================================
;
;   TTY_read - read up to $80 chars from serial input and store in buffer:
;
;   ————————————————————————————————————
;   Preparatory Ops: .A is Lo Address of buffer; .X is high; .Y is size of buffer
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

;
TTY_readln:
    sta USER_INPUT_PTR          ; Lo address
    stx USER_INPUT_PTR+1        ; Hi address
    sty USER_BUFFLEN
    jsr TTY_reset_user_input
    dec USER_BUFFLEN
    ldy #$00                    ; Counter used for tracking where we are in buffer
@read_next:
    jsr ACIA_read_byte_blk
@enter_pressed:
    cmp #TTY_char_CR             ; User pressed enter?
    beq @read_done               ; Yes, don't save the CR
    cmp #TTY_char_BS
    beq @is_backspace
    cmp #TTY_char_DEL
    bne @echo_char
@is_backspace:
    cpy #$00                     ; Already at the start of the buffer?
    beq @read_next               ; Yep
    ACIA_writeln x_backspace     ; left, space, left to delete the character
    dey                          ; Back up a position in our buffer, need to check for $00
    lda #TTY_char_NULL
    sta (USER_INPUT_PTR),y       ; Delete the character in our buffer
    bra @read_next               ; Get the next character
@echo_char:
    jsr ACIA_write_byte          ; Otherwise, echo the char
@save_char:
    sta (USER_INPUT_PTR),y       ; And save it
    cpy USER_BUFFLEN             ; Our char buffer full? (incl null)
    beq @read_done               ; Yes, get out of here
    iny                          ; Otherwise, move to the next position in the buffer
    bra @read_next               ; And read the next key
@read_done:
    iny                          ; Add a NULL in the next position
    lda #TTY_char_NULL
    sta (USER_INPUT_PTR),y       ; Make sure the last char is null
    ACIA_writeln new_line
    rts

;================================================================================
;
;   TTY_clear_screen - clear TTY screen and set some defaults
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

TTY_clear_screen:
    ACIA_writeln x_set_bg_black
    ACIA_writeln x_set_fg_green
    ACIA_writeln x_home_position
    ACIA_writeln x_erase_display
    ;ACIA_writeln x_set_normal        ; Reset to a normal font
    ;ACIA_writeln x_set_not_underlined
    rts

;================================================================================
;
;   TTY_reset_user_input - clean out TTY input buffer
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

TTY_reset_user_input:
    ldy #0
@clear_user_input_loop:
    lda #TTY_char_NULL
    sta (USER_INPUT_PTR),y      ; Zero it out
    cpy USER_BUFFLEN
    beq @reset_user_input_done
    iny
    bra @clear_user_input_loop
@reset_user_input_done:
    rts

;;

TTY_send_newline:
    ACIA_writeln new_line
    rts

TTY_send_backspace:
    ACIA_writeln x_backspace
    rts
