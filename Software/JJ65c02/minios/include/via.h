
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

.endif
