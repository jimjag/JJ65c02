
.import __VIA1_START__

PORTB = __VIA1_START__ + $00                    ; VIA port B
PORTA = __VIA1_START__ + $01                    ; VIA port A
DDRB =  __VIA1_START__ + $02                    ; Data Direction Register B
DDRA =  __VIA1_START__ + $03                    ; Data Direction Register A
IER =   __VIA1_START__ + $0e                    ; VIA Interrupt Enable Register

