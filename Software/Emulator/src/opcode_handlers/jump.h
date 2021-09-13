case JMP_AB:
    arg1 = NEXT_BYTE(m);
    set_pc(m, mem_abs(arg1, NEXT_BYTE(m), 0));
    break;

case JMP_ABX:
    arg1 = NEXT_BYTE(m);
    set_pc(m, mem_abs(arg1, NEXT_BYTE(m), m->x));
    break;

case JMP_IN:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    set_pc(m, mem_abs(read_byte(m, r1), read_byte(m, r1+1), 0)); //m->mem[r1], m->mem[r1+1], 0);
    break;

case JSR_AB:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    // we push the address of the byte immediately before where we want to
    // return to because reasons:
    r2 = m->pc + pc_offset - 1;
    STACK_PUSH(m, (r2 & 0xFF00) >> 8);
    STACK_PUSH(m, r2 & 0xFF);
    set_pc(m, r1);
    break;

case RTS:
    arg1 = STACK_POP(m);
    set_pc(m, mem_abs(arg1, STACK_POP(m), 0) + 1);
    break;
