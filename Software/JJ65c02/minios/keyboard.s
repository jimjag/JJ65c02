.include "minios.inc"
.include "sysram.inc"
.include "via.h"
.include "lib.inc"

.export KBD_initialize

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   KBD_initialize - Setup read handshake on VIA2 CA1/CA2
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

KBD_initialize:
    pha
      lda VIA2_PCR                                  ; Clear Flags
      and #$0f
      ora #(VIA_PCR_CA1_INTERRUPT_NEGATIVE | VIA_PCR_CA2_OUTPUT_PULSE | VIA_PCR_CB1_INTERRUPT_NEGATIVE | VIA_PCR_CB2_OUTPUT_HIGH)
      sta VIA1_PCR
      lda #(VIA_IER_SET_FLAGS | VIA_IER_CA1_FLAG)   ; Enable interrupt on CA1
      sta VIA2_IER
      pla
      rts

;================================================================================
;
;   KBD_ihandler - IRQ Handler
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

KBD_ihandler:
    pha
    phx
    lda VIA2_PORTA
    ldx INPUT_RWPTR
    sta INPUT_RDBUFF,x                           ; Store in rx buffer
    inc INPUT_RWPTR                              ; Increase write buffer pointer
@done:
    plx
    pla
    rts
