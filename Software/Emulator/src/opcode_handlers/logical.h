case AND_IMM:
    m->ac &= NEXT_BYTE(m);
    set_flags(m, m->ac);
    break;

case AND_ZP:
    m->ac &= read_byte(m, NEXT_BYTE(m)); //m->mem[NEXT_BYTE(m)];
    set_flags(m, m->ac);
    break;

case AND_ZPX:
    m->ac &= read_byte(m, ZP(NEXT_BYTE(m) + m->x)); //m->mem[ZP(NEXT_BYTE(m) + m->x)];
    set_flags(m, m->ac);
    break;

case AND_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac &= read_byte(m, mem_abs(arg1, arg2, 0)); //m->mem[mem_abs(arg1, arg2, 0)];
    set_flags(m, m->ac);
    break;

case AND_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac &= read_byte(m, mem_abs(arg1, arg2, m->x)); //m->mem[mem_abs(arg1, arg2, m->x)];
    set_flags(m, m->ac);
    break;

case AND_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac &= read_byte(m, mem_abs(arg1, arg2, m->y)); //m->mem[mem_abs(arg1, arg2, m->y)];
    set_flags(m, m->ac);
    break;

case AND_INX:
    m->ac &= read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x)); //m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)];
    set_flags(m, m->ac);
    break;

case AND_INY:
    m->ac &= read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y)); //m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)];
    set_flags(m, m->ac);
    break;

case AND_INZP:
    m->ac &= read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m))); //m->mem[mem_indirect_zp(m, NEXT_BYTE(m))];
    set_flags(m, m->ac);
    break;

case EOR_IMM:
    m->ac ^= NEXT_BYTE(m);
    set_flags(m, m->ac);
    break;

case EOR_ZP:
    m->ac ^= read_byte(m, NEXT_BYTE(m)); //m->mem[NEXT_BYTE(m)];
    set_flags(m, m->ac);
    break;

case EOR_ZPX:
    m->ac ^= read_byte(m, ZP(NEXT_BYTE(m) + m->x)); //m->mem[ZP(NEXT_BYTE(m) + m->x)];
    set_flags(m, m->ac);
    break;

case EOR_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac ^= read_byte(m, mem_abs(arg1, arg2, 0)); //m->mem[mem_abs(arg1, arg2, 0)];
    set_flags(m, m->ac);
    break;

case EOR_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac ^= read_byte(m, mem_abs(arg1, arg2, m->x)); //m->mem[mem_abs(arg1, arg2, m->x)];
    set_flags(m, m->ac);
    break;

case EOR_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac ^= read_byte(m, mem_abs(arg1, arg2, m->y)); //m->mem[mem_abs(arg1, arg2, m->y)];
    set_flags(m, m->ac);
    break;

case EOR_INX:
    m->ac ^= read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x)); //m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)];
    set_flags(m, m->ac);
    break;

case EOR_INY:
    m->ac ^= read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y)); //m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)];
    set_flags(m, m->ac);
    break;

case EOR_INZP:
    m->ac ^= read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m))); //m->mem[mem_indirect_zp(m, NEXT_BYTE(m))];
    set_flags(m, m->ac);
    break;

case ORA_IMM:
    m->ac |= NEXT_BYTE(m);
    set_flags(m, m->ac);
    break;

case ORA_ZP:
    m->ac |= read_byte(m, NEXT_BYTE(m)); //m->mem[NEXT_BYTE(m)];
    set_flags(m, m->ac);
    break;

case ORA_ZPX:
    m->ac |= read_byte(m, ZP(NEXT_BYTE(m) + m->x)); //m->mem[ZP(NEXT_BYTE(m) + m->x)];
    set_flags(m, m->ac);
    break;

case ORA_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac |= read_byte(m, mem_abs(arg1, arg2, 0)); //m->mem[mem_abs(arg1, arg2, 0)];
    set_flags(m, m->ac);
    break;

case ORA_ABX:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac |= read_byte(m, mem_abs(arg1, arg2, m->x)); //m->mem[mem_abs(arg1, arg2, m->x)];
    set_flags(m, m->ac);
    break;

case ORA_ABY:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    m->ac |= read_byte(m, mem_abs(arg1, arg2, m->y)); //m->mem[mem_abs(arg1, arg2, m->y)];
    set_flags(m, m->ac);
    break;

case ORA_INX:
    m->ac |= read_byte(m, mem_indexed_indirect(m, NEXT_BYTE(m), m->x)); //m->mem[mem_indexed_indirect(m, NEXT_BYTE(m), m->x)];
    set_flags(m, m->ac);
    break;

case ORA_INY:
    m->ac |= read_byte(m, mem_indirect_index(m, NEXT_BYTE(m), m->y)); //m->mem[mem_indirect_index(m, NEXT_BYTE(m), m->y)];
    set_flags(m, m->ac);
    break;

case ORA_INZP:
    m->ac |= read_byte(m, mem_indirect_zp(m, NEXT_BYTE(m))); //m->mem[mem_indirect_zp(m, NEXT_BYTE(m))];
    set_flags(m, m->ac);
    break;

case BIT_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    t1 = read_byte(m, mem_abs(arg1, arg2, 0)); //m->mem[mem_abs(arg1, arg2, 0)];
    set_flag(m, FLAG_ZERO, !(t1 & m->ac));
    set_flag(m, FLAG_OVERFLOW, t1 & 0x40);
    set_flag(m, FLAG_NEGATIVE, t1 & 0x80);
    break;

case BIT_ZP:
    t1 = read_byte(m, NEXT_BYTE(m)); //m->mem[NEXT_BYTE(m)];
    set_flag(m, FLAG_ZERO, !(t1 & m->ac));
    set_flag(m, FLAG_OVERFLOW, t1 & 0x40);
    set_flag(m, FLAG_NEGATIVE, t1 & 0x80);
    break;

case BIT_ZPX:
    t1 = read_byte(m, ZP(NEXT_BYTE(m) + m->x)); //m->mem[ZP(NEXT_BYTE(m) + m->x)];
    set_flag(m, FLAG_ZERO, !(t1 & m->ac));
    set_flag(m, FLAG_OVERFLOW, t1 & 0x40);
    set_flag(m, FLAG_NEGATIVE, t1 & 0x80);
    break;

case RMB0:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x01;
    write_byte(m, r1, read_byte(m, r1) & ~0x01);
    mark_dirty(m, r1);
    break;

case RMB1:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x02;
    write_byte(m, r1, read_byte(m, r1) & ~0x02);
    mark_dirty(m, r1);
    break;

case RMB2:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x04;
    write_byte(m, r1, read_byte(m, r1) & ~0x04);
    mark_dirty(m, r1);
    break;

case RMB3:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x08;
    write_byte(m, r1, read_byte(m, r1) & ~0x08);
    mark_dirty(m, r1);
    break;

case RMB4:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x10;
    write_byte(m, r1, read_byte(m, r1) & ~0x10);
    mark_dirty(m, r1);
    break;

case RMB5:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x20;
    write_byte(m, r1, read_byte(m, r1) & ~0x20);
    mark_dirty(m, r1);
    break;

case RMB6:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x40;
    write_byte(m, r1, read_byte(m, r1) & ~0x40);
    mark_dirty(m, r1);
    break;

case RMB7:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] &= ~0x80;
    write_byte(m, r1, read_byte(m, r1) & ~0x80);
    mark_dirty(m, r1);
    break;

case SMB0:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x01;
    write_byte(m, r1, read_byte(m, r1) | 0x01);
    mark_dirty(m, r1);
    break;

case SMB1:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x02;
    write_byte(m, r1, read_byte(m, r1) | 0x02);
    mark_dirty(m, r1);
    break;

case SMB2:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x04;
    write_byte(m, r1, read_byte(m, r1) | 0x04);
    mark_dirty(m, r1);
    break;

case SMB3:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x08;
    write_byte(m, r1, read_byte(m, r1) | 0x08);
    mark_dirty(m, r1);
    break;

case SMB4:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x10;
    write_byte(m, r1, read_byte(m, r1) | 0x10);
    mark_dirty(m, r1);
    break;

case SMB5:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x20;
    write_byte(m, r1, read_byte(m, r1) | 0x20);
    mark_dirty(m, r1);
    break;

case SMB6:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x40;
    write_byte(m, r1, read_byte(m, r1) | 0x40);
    mark_dirty(m, r1);
    break;

case SMB7:
    r1 = ZP(NEXT_BYTE(m));
    //m->mem[r1] |= 0x80;
    write_byte(m, r1, read_byte(m, r1) | 0x80);
    mark_dirty(m, r1);
    break;

case TRB_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, arg2, 0);
    //set_flag(m, FLAG_ZERO, m->mem[r1] & m->ac);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_ZERO, t2 & m->ac);
    //m->mem[r1] &= ~m->ac;
    write_byte(m, r1, t2 & ~m->ac);
    mark_dirty(m, r1);
    break;

case TRB_ZP:
    r1 = ZP(NEXT_BYTE(m));
    //set_flag(m, FLAG_ZERO, m->mem[r1] & m->ac);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_ZERO, t2 & m->ac);
    //m->mem[r1] &= ~m->ac;
    write_byte(m, r1, t2 & ~m->ac);
    mark_dirty(m, r1);
    break;

case TSB_AB:
    arg1 = NEXT_BYTE(m);
    arg2 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, arg2, 0);
    //set_flag(m, FLAG_ZERO, m->mem[r1] & m->ac);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_ZERO, t2 & m->ac);
    //m->mem[r1] |= m->ac;
    write_byte(m, r1, t2 | m->ac);
    mark_dirty(m, r1);
    break;

case TSB_ZP:
    r1 = ZP(NEXT_BYTE(m));
    //set_flag(m, FLAG_ZERO, m->mem[r1] & m->ac);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_ZERO, t2 & m->ac);
    //m->mem[r1] |= m->ac;
    write_byte(m, r1, t2 | m->ac);
    mark_dirty(m, r1);
    break;
