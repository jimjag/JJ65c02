.include "lcd.h"
.include "tty.h"

;
; System variables intended to be global
;
.exportzp Z0
.exportzp Z1
.exportzp Z2
.exportzp Z3
.exportzp Z4
.exportzp Z5
.exportzp Z6
.exportzp Z7
.exportzp MINIOS_STATUS
.exportzp ACIA_SPTR
.exportzp CON_SPTR
.exportzp USER_INPUT_PTR
.exportzp TEXT_BLK
.exportzp SERIN_RPTR
.exportzp SERIN_WPTR
.exportzp PS2IN_RPTR
.exportzp PS2IN_WPTR

.export CLK_SPD
.export ISR_VECTOR

.export USER_BUFFLEN
.export RECVB

.export INPUT_BUFFER

;===================================================================

.segment "ZEROPAGE"

Z0:     .res 1
Z1:     .res 1
Z2:     .res 1
Z3:     .res 1
Z4:     .res 1
Z5:     .res 1
Z6:     .res 1
Z7:     .res 1

MINIOS_STATUS:  .res 1      ; miniOS Status Register
SERIN_RPTR:  .res 1      ; Read index pointer (MSB = 0)
SERIN_WPTR:  .res 1      ; Write index point
PS2IN_RPTR:     .res 1      ; PS/2 Keyboard Read index pointer (MSB = 1)
PS2IN_WPTR:     .res 1      ; PS/2 Keyboard Write index point
ACIA_SPTR:      .res 2      ; String pointer - ACIA/TTY I/O
CON_SPTR:      .res 2       ; String pointer - Console I/O
USER_INPUT_PTR: .res 2      ; buffer pointer

;===================================================================

.segment "SYSRAM"

CLK_SPD:        .res 1      ; Clock speed, in MHz
ISR_VECTOR:     .res 2      ; Store true ISR vector
USER_BUFFLEN:   .res 1
RECVB:          .res 132
INPUT_BUFFER:   .res $FF    ; Used for both Serial (0x00-0x7f) and PS/2 input (0x80-0xff)

;===================================================================

.export welcome_msg

.segment "RODATA"
;
; xterm control sequences
; https://www.xfree86.org/current/ctlseqs.html
;
x_set_bold:             .byte TTY_char_ESC,"[1m",TTY_char_NULL
x_set_underlined:       .byte TTY_char_ESC,"[4m",TTY_char_NULL
x_set_normal:           .byte TTY_char_ESC,"[22m",TTY_char_NULL
x_set_not_underlined:   .byte TTY_char_ESC,"[24m",TTY_char_NULL
x_set_bg_black:         .byte TTY_char_ESC,"[40m",TTY_char_NULL
x_set_fg_green:         .byte TTY_char_ESC,"[32m",TTY_char_NULL

; Cursor
x_home_position:        .byte TTY_char_ESC,"[H",TTY_char_NULL
x_left:                 .byte TTY_char_ESC,"[D",TTY_char_NULL
x_backspace:            .byte TTY_char_ESC,"[D",TTY_char_SPACE,TTY_char_ESC,"[D", TTY_char_NULL

; Erasing
x_erase_display:        .byte TTY_char_ESC,"[2J", TTY_char_NULL
x_erase_line:           .byte TTY_char_ESC,"[2K", TTY_char_NULL

; Other
new_line:               .asciiz "\r\n"
prompt:                 .asciiz "OK> "

; Messages
welcome_msg:    .asciiz "Welcome to miniOS\r\n\r\n"
panic_msg:      .asciiz "!PANIC!\r\n"
