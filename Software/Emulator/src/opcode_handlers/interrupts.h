case BRK: {
    // BRK is a 2-byte instruction: push PC of the byte AFTER the signature.
    uint16_t brk_pc = m->pc + 2;
    STACK_PUSH(m, (brk_pc & 0xFF00) >> 8);
    STACK_PUSH(m, brk_pc & 0xFF);
    STACK_PUSH(m, m->sr | FLAG_BREAK | 0x20);
    set_flag(m, FLAG_INTERRUPT, 1);
    set_flag(m, FLAG_DECIMAL, 0);
    set_pc(m, mem_abs(read_byte(m, 0xFFFE), read_byte(m, 0xFFFF), 0));
    break;
}

case RTI:
    m->sr = STACK_POP(m) | 0x20;
    arg1 = STACK_POP(m);
    set_pc(m, mem_abs(arg1, STACK_POP(m), 0));
    break;

case WAI:
    m->emu_flags |= EMU_FLAG_WAIT_FOR_INTERRUPT;
    break;
