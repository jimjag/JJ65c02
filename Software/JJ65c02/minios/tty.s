.include "minios.inc"
.include "acia.inc"
.include "tty.h"

.export TTY_setup_term
.export TTY_read
.export TTY_clear_screen
.export TTY_reset_user_input
.export welcome_msg

UI_BUFSIZE = $20

.segment "ZEROPAGE"

user_input_ptr: .res 2

.segment "BSS"

user_input: .res UI_BUFSIZE, NULL

.segment "RODATA"
;
; xterm control sequences
; https://www.xfree86.org/current/ctlseqs.html
;
x_set_bold:             .byte ESC,"[1m",NULL
x_set_underlined:       .byte ESC,"[4m",NULL
x_set_normal:           .byte ESC,"[22m",NULL
x_set_not_underlined:   .byte ESC,"[24m",NULL
x_set_bg_blue:          .byte ESC,"[44m",NULL
x_set_fg_white:         .byte ESC,"[37m",NULL

; Cursor
x_home_position:        .byte ESC,"[H",NULL
x_left:                 .byte ESC,"[D",NULL
x_backspace:            .byte ESC,"[D",SPACE,ESC,"[D", NULL

; Erasing
x_erase_display:        .byte ESC,"[2J", NULL
x_erase_line:           .byte ESC,"[2K", NULL

; Other
new_line:               .asciiz "\n\r"
prompt:                 .asciiz "OK> "

; Messages
welcome_msg:    .asciiz "Welcome to miniOS\n\n\r"
panic_msg:      .asciiz "!PANIC!\n\r"

.segment "CODE"

TTY_setup_term:
    jsr TTY_clear_screen
    rts 

; Code below has been cribbed from
; https://www.grappendorf.net/projects/6502-home-computer/acia-serial-interface-hello-world.html

TTY_read:
    pha 
    phy 
    lda #<user_input
    sta user_input_ptr          ; Lo address
    lda #>user_input
    sta user_input_ptr+1        ; Hi address
    ldy #$00                    ; Counter used for tracking where we are in buffer
@read_next:
    lda ACIA_STATUS
    and #$08
    beq @read_next
    lda ACIA_DATA
@enter_pressed:
    cmp #CR                      ; User pressed enter?
    beq @read_done               ; Yes, don't save the CR
@is_backspace:
    cmp #BS
    bne @echo_char               ; Nope
    cpy #$00                     ; Already at the start of the buffer?
    beq @read_next               ; Yep
    ACIA_writeln x_backspace     ; left, space, left to delete the character
    dey                          ; Back up a position in our buffer, need to check for $00
    lda #NULL
    sta (user_input_ptr),y       ; Delete the character in our buffer
    bra @read_next               ; Get the next character
@echo_char:
    sta ACIA_DATA                ; Otherwise, echo the char
@save_char:
    sta (user_input_ptr),y       ; And save it
    cpy #$0e                     ; Our 16 char buffer full? (incl null)
    beq @read_done               ; Yes, get out of here
    iny                          ; Otherwise, move to the next position in the buffer
    bra @read_next               ; And read the next key
@read_done:
    iny                          ; Add a NULL in the next position
    lda #NULL
    sta (user_input_ptr),y       ; Make sure the last char is null
    ACIA_writeln new_line
    ply 
    pla 
    rts 


TTY_clear_screen:
    ACIA_writeln x_set_fg_white
    ACIA_writeln x_set_bg_blue
    ACIA_writeln x_home_position
    ACIA_writeln x_erase_display
    ACIA_writeln x_set_normal        ; Reset to a normal font
    ACIA_writeln x_set_not_underlined 
    rts 

TTY_reset_user_input:
    pha
    lda #<user_input
    sta user_input_ptr
    lda #>user_input
    sta user_input_ptr+1        ; Point or repoint at our user_input array
    ldy #$00
@clear_user_input_loop:
    lda #NULL
    sta (user_input_ptr), y     ; Zero it out
    cpy #(UI_BUFSIZE)           ; 32 bytes in user_input
    beq @reset_user_input_done
    iny
    bra @clear_user_input_loop
@reset_user_input_done:
    pla
    rts

