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
.exportzp R0
.exportzp R1
.exportzp R2
.exportzp R3
.exportzp R4
.exportzp R5
.exportzp R6
.exportzp R7
.exportzp MINIOS_STATUS
.exportzp ACIA_SPTR
.exportzp CON_SPTR
.exportzp USER_INPUT_PTR
.exportzp SERIN_RPTR
.exportzp SERIN_WPTR
.exportzp PS2IN_RPTR
.exportzp PS2IN_WPTR
.exportzp YMBLPTR
.exportzp YMEOFP
.exportzp GX0
.exportzp GY0
.exportzp GX1
.exportzp GY1
.exportzp GW0
.exportzp GH0
.exportzp GR0
.exportzp GCOLOR
.exportzp GCHAR
.exportzp GSND


.export CLK_SPD
.export BANK_NUM
.export ISR_VECTOR

.export USER_BUFFLEN
.export YMBUF

.export INPUT_BUFFER

;===================================================================

.segment "ZEROPAGE"

; Scratch space: 8bit vars
Z0:     .res 1
Z1:     .res 1
Z2:     .res 1
Z3:     .res 1
Z4:     .res 1
Z5:     .res 1
Z6:     .res 1
Z7:     .res 1

; 16bit "registers" - Argument/parameter storage (use instead of stack)
R0:     .res 2
R1:     .res 2
R2:     .res 2
R3:     .res 2
R4:     .res 2
R5:     .res 2
R6:     .res 2
R7:     .res 2

; The below are for the interface to the Pi Pico graphics. We re-use
; space for those commands that don't share variables
GX0 =           R0      ; X0 coordinate
GY0 =           R1      ; Y0 coordinate
GX1 =           R2
GY1 =           R3
GW0 =           GX1     ; Width0 value
GH0 =           GY1     ; Height0 value
GR0 =           R4      ; Radius0 value
GCOLOR =        R0      ; Color value
GCHAR =         R0      ; Graphics character byte to "draw"
GSND =          R0      ; Sound command

; General
MINIOS_STATUS:  .res 1   ; miniOS Status Register
SERIN_RPTR:     .res 1   ; Read index pointer (0x00->0x7f)
SERIN_WPTR:     .res 1   ; Write index pointer (0x00->0x7f)
PS2IN_RPTR:     .res 1   ; PS/2 Keyboard Read index pointer (0x80->0xff)
PS2IN_WPTR:     .res 1   ; PS/2 Keyboard Write index pointer (0x80->0xff)
ACIA_SPTR:      .res 2   ; String pointer - ACIA/TTY I/O
CON_SPTR:       .res 2   ; String pointer - Console I/O
USER_INPUT_PTR: .res 2   ; buffer pointer
YMBLPTR:        .res 2   ; data pointer (two byte variable)
YMEOFP:         .res 2   ; end of file address pointer (2 bytes)

;===================================================================

.segment "SYSRAM"

INPUT_BUFFER:   .res $FF    ; Used for both Serial (0x00-0x7f) and PS/2 input (0x80-0xff)
CLK_SPD:        .res 1      ; Clock speed, in MHz
BANK_NUM:       .res 1      ; Current RAM bank number in use
ISR_VECTOR:     .res 2      ; Store true ISR vector
USER_BUFFLEN:   .res 1
YMBUF:          .res 132    ; storage for XMODEM. 128bytes buffer + overhead

;===================================================================

.export welcome_msg
.export panic_msg
.export x_escZ_prefix
.export x_home_position
.export x_up
.export x_down
.export x_right
.export x_left
.export x_backspace
.export x_erase_display
.export x_erase_line
.export prompt
.export new_line
.export x_set_bg_black
.export x_set_fg_green


.segment "RODATA"
;
; xterm control sequences
; https://www.xfree86.org/current/ctlseqs.html
;

x_escZ_prefix:          .byte TTY_char_ESC,"[Z",TTY_char_NULL
x_reset:                .byte TTY_char_ESC,"[0m",TTY_char_NULL
x_set_bold:             .byte TTY_char_ESC,"[1m",TTY_char_NULL
x_set_underlined:       .byte TTY_char_ESC,"[4m",TTY_char_NULL
x_set_normal:           .byte TTY_char_ESC,"[22m",TTY_char_NULL
x_set_not_underlined:   .byte TTY_char_ESC,"[24m",TTY_char_NULL
x_set_bg_black:         .byte TTY_char_ESC,"[40m",TTY_char_NULL
x_set_fg_green:         .byte TTY_char_ESC,"[32m",TTY_char_NULL

; Cursor
x_home_position:        .byte TTY_char_ESC,"[H",TTY_char_NULL
x_up:                   .byte TTY_char_ESC,"[A",TTY_char_NULL
x_down:                 .byte TTY_char_ESC,"[B",TTY_char_NULL
x_right:                .byte TTY_char_ESC,"[C",TTY_char_NULL
x_left:                 .byte TTY_char_ESC,"[D",TTY_char_NULL
x_backspace:            .byte TTY_char_ESC,"[D",TTY_char_SPACE,TTY_char_ESC,"[D",TTY_char_NULL

; Erasing
x_erase_display:        .byte TTY_char_ESC,"[2J", TTY_char_NULL
x_erase_line:           .byte TTY_char_ESC,"[2K", TTY_char_NULL

; Other
new_line:               .asciiz "\r\n"
prompt:                 .asciiz "OK> "

; Messages
welcome_msg:    .asciiz "Welcome to miniOS\r\n\r\n"
panic_msg:      .asciiz "!PANIC!\r\n"
