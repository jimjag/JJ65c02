.include "minios.inc"
.include "sysram.inc"
.include "via.h"
.include "lib.inc"

.export KBD_initialize
.export KBD_ihandler

; Actual start of ROM code
.segment "CODE"

;
;  This keyboard interface assumes that an Arduino running
;  PS2KeyAdvanced and PS2KeyMap handles the heavy lifting
;  of responding to the clk/interrupt of the PS2 keyboard
;  and figuring out the scancode and then translating that
;  to UTF8. It then pushes that that PORTA of VIA2 and then
;  triggers an interrupt via CA1
;
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
    ldx SERIN_WPTR
    sta INPUT_BUFFER,x                           ; Store in rx buffer
    inc SERIN_WPTR                              ; Increase write buffer pointer
@done:
    plx
    pla
    rts
