.include "minios.inc"
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
.exportzp ptr1
.exportzp acia_active

.segment "ZEROPAGE"
ptr1:           .res 2
acia_active:    .res 1

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
    stz acia_active
    lda #(ACIA_HARDWARE_RESET)
    sta ACIA_STATUS
    lda ACIA_DATA
    lda #(ACIA_PARITY_DISABLE | ACIA_ECHO_DISABLE | ACIA_TX_INT_DISABLE_RTS_LOW | ACIA_RX_INT_DISABLE | ACIA_DTR_LOW)
    sta ACIA_COMMAND
    lda #(ACIA_STOP_BITS_1 | ACIA_DATA_BITS_8 | ACIA_CLOCK_INT | ACIA_BAUD_19200)
    sta ACIA_CONTROL
    lda ACIA_CONTROL
    cmp #(ACIA_STOP_BITS_1 | ACIA_DATA_BITS_8 | ACIA_CLOCK_INT | ACIA_BAUD_19200)
    bne @done
    lda #1
    sta acia_active
@done:
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
    clc                         ; no chr present
    lda ACIA_STATUS
    and #(ACIA_STATUS_RX_FULL)  ; mask rcvr full bit
    beq @done
    lda ACIA_DATA               ; else get chr
    sec                         ; and set the Carry Flag
@done:
    rts                         ; done


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
;   Preparatory Ops: ptr1, ptr+1 string pointer
;
;   Returned Values: none
;
;   Destroys:        .A, .X
;   ————————————————————————————————————
;
;================================================================================

ACIA_write_string:
    phy
    ldy #$00
@string_loop:
    lda (ptr1),y
    beq @end_loop
    jsr ACIA_write_byte
    iny
    beq @cross_page
    bne @string_loop
@cross_page:
    inc ptr1+1
    bra @string_loop
@end_loop:
    ply
    rts
