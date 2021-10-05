.ifndef _MINIOS_INC_
_MINIOS_INC_ = 1

.FEATURE leading_dot_in_identifiers
.setcpu "65C02"
.MACPACK generic

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;;
;   miniOS: RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Updated by Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;   Credits:
;               - Jan Roesner <jan@roesner.it>     Original Sixty/5o2 project
;               - Ben Eater                        (Project 6502)
;               - Steven Wozniak                   (bin2hex routine)
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $0300      RAM: miniOS set-aside / Page 2
;      . $0300 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8010 - $8fff      IO Blk: 4k
;      . $8010 - $801f      ACIA:
;      . $8020 - $802f      VIA:
;    $9000 - $ffff      ROM: 28K
;--------


.include "minios.h"

.endif
