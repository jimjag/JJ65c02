case PHA:
    STACK_PUSH(m, m->ac);
    break;

case PHP:
    STACK_PUSH(m, m->sr | FLAG_BREAK | 0x20);
    break;

case PLA:
    m->ac = STACK_POP(m);
    set_flags(m, m->ac);
    break;

case PLP:
    m->sr = STACK_POP(m) | 0x20;
    break;

case PHX:
	STACK_PUSH(m, m->x);
    break;

case PHY:
	STACK_PUSH(m, m->y);
    break;

case PLX:
	m->x = STACK_POP(m);
    set_flags(m, m->x);
    break;

case PLY:
	m->y = STACK_POP(m);
    set_flags(m, m->y);
    break;
