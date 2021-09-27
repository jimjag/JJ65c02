.FEATURE leading_dot_in_identifiers
.setcpu "65C02"
.MACPACK generic

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;
;                                      v0.7
;
;   miniOS: RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Updated by Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;   Credits:
;               - Jan Roesner <jan@roesner.it>     Original Sixty/5o2 project
;               - Ben Eater                        (Project 6502)
;               - Steven Wozniak                   (bin2hex routine)
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $022f      RAM: miniOS set-aside / Page 2
;      . $0260 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8000 - $8fff      IO Blk: 4K
;    $9000 - $9fff      VIA1: 4K
;    $a000 - $ffff      ROM: 24K
;--------


PORTB = $9000                                   ; VIA port B
PORTA = $9001                                   ; VIA port A
DDRB = $9002                                    ; Data Direction Register B
DDRA = $9003                                    ; Data Direction Register A
IER = $900e                                     ; VIA Interrupt Enable Register

E =  %10000000
RW = %01000000
RS = %00100000

DEBOUNCE = 15                                   ; 150ms seems about right

Z0 = $00                                        ; General purpose ZP memory locations
Z1 = $01
Z2 = $02
Z3 = $03

LCD_COLS = 20
LCD_ROWS = 4
LCD_SIZE = LCD_COLS * LCD_ROWS
LCD_LASTIDX = LCD_SIZE - 1
VIDEO_RAM = $0210                               ; $0210 - $025f - Video RAM for 80 char (max) LCD display
POSITION_MENU = $0204                           ; initialize positions for menu and cursor in RAM
POSITION_CURSOR = $0205
CLK_SPD = $0200                                 ; Clock speed, in MHz
ISR_FIRST_RUN = $0203                           ; used to determine first run of the ISRD
ISR_VECTOR = $0206                              ; Store true ISR vector ($0206, $0207)

PROGRAM_START = $0260                           ; memory location for user programs
PROGRAM_END = $8000                             ; End of RAM

CURRENT_RAM_ADDRESS = Z0                        ; a RAM address handle for indirect writing
CURRENT_RAM_ADDRESS_L = Z0
CURRENT_RAM_ADDRESS_H = Z1

LOADING_STATE = Z2
