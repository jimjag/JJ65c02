
.ifndef _VIA_H_
_VIA_H_ = 1


.import __IO_START__

PORTB = __IO_START__ + $20                    ; VIA port B
PORTA = __IO_START__ + $21                    ; VIA port A
DDRB =  __IO_START__ + $22                    ; Data Direction Register B
DDRA =  __IO_START__ + $23                    ; Data Direction Register A
IER =   __IO_START__ + $2e                    ; VIA Interrupt Enable Register

.endif
