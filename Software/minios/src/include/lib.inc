.ifndef _LIB_INC_
_LIB_INC_ = 1

.import LIB_delay1ms
.import LIB_delay100ms
.import LIB_bin_to_hex
.import LIB_have_serialdata
.import LIB_have_ps2data
.import LIB_flush_serbuf
.import LIB_flush_ps2buf
.import LIB_byte2str
.import LIB_short2str
.import LIB_setrambank
.import LIB_getrambank
.import LIB_MSTK_PUSH
.import LIB_MSTK_PULL

.import GRA_print_char
.import GRA_set_fgcolor
.import GRA_set_bgcolor

; GRAphics colors
BLACK_c          = 0
RED_c            = 1
GREEN_c          = 2
YELLOW_c         = 3
BLUE_c           = 4
MAGENTA_c        = 5
CYAN_c           = 6
LIGHT_GREY_c     = 7
GREY_c           = 8
LIGHT_RED_c      = 9
LIGHT_GREEN_c   = 10
LIGHT_YELLOW_c  = 11
LIGHT_BLUE_c    = 12
LIGHT_MAGENTA_c = 13
LIGHT_CYAN_c    = 14
WHITE_c         = 15
TRANPARENT_c    = $ff

.endif
