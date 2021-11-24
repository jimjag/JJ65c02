
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

SND_note_b0 = 251
SND_note_b0s = 244      ; heh
SND_note_c = 237
SND_note_cs = 224
SND_note_d = 211
SND_note_ds = 199
SND_note_e = 188
SND_note_es = 182       ; heh
SND_note_f = 177
SND_note_fs = 167
SND_note_g = 157
SND_note_gs = 149
SND_note_a = 140
SND_note_as = 132
SND_note_b = 124
SND_note_bs = 120       ; heh
SND_note_c1 = 117
SND_note_c1s = 111
SND_note_d1 = 104
SND_note_d1s = 99
SND_note_e1 = 93
SND_note_e1s = 90       ; heh
SND_note_f1 = 87
SND_note_f1s = 82
SND_note_g1 = 77
SND_note_g1s = 73
SND_note_a1 = 69
SND_note_a1s = 65
SND_note_b1 = 61
SND_note_c2 = 59

.endif
