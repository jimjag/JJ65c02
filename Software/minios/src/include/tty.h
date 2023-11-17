.ifndef _TTY_H_
_TTY_H_ = 1


.feature string_escapes

; Non-visible ASCII codes
; https://www.ascii-code.com/
;
TTY_char_NULL    = $00   ; Null char
TTY_char_SOH     = $01   ; Start of Heading
TTY_char_STXT    = $02   ; Start of Text (STX is a valid opcode)
TTY_char_ETX     = $03   ; End of Text
TTY_char_EOT     = $04   ; End of Transmission
TTY_char_ENQ     = $05   ; Enquiry
TTY_char_ACK     = $06   ; Acknowledgement
TTY_char_BEL     = $07   ; Bell
TTY_char_BS      = $08   ; Backspace, see DEL
TTY_char_HT      = $09   ; Horizontal Tab
TTY_char_LF      = $0A   ; Line Feed
TTY_char_VT      = $0B   ; Vertical Tab
TTY_char_FF      = $0C   ; Form Feed
TTY_char_CR      = $0D   ; Carriage Return
TTY_char_SO      = $0E   ; Shift Out / x-on
TTY_char_SI      = $0F   ; Shift In / X-off
TTY_char_DLE     = $10   ; Data Line Escape
TTY_char_DC1     = $11   ; Device Control 1 (often XON)
TTY_char_DC2     = $12   ; Device Control 2
TTY_char_DC3     = $13   ; Device Control 3 (often XOFF)
TTY_char_DC4     = $14   ; Device Control 4
TTY_char_NAK     = $15   ; Negative Acknowledgement
TTY_char_SYN     = $16   ; Synchronous Idle
TTY_char_ETB     = $17   ; End of Transmit Block
TTY_char_CAN     = $18   ; Cancel
TTY_char_EM      = $19   ; End of Medium
TTY_char_SUB     = $1A   ; Substitute
TTY_char_ESC     = $1B   ; Escape
TTY_char_FS      = $1C   ; File Separator
TTY_char_GS      = $1D   ; Group Separator
;TTY_char_RS      = $1E   ; Record Separator
TTY_char_US      = $1F   ; Unit Separator
TTY_char_SPACE   = $20   ; Space
TTY_char_DEL     = $7F   ; Delete
;TTY_char_BS      = $7F   ; Backspace on Mac

.endif
