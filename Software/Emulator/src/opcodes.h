#include <stdint.h>

#ifndef __6502_OPCODES__
#define __6502_OPCODES__

#define OPCODE_CYCLES(opcode) 1

// Opcode constants that have multiple addressing modes are named in the form
// X_Y, where X is the instruction and Y is the addressing mode. The possible
// addressing modes are:
//      AB:   absolute mode, next two bytes are the low/high byte of an absolute
//            memory address
//      ABX:  absolute,X, next two bytes are added to the value in register X to
//            get the memory address
//      ABY:  same as ABX, except the value of register Y is used instead of X
//      ACC:  accumulator, act on the value in the accumulator
//      IMM:  immediate, next byte is a constant to be used instead of a lookup
//      IN:   indirect, next two bytes are an absolute memory address of the
//            lower nibble of a memory address. That byte and the byte after will
//            be loaded and the address made of those two bytes will be used
//      INX:  (indirect,X) mode, add X to the following byte, modulo 0xFF, and
//            lookup two bytes starting at that location. Those two bytes form
//            the memory address that will be used
//      INY:  (indirect),Y mode, look up two bytes starting at address in the
//            following byte, add Y modulo 0xFFFF, and use the result as an
//            address
//		INZP: indirect zero-page, next byte is a memory address within the zero-page
//			  the byte at that address and the byte after it form a memory address
//			  that address is where the actual value is loaded from
//      REL:  relative, next byte contains a signed offset from the current PC.
//      ZP:   zero-page, next byte is the low bits of the memory address (can
//            only address first 256 bytes of memory using ZP)
//      ZPX:  zero-page,X, add next byte to X modulo 0xFF and use that as a
//            memory address

#define ADC_AB   0x6D
#define ADC_ABX  0x7D
#define ADC_ABY  0x79
#define ADC_IMM  0x69
#define ADC_INX  0x61
#define ADC_INY  0x71
#define ADC_ZP   0x65
#define ADC_ZPX  0x75
#define ADC_INZP 0x72

#define AND_AB   0x2D
#define AND_ABX  0x3D
#define AND_ABY  0x39
#define AND_IMM  0x29
#define AND_INX  0x21
#define AND_INY  0x31
#define AND_ZP   0x25
#define AND_ZPX  0x35
#define AND_INZP 0x32

#define ASL_AB   0x0E
#define ASL_ABX  0x1E
#define ASL_ACC  0x0A
#define ASL_ZP   0x06
#define ASL_ZPX  0x16

#define BCC_REL  0x90
#define BCS_REL  0xB0
#define BEQ_REL  0xF0

#define BIT_AB   0x2C
#define BIT_ZP   0x24

#define BMI_REL  0x30
#define BNE_REL  0xD0
#define BPL_REL  0x10

#define BRK      0x00

#define BVC_REL  0x50
#define BVS_REL  0x70

#define CLC      0x18
#define CLD      0xD8
#define CLI      0x58
#define CLV      0xB8

#define CMP_AB   0xCD
#define CMP_ABX  0xDD
#define CMP_ABY  0xD9
#define CMP_IMM  0xC9
#define CMP_INX  0xC1
#define CMP_INY  0xD1
#define CMP_ZP   0xC5
#define CMP_ZPX  0xD5
#define CMP_INZP 0xD2

#define CPX_AB   0xEC
#define CPX_IMM  0xE0
#define CPX_ZP   0xE4

#define CPY_AB   0xCC
#define CPY_IMM  0xC0
#define CPY_ZP   0xC4

#define DEC_ACC  0x3A
#define DEC_AB   0xCE
#define DEC_ABX  0xDE
#define DEC_ZP   0xC6
#define DEC_ZPX  0xD6

#define DEX      0xCA
#define DEY      0x88

#define EOR_AB   0x4D
#define EOR_ABX  0x5D
#define EOR_ABY  0x59
#define EOR_IMM  0x49
#define EOR_INX  0x41
#define EOR_INY  0x51
#define EOR_ZP   0x45
#define EOR_ZPX  0x55
#define EOR_INZP 0x52

#define INC_ACC  0x1A
#define INC_AB   0xEE
#define INC_ABX  0xFE
#define INC_ZP   0xE6
#define INC_ZPX  0xF6

#define INX      0xE8
#define INY      0xC8

#define JMP_AB   0x4C
#define JMP_ABX  0x7C
#define JMP_IN   0x6C

#define JSR_AB   0x20

#define LDA_AB   0xAD
#define LDA_ABX  0xBD
#define LDA_ABY  0xB9
#define LDA_IMM  0xA9
#define LDA_INX  0xA1
#define LDA_INY  0xB1
#define LDA_ZP   0xA5
#define LDA_ZPX  0xB5
#define LDA_INZP 0xB2

#define LDX_AB   0xAE
#define LDX_ABY  0xBE
#define LDX_IMM  0xA2
#define LDX_ZP   0xA6
#define LDX_ZPY  0xB6

#define LDY_AB   0xAC
#define LDY_ABX  0xBC
#define LDY_IMM  0xA0
#define LDY_ZP   0xA4
#define LDY_ZPX  0xB4

#define LSR_AB   0x4E
#define LSR_ABX  0x5E
#define LSR_ACC  0x4A
#define LSR_ZP   0x46
#define LSR_ZPX  0x56

#define ORA_IMM  0x09
#define ORA_ZP   0x05
#define ORA_ZPX  0x15
#define ORA_AB   0x0D
#define ORA_ABX  0x1D
#define ORA_ABY  0x19
#define ORA_INX  0x01
#define ORA_INY  0x11
#define ORA_INZP 0x12

#define NOP      0xEA

#define PHA      0x48
#define PHP      0x08
#define PLA      0x68
#define PLP      0x28

#define ROL_AB   0x2E
#define ROL_ABX  0x3E
#define ROL_ACC  0x2A
#define ROL_ZP   0x26
#define ROL_ZPX  0x36

#define ROR_AB   0x6E
#define ROR_ABX  0x7E
#define ROR_ACC  0x6A
#define ROR_ZP   0x66
#define ROR_ZPX  0x76

#define RTI      0x40
#define RTS      0x60

#define SBC_IMM  0xE9
#define SBC_ZP   0xE5
#define SBC_ZPX  0xF5
#define SBC_AB   0xED
#define SBC_ABX  0xFD
#define SBC_ABY  0xF9
#define SBC_INX  0xE1
#define SBC_INY  0xF1
#define SBC_INZP 0xF2

#define SEC      0x38
#define SED      0xF8
#define SEI      0x78

#define STA_AB   0x8D
#define STA_ABX  0x9D
#define STA_ABY  0x99
#define STA_INX  0x81
#define STA_INY  0x91
#define STA_ZP   0x85
#define STA_ZPX  0x95
#define STA_INZP 0x92

#define STX_ZP   0x86
#define STX_ZPY  0x96
#define STX_AB   0x8E

#define STY_ZP   0x84
#define STY_ZPX  0x94
#define STY_AB   0x8C

#define TAX      0xAA
#define TAY      0xA8
#define TSX      0xBA
#define TXA      0x8A
#define TXS      0x9A
#define TYA      0x98

#define BRA  	 0x80

#define BBR0	 0x0F
#define BBR1	 0x1F
#define BBR2	 0x2F
#define BBR3	 0x3F
#define BBR4	 0x4F
#define BBR5	 0x5F
#define BBR6	 0x6F
#define BBR7	 0x7F

#define BBS0	 0x8F
#define BBS1	 0x9F
#define BBS2	 0xAF
#define BBS3	 0xBF
#define BBS4	 0xCF
#define BBS5	 0xDF
#define BBS6	 0xEF
#define BBS7	 0xFF

#define RMB0	 0x07
#define RMB1	 0x17
#define RMB2	 0x27
#define RMB3	 0x37
#define RMB4	 0x47
#define RMB5	 0x57
#define RMB6	 0x67
#define RMB7	 0x77

#define SMB0	 0x87
#define SMB1	 0x97
#define SMB2	 0xA7
#define SMB3	 0xB7
#define SMB4	 0xC7
#define SMB5	 0xD7
#define SMB6	 0xE7
#define SMB7	 0xF7

#define TRB_AB	 0x1C
#define TRB_ZP	 0x14

#define TSB_AB 	 0x0C
#define TSB_ZP	 0x04

#define STZ_AB	 0x9C
#define STZ_ABX	 0x9E
#define STZ_ZP	 0x64
#define STZ_ZPX  0x74

#define PHX		 0xDA
#define PHY		 0x5A
#define PLX		 0xFA
#define PLY 	 0x7A

#define WAI      0xCB
#define STP 	 0xDB

char* translate_opcode(const uint8_t opcode);
uint8_t translate_opcode_cycles(const uint8_t opcode);

#endif
