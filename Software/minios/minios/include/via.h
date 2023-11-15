
.ifndef _VIA_H_
_VIA_H_ = 1


.import __IO_START__

VIA1_PORTB =  __IO_START__ + $20                    ; I/O Port B
VIA1_PORTA =  __IO_START__ + $21                    ; I/O Port A
VIA1_DDRB =   __IO_START__ + $22                    ; Data Direction Register B
VIA1_DDRA =   __IO_START__ + $23                    ; Data Direction Register A
VIA1_T1CL =   __IO_START__ + $24                    ; T1/CB1 shift rate
VIA1_T1CH =   __IO_START__ + $25                    ; T1/CB1 shift rate
VIA1_T1LL =   __IO_START__ + $26                    ; T1 lower latch
VIA1_T1LH =   __IO_START__ + $27                    ; T1 upper latch
VIA1_T2CL =   __IO_START__ + $28                    ; T2/CB2 shift rate
VIA1_T2CH =   __IO_START__ + $29                    ; T2/CB2 shift rate
VIA1_SR =     __IO_START__ + $2a                    ; Shift Register
VIA1_ACR =    __IO_START__ + $2b                    ; Auxiliary Control Register
VIA1_PCR =    __IO_START__ + $2c                    ; Peripheral Control Register
VIA1_IFR =    __IO_START__ + $2d                    ; Interrupt Flag Register
VIA1_IER =    __IO_START__ + $2e                    ; Interrupt Enable Register
VIA1_ORA =    __IO_START__ + $2e                    ; Port A - no handshake


VIA2_PORTB =  __IO_START__ + $40                    ; I/O Port B
VIA2_PORTA =  __IO_START__ + $41                    ; I/O Port A
VIA2_DDRB =   __IO_START__ + $44                    ; Data Direction Register B
VIA2_DDRA =   __IO_START__ + $43                    ; Data Direction Register A
VIA2_T1CL =   __IO_START__ + $44                    ; T1/CB1 shift rate
VIA2_T1CH =   __IO_START__ + $45                    ; T1/CB1 shift rate
VIA2_T1LL =   __IO_START__ + $46                    ; T1 lower latch
VIA2_T1LH =   __IO_START__ + $47                    ; T1 upper latch
VIA2_T4CL =   __IO_START__ + $48                    ; T2/CB2 shift rate
VIA2_T4CH =   __IO_START__ + $49                    ; T2/CB2 shift rate
VIA2_SR =     __IO_START__ + $4a                    ; Shift Register
VIA2_ACR =    __IO_START__ + $4b                    ; Auxiliary Control Register
VIA2_PCR =    __IO_START__ + $4c                    ; Peripheral Control Register
VIA2_IFR =    __IO_START__ + $4d                    ; Interrupt Flag Register
VIA2_IER =    __IO_START__ + $4e                    ; Interrupt Enable Register
VIA2_ORA =    __IO_START__ + $4e                    ; Port A - no handshake

; Peripheral Control Register flags
VIA_PCR_CA1_INTERRUPT_NEGATIVE     = %00000000
VIA_PCR_CA1_INTERRUPT_POSITIVE     = %00000001
VIA_PCR_CA2_OUTPUT_HANDSHAKE       = %00001000
VIA_PCR_CA2_OUTPUT_PULSE           = %00001010
VIA_PCR_CB1_INTERRUPT_NEGATIVE     = %00000000
VIA_PCR_CB1_INTERRUPT_POSITIVE     = %00010000
VIA_PCR_CB2_OUTPUT_LOW             = %11000000
VIA_PCR_CB2_OUTPUT_HIGH            = %11100000

; Interrupt Enable Register flags
VIA_IER_CLEAR_FLAGS                = %00000000
VIA_IER_SET_FLAGS                  = %10000000
VIA_IER_CA1_FLAG                   = %00000010
VIA_IER_CA2_FLAG                   = %00000001

.endif
