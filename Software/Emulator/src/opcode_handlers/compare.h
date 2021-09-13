case CMP_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    //cmp(m, m->mem[mem_abs(arg1, arg2, 0)], m->ac);
    cmp(m, read_byte(m, mem_abs(arg1, arg2, 0)), m->ac);
    break;

case CMP_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    //cmp(m, m->mem[mem_abs(arg1, arg2, m->x)], m->ac);
    cmp(m, read_byte(m, mem_abs(arg1, arg2, m->x)), m->ac);
    break;

case CMP_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    //cmp(m, m->mem[mem_abs(arg1, arg2, m->y)], m->ac);
    cmp(m, read_byte(m, mem_abs(arg1, arg2, m->y)), m->ac);
    break;

case CMP_IMM:
    cmp(m, NEXT_BYTE(m), m->ac);
    break;

case CMP_INX:
    //cmp(m, m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)], m->ac);
    cmp(m, read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x)), m->ac);
    break;

case CMP_INY:
    //cmp(m, m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)], m->ac);
    cmp(m, read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y)), m->ac);
    break;

case CMP_ZP:
    //cmp(m, m->mem[NEXT_BYTE(m)], m->ac);
    cmp(m, read_byte(m, NEXT_BYTE(m)), m->ac);
    break;

case CMP_ZPX:
    //cmp(m, m->mem[ZP(NEXT_BYTE(m) + m->x)], m->ac);
    cmp(m, read_byte(m, ZP(NEXT_BYTE(m) + m->x)), m->ac);
    break;

case CMP_INZP:
    //cmp(m, m->mem[mem_indirect_zp(m, NEXT_BYTE(m))], m->ac);
    cmp(m, read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m))), m->ac);
    break;

case CPX_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    //cmp(m, m->mem[mem_abs(arg1, arg2, 0)], m->x);
    cmp(m, read_byte(m, mem_abs(arg1, arg2, 0)), m->x);
    break;

case CPX_IMM:
    cmp(m, NEXT_BYTE(m), m->x);
    break;

case CPX_ZP:
    //cmp(m, m->mem[NEXT_BYTE(m)], m->x);
    cmp(m, read_byte(m, NEXT_BYTE(m)), m->x);
    break;

case CPY_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    //cmp(m, m->mem[mem_abs(arg1, arg2, 0)], m->y);
    cmp(m, read_byte(m, mem_abs(arg1, arg2, 0)), m->y);
    break;

case CPY_IMM:
    cmp(m, NEXT_BYTE(m), m->y);
    break;

case CPY_ZP:
    //cmp(m, m->mem[NEXT_BYTE(m)], m->y);
    cmp(m, read_byte(m, NEXT_BYTE(m)), m->y);
    break;
