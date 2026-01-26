.ifndef _SYSRAM_H_
_SYSRAM_H_ = 1

; miniOS status/config bit masks

MINIOS_ACIA_ENABLED_FLAG = 1 << 0   ; bit 0
MINIOS_RAM_TEST_PASS_FLAG = 1 << 1  ; bit 1
MINIOS_RTS_HIGH_FLAG = 1 << 2       ; bit 2
EHBASIC_ZP_CORRUPTED_FLAG = 1 << 3  ; bit 3

YMBUF_SIZE = 132

.endif
