case ASL_AB:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_CARRY, t2 & 0x80);
    write_byte(m, r1, (t2 << 1) & 0xFE);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ASL_ABX:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), m->x);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_CARRY, t2 & 0x80);
    write_byte(m, r1, (t2 << 1) & 0xFE);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ASL_ACC:
    set_flag(m, FLAG_CARRY, m->ac & 0x80);
    m->ac = (m->ac << 1) & 0xFE;
    set_flags(m, m->ac);
    break;

case ASL_ZP:
    arg1 = NEXT_BYTE(m);
    t2 = read_byte(m, arg1);
    set_flag(m, FLAG_CARRY, t2 & 0x80);
    write_byte(m, arg1, (t2 << 1) & 0xFE);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case ASL_ZPX:
    arg1 = ZP(NEXT_BYTE(m) + m->x);
    t2 = read_byte(m, arg1);
    set_flag(m, FLAG_CARRY, t2 & 0x80);
    write_byte(m, arg1, (t2 << 1) & 0xFE);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case LSR_AB:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_CARRY, t2 & 0x01);
    write_byte(m, r1, (t2 >> 1) & 0x7F);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case LSR_ABX:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), m->x);
    t2 = read_byte(m, r1);
    set_flag(m, FLAG_CARRY, t2 & 0x01);
    write_byte(m, r1, (t2 >> 1) & 0x7F);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case LSR_ACC:
    set_flag(m, FLAG_CARRY, m->ac & 0x01);
    m->ac = (m->ac >> 1) & 0x7F;
    set_flags(m, m->ac);
    break;

case LSR_ZP:
    arg1 = NEXT_BYTE(m);
    t2 = read_byte(m, arg1);
    set_flag(m, FLAG_CARRY, t2 & 0x01);
    write_byte(m, arg1, (t2 >> 1) & 0x7F);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case LSR_ZPX:
    arg1 = ZP(NEXT_BYTE(m) + m->x);
    t2 = read_byte(m, arg1);
    set_flag(m, FLAG_CARRY, t2 & 0x01);
    write_byte(m, arg1, (t2 >> 1) & 0x7F);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case ROL_AB:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    t2 = read_byte(m, r1);
    t1 = t2 & 0x80;
    write_byte(m, r1, ((t2 << 1) & 0xFE) | get_flag(m, FLAG_CARRY));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ROL_ABX:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), m->x);
    t2 = read_byte(m, r1);
    t1 = t2 & 0x80;
    write_byte(m, r1, ((t2 << 1) & 0xFE) | get_flag(m, FLAG_CARRY));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ROL_ACC:
    t1 = m->ac & 0x80;
    m->ac = ((m->ac << 1) & 0xFE) | get_flag(m, FLAG_CARRY);
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, m->ac);
    break;

case ROL_ZP:
    arg1 = NEXT_BYTE(m);
    t2 = read_byte(m, arg1);
    t1 = t2 & 0x80;
    write_byte(m, arg1, ((t2 << 1) & 0xFE) | get_flag(m, FLAG_CARRY));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case ROL_ZPX:
    arg1 = ZP(NEXT_BYTE(m) + m->x);
    t2 = read_byte(m, arg1);
    t1 = t2 & 0x80;
    write_byte(m, arg1, ((t2 << 1) & 0xFE) | get_flag(m, FLAG_CARRY));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case ROR_AB:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), 0);
    t2 = read_byte(m, r1);
    t1 = t2 & 0x01;
    write_byte(m, r1, ((t2 >> 1) & 0x7F) | (get_flag(m, FLAG_CARRY) << 7));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ROR_ABX:
    arg1 = NEXT_BYTE(m);
    r1 = mem_abs(arg1, NEXT_BYTE(m), m->x);
    t2 = read_byte(m, r1);
    t1 = t2 & 0x01;
    write_byte(m, r1, ((t2 >> 1) & 0x7F) | (get_flag(m, FLAG_CARRY) << 7));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, r1);
    break;

case ROR_ACC:
    t1 = m->ac & 0x01;
    m->ac = ((m->ac >> 1) & 0x7F) | (get_flag(m, FLAG_CARRY) << 7);
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, m->ac);
    break;

case ROR_ZP:
    arg1 = NEXT_BYTE(m);
    t2 = read_byte(m, arg1);
    t1 = t2 & 0x01;
    write_byte(m, arg1, ((t2 >> 1) & 0x7F) | (get_flag(m, FLAG_CARRY) << 7));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;

case ROR_ZPX:
    arg1 = ZP(NEXT_BYTE(m) + m->x);
    t2 = read_byte(m, arg1);
    t1 = t2 & 0x01;
    write_byte(m, arg1, ((t2 >> 1) & 0x7F) | (get_flag(m, FLAG_CARRY) << 7));
    set_flag(m, FLAG_CARRY, t1);
    set_flags(m, t2);
    mark_dirty(m, arg1);
    break;
