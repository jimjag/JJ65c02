#include "opcodes.h"

char* opcodes_matrix[16][16] = 
  {{"BRK", "ORA", "NOP", "NOP", "TSB", "ORA", "ASL", "RMB0", "PHP", "ORA", "ASL", "NOP", "TSB", "ORA", "ASL", "BBR0"},
   {"BPL", "ORA", "ORA", "NOP", "TRB", "ORA", "ASL", "RMB1", "CLC", "ORA", "INC", "NOP", "TRB", "ORA", "ASL", "BPR1"},
   {"JSR", "AND", "NOP", "NOP", "BIT", "AND", "ROL", "RMB2", "PLP", "AND", "ROL", "NOP", "BIT", "AND", "ROL", "BBR2"},
   {"BMI", "AND", "AND", "NOP", "BIT", "AND", "ROL", "RMB3", "SEC", "AND", "DEC", "NOP", "BIT", "AND", "ROL", "BBR3"},
   {"RTI", "EOR", "NOP", "NOP", "NOP", "EOR", "LSR", "RMB4", "PHA", "EOR", "LSR", "NOP", "JMP", "EOR", "LSR", "BBR4"},
   {"BVC", "EOR", "EOR", "NOP", "NOP", "EOR", "LSR", "RMB5", "CLI", "EOR", "PHY", "NOP", "NOP", "EOR", "LSR", "BBR5"},
   {"RTS", "ADC", "NOP", "NOP", "STZ", "ADC", "ROR", "RMB6", "PLA", "ADC", "ROR", "NOP", "JMP", "ADC", "ROR", "BBR6"},
   {"BVS", "ADC", "ADC", "NOP", "STZ", "ADC", "ROR", "RMB7", "SEI", "ADC", "PLY", "NOP", "JMP", "ADC", "ROR", "BPR7"},
   {"BRA", "STA", "NOP", "NOP", "STY", "STA", "STX", "SMB0", "DEY", "BIT", "TXA", "NOP", "STY", "STA", "STX", "BBS0"},
   {"BCC", "STA", "STA", "NOP", "STY", "STA", "STX", "SMB1", "TYA", "STA", "TXS", "NOP", "STZ", "STA", "STZ", "BBS1"},
   {"LDY", "LDA", "LDX", "NOP", "LDY", "LDA", "LDX", "SMB2", "TAY", "LDA", "TAX", "NOP", "LDY", "LDA", "LDX", "BBS2"},
   {"BCS", "LDA", "LDA", "NOP", "LDY", "LDA", "LDX", "SMB3", "CLV", "LDA", "TSX", "NOP", "LDY", "LDA", "LDX", "BBS3"},
   {"CPY", "CMP", "NOP", "NOP", "CPY", "CMP", "DEC", "SMB4", "INY", "CMP", "DEX", "WAI", "CPY", "CMP", "DEC", "BBS4"},
   {"BNE", "CMP", "CMP", "NOP", "NOP", "CMP", "DEC", "SMB5", "CLD", "CMP", "PHX", "STP", "NOP", "CMP", "DEC", "BBS5"},
   {"CPX", "SBC", "NOP", "NOP", "CPX", "SBC", "INC", "SMB6", "INX", "SBC", "NOP", "NOP", "CPX", "SBC", "INC", "BBS6"},
   {"BEQ", "SBC", "SBC", "NOP", "NOP", "SBC", "INC", "SMB7", "SED", "SBC", "PLX", "NOP", "NOP", "SBC", "INC", "BBS7"}};

uint8_t opcodes_cycles[16][16] =
  {{7    , 6    , 2    , 1    , 5    , 3    , 5    , 5     , 3    , 2    , 2    , 1    , 6    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 5    , 4    , 6    , 5     , 2    , 4    , 2    , 1    , 6    , 4    , 6    , 5     },
   {6    , 6    , 1    , 1    , 3    , 3    , 5    , 5     , 4    , 2    , 2    , 1    , 4    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 4    , 4    , 6    , 5     , 2    , 4    , 2    , 1    , 4    , 4    , 6    , 5     },
   {6    , 6    , 1    , 1    , 1    , 3    , 5    , 5     , 3    , 2    , 2    , 1    , 3    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 1    , 4    , 6    , 5     , 2    , 4    , 3    , 1    , 1    , 4    , 6    , 5     },
   {6    , 6    , 2    , 1    , 3    , 3    , 5    , 5     , 4    , 2    , 2    , 1    , 6    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 4    , 4    , 6    , 5     , 2    , 4    , 4    , 1    , 6    , 4    , 6    , 5     },
   {3    , 6    , 2    , 1    , 3    , 3    , 3    , 5     , 2    , 2    , 2    , 1    , 4    , 4    , 4    , 5     },
   {2    , 6    , 5    , 1    , 4    , 4    , 4    , 5     , 2    , 5    , 2    , 1    , 4    , 5    , 5    , 5     },
   {2    , 6    , 2    , 1    , 3    , 3    , 3    , 5     , 2    , 2    , 2    , 1    , 4    , 4    , 4    , 5     },
   {2    , 5    , 5    , 1    , 4    , 4    , 4    , 5     , 2    , 4    , 2    , 1    , 4    , 4    , 4    , 5     },
   {2    , 6    , 2    , 1    , 3    , 3    , 5    , 5     , 2    , 2    , 2    , 3    , 4    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 4    , 4    , 6    , 5     , 2    , 4    , 3    , 3    , 1    , 4    , 7    , 5     },
   {2    , 6    , 2    , 1    , 3    , 5    , 5    , 5     , 2    , 2    , 2    , 1    , 4    , 4    , 6    , 5     },
   {2    , 5    , 5    , 1    , 4    , 4    , 6    , 5     , 2    , 4    , 4    , 1    , 4    , 4    , 7    , 5    }};

char* translate_opcode(const uint8_t opcode)
{
  return opcodes_matrix[(opcode & 0xf0) >> 4][opcode & 0x0f];
}

uint8_t translate_opcode_cycles(const uint8_t opcode)
{
  return opcodes_cycles[(opcode & 0xf0) >> 4][opcode & 0x0f];
}
