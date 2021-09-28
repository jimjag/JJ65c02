.include "minios.inc"
    
.import __SERIAL_START__
.import LIB_delay1ms
.export ACIA_DATA
.export ACIA_STATUS
.export ACIA_COMMAND
.export ACIA_CONTROL

.export ACIA_init
.export ACIA_irq_handler
.export ACIA_is_data_available
.export ACIA_read_byte
.export ACIA_write_byte
.export ACIA_write_string

.import __ACIA_START__
ACIA_DATA    = __ACIA_START__ + $10
ACIA_STATUS  = __ACIA_START__ + $11
ACIA_COMMAND = __ACIA_START__ + $12
ACIA_CONTROL = __ACIA_START__ + $13

ACIA_STOP_BITS_1 = %00000000
ACIA_STOP_BITS_2 = %10000000
ACIA_DATA_BITS_8 = %00000000
ACIA_DATA_BITS_7 = %00100000
ACIA_DATA_BITS_6 = %01000000
ACIA_DATA_BITS_5 = %01100000
ACIA_CLOCK_EXT   = %00000000
ACIA_CLOCK_INT   = %00010000
ACIA_BAUD_16XEXT = %00000000
ACIA_BAUD_50     = %00000001
ACIA_BAUD_75     = %00000010
ACIA_BAUD_109    = %00000011
ACIA_BAUD_134    = %00000100
ACIA_BAUD_150    = %00000101
ACIA_BAUD_300    = %00000110
ACIA_BAUD_600    = %00000111
ACIA_BAUD_1200   = %00001000
ACIA_BAUD_1800   = %00001001
ACIA_BAUD_2400   = %00001010
ACIA_BAUD_3600   = %00001011
ACIA_BAUD_4800   = %00001100
ACIA_BAUD_7200   = %00001101
ACIA_BAUD_9600   = %00001110
ACIA_BAUD_19200  = %00001111

; ACIA command register bit values

ACIA_PARITY_ODD              = %00000000
ACIA_PARITY_EVEN             = %01000000
ACIA_PARITY_MARK             = %10000000
ACIA_PARITY_SPACE            = %11000000
ACIA_PARITY_DISABLE          = %00000000
ACIA_PARITY_ENABLE           = %00100000
ACIA_ECHO_DISABLE            = %00000000
ACIA_ECHO_ENABLE             = %00010000
ACIA_TX_INT_DISABLE_RTS_HIGH = %00000000
ACIA_TX_INT_ENABLE_RTS_LOW   = %00000100
ACIA_TX_INT_DISABLE_RTS_LOW  = %00001000
ACIA_TX_INT_DISABLE_BREAK    = %00001100
ACIA_RX_INT_ENABLE           = %00000000
ACIA_RX_INT_DISABLE          = %00000010
ACIA_DTR_HIGH                = %00000000
ACIA_DTR_LOW                 = %00000001

; ACIA status register bit masks

ACIA_STATUS_IRQ        = 1 << 7
ACIA_STATUS_DSR        = 1 << 6
ACIA_STATUS_DCD        = 1 << 5
ACIA_STATUS_TX_EMPTY   = 1 << 4
ACIA_STATUS_RX_FULL    = 1 << 3
ACIA_STATUS_OVERRUN    = 1 << 2
ACIA_STATUS_FRAME_ERR  = 1 << 1
ACIA_STATUS_PARITY_ERR = 1 << 0

ACIA_DATA_AVAILABLE    = $01
ACIA_NO_DATA_AVAILABLE = $00

ACIA_BUFFER_SIZE       = 32

.segment "ZEROPAGE"
ptr1:       .res 2

.segment "SYSRAM"
acia_tx_iptr:   .res 1
acia_tx_optr:   .res 1
acia_rx_iptr:   .res 1
acia_rx_optr:   .res 1
acia_rx_buffer: .res ACIA_BUFFER_SIZE
acia_tx_buffer: .res ACIA_BUFFER_SIZE

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
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

ACIA_init:
    lda #(ACIA_PARITY_DISABLE | ACIA_ECHO_DISABLE | ACIA_TX_INT_DISABLE_RTS_LOW | ACIA_RX_INT_ENABLE | ACIA_DTR_LOW)
    sta ACIA_COMMAND
    lda #(ACIA_STOP_BITS_1 | ACIA_DATA_BITS_8 | ACIA_CLOCK_INT | ACIA_BAUD_19200)
    sta ACIA_CONTROL
    stz acia_rx_iptr
    stz acia_rx_optr
    stz acia_tx_iptr
    stz acia_tx_optr
    rts

;================================================================================
;
;   ACIA_irq_handler - Handles the R6551 IRQ
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

ACIA_irq_handler:
    pha
    phx
    lda ACIA_STATUS
    cmp #$80
    beq @cts_high                           ; Stop processing if only CTS is high
    asl                                     ; IRQ
    asl                                     ; DSR
    asl                                     ; DCD
    asl                                     ; Test the RX bit now
    bpl @rx_full_exit                       ; Receive buffer full
    pha
    lda ACIA_DATA
    ldx acia_rx_optr
    sta acia_rx_buffer,x
    inc acia_rx_optr
    ; Check for receive buffer overflow condition
    lda acia_rx_optr
    sec
    sbc acia_rx_iptr
    ; We have more than allowed characters to service in queue - overflow
    cmp #(ACIA_BUFFER_SIZE)
    bcc @no_rx_overflow
    ; Raise RTS line to stop inflow
    lda ACIA_COMMAND
    and #%11110011
    ; ora #%00000001
    sta ACIA_COMMAND
@no_rx_overflow:
    pla
@rx_full_exit:
    ; Ignore overrun
    ; Ignore framing error
    ; Ignore parity error
@cts_high:
    plx
    pla
    rts

;================================================================================
;
;   ACIA_is_data_available - determines if there is anything to
;   receive and return in .A
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

ACIA_is_data_available:
    lda acia_rx_optr
    cmp acia_rx_iptr
    beq @no_data_found
    lda #(ACIA_DATA_AVAILABLE)
    rts
@no_data_found:
    lda #(ACIA_NO_DATA_AVAILABLE)
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
    jsr ACIA_is_data_available
    cmp #(ACIA_DATA_AVAILABLE)
    bcc @done                           ; .A < $01
    phx
    ldx acia_rx_iptr
    lda acia_rx_buffer,x
    inc acia_rx_iptr                    ; Increase read buffer pointer
    tax                                 ; Store result in X for a while now
    lda acia_rx_optr                    ; Check how many chars?
    sec
    sbc acia_rx_iptr
    cmp #(ACIA_BUFFER_SIZE)             ; More than buffer - still overflow
    bcs @still_rx_overflow
    lda ACIA_COMMAND
    and #%11110011
    ; We might enable the TX empty interrupt without any data to write
    ; but there is no way of checking it, and the interrupt will 
    ; correct the setting if it should not be enabled
    ora #(ACIA_TX_INT_ENABLE_RTS_LOW)
    sta ACIA_COMMAND
@still_rx_overflow:
    txa                                 ; result
    plx
    sec                                 ; note that we have data
@done:
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
    sta ACIA_DATA
    pha
    lda #$01                            ; wait 1ms (more than 520us for 19200 baud)
    jsr LIB_delay1ms
    pla
    rts

;================================================================================
;
;   ACIA_write_string - Write null-terminated string
;
;   ————————————————————————————————————
;   Preparatory Ops: .A, .X: Input pointer (.A low, .X high)
;
;   Returned Values: none
;
;   Destroys:        .A, .X
;   ————————————————————————————————————
;
;================================================================================

ACIA_write_string:
    sta ptr1
    stx ptr1+1
    phy
    ldy #$00
@string_loop:
    lda (ptr1),y
    beq @end_loop
    jsr ACIA_write_byte
    iny 
    beq @end_loop
    bra @string_loop
@end_loop:
    ply
    rts
