.include "minios.inc"
.include "sysram.inc"
.include "acia.h"
.include "lib.inc"

.export ACIA_DATA
.export ACIA_STATUS
.export ACIA_COMMAND
.export ACIA_CONTROL

.export ACIA_init
.export ACIA_read_byte
.export ACIA_write_byte
.export ACIA_write_string
.export ACIA_ihandler

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   ACIA_init - initializes the R6551
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

ACIA_init:
    pha
    lda #(ACIA_HARDWARE_RESET)
    sta ACIA_STATUS
    lda #(ACIA_PARITY_DISABLE | ACIA_ECHO_DISABLE | ACIA_TX_INT_DISABLE_RTS_LOW | ACIA_RX_INT_ENABLE | ACIA_DTR_LOW)
    sta ACIA_COMMAND
    lda #(ACIA_STOP_BITS_1 | ACIA_DATA_BITS_8 | ACIA_CLOCK_INT | ACIA_BAUD_19200)
    sta ACIA_CONTROL
    lda ACIA_CONTROL
    cmp #(ACIA_STOP_BITS_1 | ACIA_DATA_BITS_8 | ACIA_CLOCK_INT | ACIA_BAUD_19200)
    bne @done
    lda #(MINIOS_ACIA_ENABLED_FLAG)
    tsb MINIOS_STATUS
@done:
    jsr LIB_flush_rbuff
    pla
    rts

;================================================================================
;
;   ACIA_read_byte - Return one byte from RX buffer in .A
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A, C flag (set if data exist, cleared if no data)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

ACIA_read_byte:
    jsr LIB_have_rdata
    bcs @read_it
    clc                 ; just in case
    rts
@read_it:
    phx
    ldx INPUT_RRPTR
    lda INPUT_RDBUFF,x
    inc INPUT_RRPTR
.ifdef __HW_FLOW_CONTROL__
    pha
    lda INPUT_RRPTR
    sec
    sbc INPUT_RWPTR
    cmp #$80                        ; TODO: check this...
    bcs @done                       ; consume buffer
    pha
    lda ACIA_COMMAND
    and #%11110011
    ora #(ACIA_TX_INT_ENABLE_RTS_LOW)
    sta ACIA_COMMAND
    pla
@done:
    pla
.endif
    plx
    sec
    rts

;================================================================================
;
;   ACIA_write_byte - Write one byte to TX buffer
;
;   ————————————————————————————————————
;   Preparatory Ops: .A input in accumulator
;
;   Returned Values: none
;
;   Destroys:        .none
;   ————————————————————————————————————
;
;================================================================================

ACIA_write_byte:
    phx
    tax
    pha
@wait_txd_empty_char:
    lda ACIA_STATUS
    and #(ACIA_STATUS_TX_EMPTY)
    beq @wait_txd_empty_char
    stx ACIA_DATA
    lda #$01                            ; wait 1ms (more than 520us for 19200 baud)
    jsr LIB_delay1ms
    pla
    plx
    rts

;================================================================================
;
;   ACIA_write_string - Write null-terminated string
;
;   ————————————————————————————————————
;   Preparatory Ops: ACIA_SPTR, ACIA_SPTR+1 string pointer
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

ACIA_write_string:
    pha
    phx
    phy
    ldy #$00
@string_loop:
    lda (ACIA_SPTR),y
    beq @end_loop
    jsr ACIA_write_byte
    iny
    beq @cross_page
    bne @string_loop
@cross_page:
    inc ACIA_SPTR+1
    bra @string_loop
@end_loop:
    ply
    plx
    pla
    rts

;================================================================================
;
;   ACIA_ihandler - IRQ Handler
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

ACIA_ihandler:
    pha
    phx
    lda ACIA_STATUS
    and #(ACIA_STATUS_RX_FULL)
    beq @done                                   ; Receive buffer full?
    lda ACIA_DATA
    ldx INPUT_RWPTR
    sta INPUT_RDBUFF,x                           ; Store in rx buffer
    inc INPUT_RWPTR                              ; Increase write buffer pointer
.ifdef __HW_FLOW_CONTROL__
    lda INPUT_RWPTR
    cmp INPUT_RRPTR                              ; are we buffer full?
    bne @done
    lda ACIA_COMMAND                            ; bring RTS high
    and #%11110011
    sta ACIA_COMMAND
.endif
@done:
    plx
    pla
    rts
