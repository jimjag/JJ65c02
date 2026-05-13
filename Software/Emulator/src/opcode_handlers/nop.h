case NOP2_02:
case NOP2_22:
case NOP2_42:
case NOP2_62:
case NOP2_82:
case NOP2_C2:
case NOP2_E2:
case NOP2_44:
case NOP2_54:
case NOP2_D4:
case NOP2_F4:
    (void) NEXT_BYTE(m);
    break;

case NOP3_5C:
case NOP3_DC:
case NOP3_FC:
    (void) NEXT_BYTE(m);
    (void) NEXT_BYTE(m);
    break;
