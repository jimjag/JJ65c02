.ifndef _TTY_H_
_TTY_H_ = 1


.feature string_escapes

; Non-visible ASCII codes
; https://www.ascii-code.com/
;
NULL    = $00   ; Null char
SOH     = $01   ; Start of Heading
STXT    = $02   ; Start of Text (STX is a valid opcode)
ETX     = $03   ; End of Text
EOT     = $04   ; End of Transmission
ENQ     = $05   ; Enquiry
ACK     = $06   ; Acknowledgement
BEL     = $07   ; Bell
;BS     = $08   ; Backspace, see DEL
HT      = $09   ; Horizontal Tab
LF      = $0A   ; Line Feed
VT      = $0B   ; Vertical Tab
FF      = $0C   ; Form Feed
CR      = $0D   ; Carriage Return
SO      = $0E   ; Shift Out / x-on
SI      = $0F   ; Shift In / X-off
DLE     = $10   ; Data Line Escape
DC1     = $11   ; Device Control 1 (often XON)
DC2     = $12   ; Device Control 2
DC3     = $13   ; Device Control 3 (often XOFF)
DC4     = $14   ; Device Control 4
NAK     = $15   ; Negative Acknowledgement
SYN     = $16   ; Synchronous Idle
ETB     = $17   ; End of Transmit Block
CAN     = $18   ; Cancel
EM      = $19   ; End of Medium
SUB     = $1A   ; Substitute
ESC     = $1B   ; Escape
FS      = $1C   ; File Separator
GS      = $1D   ; Group Separator
RS      = $1E   ; Record Separator
US      = $1F   ; Unit Separator
SPACE   = $20   ; Space
DEL     = $7F   ; Delete
BS      = $7F   ; Backspace on Mac

UI_BUFSIZE = $80

.endif
