
.ifndef _VIA_H_
_VIA_H_ = 1


.import __IO_START__

VIA1_PORTB =  __IO_START__ + $20                    ; I/O Port B
VIA1_PORTA =  __IO_START__ + $21                    ; I/O Port A
VIA1_DDRB =   __IO_START__ + $22                    ; Data Direction Register B
VIA1_DDRA =   __IO_START__ + $23                    ; Data Direction Register A
VIA1_T2CL =   __IO_START__ + $28                    ; T2/CB2 shift rate
VIA1_T2CH =   __IO_START__ + $29                    ; T2/CB2 shift rate
VIA1_SR =     __IO_START__ + $2a                    ; Shift Register
VIA1_ACR =    __IO_START__ + $2b                    ; Auxiliary Control Register
VIA1_PCR =    __IO_START__ + $2c                    ; Peripheral Control Register
VIA1_IER =    __IO_START__ + $2e                    ; Interrupt Enable Register

VIA_up_key = $01
VIA_down_key = $02
VIA_left_key = $04
VIA_right_key = $08

SND_note_b4 = 251
SND_note_c5 = 237       ; Tenor C (aka C5)
SND_note_c5s = 224
SND_note_d5 = 211
SND_note_d5s = 199
SND_note_e5 = 188
SND_note_f5 = 177
SND_note_f5s = 167
SND_note_g5 = 157
SND_note_g5s = 149
SND_note_a5 = 140
SND_note_a5s = 132
SND_note_b5 = 124
SND_note_c6 = 117
SND_note_c6s = 111
SND_note_d6 = 104
SND_note_d6s = 99
SND_note_e6 = 93
SND_note_f6 = 87
SND_note_f6s = 82
SND_note_g6 = 77
SND_note_g6s = 73
SND_note_a6 = 69
SND_note_a6s = 65
SND_note_b6 = 61
SND_note_c7 = 59

.endif
