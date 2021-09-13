case ADC_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    add(m, read_byte(m, mem_abs(arg1, arg2, 0))); //m->mem[mem_abs(arg1, arg2, 0)]);
    break;

case ADC_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    add(m, read_byte(m, mem_abs(arg1, arg2, m->x))); //m->mem[mem_abs(arg1, arg2, m->x)]);
    break;

case ADC_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    add(m, read_byte(m, mem_abs(arg1, arg2, m->y))); //m->mem[mem_abs(arg1, arg2, m->y)]);
    break;

case ADC_IMM:
    add(m, NEXT_BYTE(m));
    break;

case ADC_INX:
    add(m, read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x))); //m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)]);
    break;

case ADC_INY:
    add(m, read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y))); //m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)]);
    break;

case ADC_ZP:
    add(m, read_byte(m, NEXT_BYTE(m))); //m->mem[NEXT_BYTE(m)]);
    break;

case ADC_ZPX:
    add(m, read_byte(m, ZP(NEXT_BYTE(m) + m->x))); //m->mem[ZP(NEXT_BYTE(m) + m->x)]);
    break;

case ADC_INZP:
    add(m, read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m)))); //m->mem[mem_indirect_zp(m, NEXT_BYTE(m))]);
    break;

case SBC_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    sub(m, read_byte(m, mem_abs(arg1, arg2, 0))); //m->mem[mem_abs(arg1, arg2, 0)]);
    break;

case SBC_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    sub(m, read_byte(m, mem_abs(arg1, arg2, m->x))); //m->mem[mem_abs(arg1, arg2, m->x)]);
    break;

case SBC_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    sub(m, read_byte(m, mem_abs(arg1, arg2, m->y))); //m->mem[mem_abs(arg1, arg2, m->y)]);
    break;

case SBC_IMM:
    sub(m, NEXT_BYTE(m));
    break;

case SBC_INX:
    sub(m, read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x))); //m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)]);
    break;

case SBC_INY:
    sub(m, read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y))); //m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)]);
    break;

case SBC_ZP:
    sub(m, read_byte(m, NEXT_BYTE(m))); //m->mem[NEXT_BYTE(m)]);
    break;

case SBC_ZPX:
    sub(m, read_byte(m, ZP(NEXT_BYTE(m) + m->x))); //m->mem[ZP(NEXT_BYTE(m) + m->x)]);
    break;

case SBC_INZP:
    sub(m, read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m)))); //m->mem[mem_indirect_zp(m, NEXT_BYTE(m))]);
    break;
