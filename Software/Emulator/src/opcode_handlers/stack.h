case PHA:
    STACK_PUSH(m, m->ac);
    break;

case PHP:
    STACK_PUSH(m, m->sr);
    break;

case PLA:
    m->ac = STACK_POP(m);
    break;

case PLP:
    m->sr = STACK_POP(m);
    break;

case PHX:
	STACK_PUSH(m, m->x);
    break;

case PHY:
	STACK_PUSH(m, m->y);
    break;

case PLX:
	m->x = STACK_POP(m);
    break;

case PLY:
	m->y = STACK_POP(m);
    break;
