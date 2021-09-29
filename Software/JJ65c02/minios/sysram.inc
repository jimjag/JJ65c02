.ifndef _SYSRAM_INC_
_SYSRAM_INC_ = 1

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $0300      RAM: miniOS set-aside / Page 2
;      . $0300 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8010 - $801f      ACIA Blk:
;    $9000 - $9fff      VIA1: 4K
;    $a000 - $ffff      ROM: 24K
;--------

.importzp Z0
.importzp Z1
.importzp Z2
.importzp Z3

.import VIDEO_RAM
.import CLK_SPD
.import ISR_VECTOR

.endif
