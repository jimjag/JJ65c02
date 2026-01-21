.ifndef _MINIOS_INC_
_MINIOS_INC_ = 1

;.FEATURE leading_dot_in_identifiers
.setcpu "65C02"
.MACPACK generic

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;
;   miniOS: RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $9fff      RAM: 40k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $03ff      RAM: miniOS set-aside / Page 2-3
;      . $0400 - $9fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;      . $8000 - $9fff      RAM: RAM Bank
;    $a010 - $afff      IO Blk: 4k
;      . $8010 - $801f      ACIA:
;      . $8020 - $802f      VIA1:
;    $b000 - $ffff      ROM: 20K
;--------


.include "minios.h"

.endif
