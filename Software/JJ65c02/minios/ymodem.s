; YMODEM/CRC Sender/Receiver for the 65C02
;
; By Daryl Rictor Aug 2002
;
; A simple file transfer program to allow transfers between the SBC  and a
; console device utilizing the x-modem/CRC transfer protocol.  Requires
; ~1200 bytes of either RAM or ROM, 132 bytes of RAM for the receive buffer,
; and 12 bytes of zero page RAM for variable storage.
;
;**************************************************************************
; This implementation of YMODEM/CRC does NOT conform strictly to the
; YMODEM protocol standard in that it (1) does not accurately time character
; reception or (2) fall back to the Checksum mode.

; (1) For timing, it uses a crude timing loop to provide approximate
; DELAYs.  These have been calibrated against a 1MHz CPU clock.  I have
; found that CPU clock speed of up to 5MHz also work but may not in
; every case.  Windows HyperTerminal worked quite well at both speeds!
;
; (2) Most modern terminal programs support YMODEM/CRC which can detect a
; wider range of transmission errors so the fallback to the simple checksum
; calculation was not implemented to save space.
;**************************************************************************
;
; Files transferred via YMODEM-CRC will have the load address contained in
; the first two bytes in little-endian format:
;  FIRST BLOCK
;     offset(0) = lo(load start address),
;     offset(1) = hi(load start address)
;     offset(2) = data byte (0)
;     offset(n) = data byte (n-2)
;
; Subsequent blocks
;     offset(n) = data byte (n)
;
; One note,YMODEM sends 128 byte blocks.  If the block of memory that
; you wish to save is smaller than the 128 byte block boundary, then
; the last block will be padded with zeros.  Upon reloading, the
; data will be written back to the original location.  In addition, the
; padded zeros WILL also be written into RAM, which could overwrite other
; data.
;

.include "minios.inc"
.include "sysram.inc"
.include "tty.h"
.include "acia.inc"
.include "lib.inc"
.include "lcd.inc"

.export YMODEM_send
.export YMODEM_recv

LASTBLK = Z0        ; flag for last block
BLKNO = Z1          ; block number
ERRCNT = Z2         ; error counter 10 is the limit
BFLAG = Z3          ; block flag
DELAY = Z4          ; DELAY counter

.segment "ZEROPAGE"
PTR:    .res 2      ; data pointer (two byte variable)
EOFP:   .res 2      ; end of file address pointer (2 bytes)
CRC:    .res 2      ; CRC lo byte  (two byte variable)

.segment "CODE"

;^^^^^^^^^^^^^^^^^^^^^^ Start of Program ^^^^^^^^^^^^^^^^^^^^^^
;
; YMODEM/CRC transfer routines
; By Daryl Rictor, August 8, 2002
;
; v1.0  released on Aug 8, 2002.
;
; Enter this routine with the beginning address stored in the zero page address
; pointed to by PTR & PTR+1 and the ending address stored in the zero page address
; pointed to by EOFP & EOFP+1.
;
;

;================================================================================
;
;   YMODEM_send: Send data via YMODEM protocol through ACIA
;
;   ————————————————————————————————————
;   Preparatory Ops:
;
;   Returned Values:
;   ————————————————————————————————————
;
;================================================================================

YMODEM_send:
.ifdef _BUILD_YMODEM_send_
    ACIA_writeln YM_start_msg      ; send prompt and info
    lda #$00
    sta ERRCNT                  ; error counter set to 0
    sta LASTBLK                 ; set flag to false
    lda #$01
    sta BLKNO                   ; set block # to 1
@Wait4CRC:
    jsr GetByte
    bcc @Wait4CRC               ; wait for something to come in...
    cmp #'C'                    ; is it the "C" to start a CRC xfer?
    beq @SetstAddr              ; yes
    cmp #(ESC)                  ; is it a cancel? <Esc> Key
    bne @Wait4CRC               ; No, wait for another character
    jmp @PrtAbort               ; Print abort msg and exit
@SetstAddr:
    ldy #$00                    ; init data block offset to 0
    ldx #$04                    ; preload X to Receive buffer
    lda #$01                    ; manually load blk number
    sta RECVB                   ; into 1st byte
    lda #$FE                    ; load 1's comp of block #
    sta RECVB+1                 ; into 2nd byte
    lda PTR                     ; load low byte of start address
    sta RECVB+2                 ; into 3rd byte
    lda PTR+1                   ; load hi byte of start address
    sta RECVB+3                 ; into 4th byte
    bra @LdBuff1                ; jump into buffer load routine

@LdBuffer:
    lda LASTBLK                 ; Was the last block sent?
    beq @LdBuff0                ; no, send the next one
    jmp @Done                   ; yes, we're done
@LdBuff0:
    ldx #$02                    ; init pointers
    ldy #$00
    inc BLKNO                   ; INC  block counter
    lda BLKNO
    sta RECVB                   ; save in 1st byte of buffer
    eor #$FF
    sta RECVB+1                 ; save 1's comp of BLKNO next
@LdBuff1:
    lda (PTR),y                 ; save 128 bytes of data
    sta RECVB,x
@LdBuff2:
    sec
    lda EOFP
    sbc PTR                     ; Are we at the last address?
    bne @LdBuff4                ; no, INC  pointer and continue
    lda EOFP+1
    sbc PTR+1
    bne @LdBuff4
    inc LASTBLK                 ; Yes, Set last byte flag
@LdBuff3:
    inx
    cpx #$82                    ; Are we at the end of the 128 byte block?
    beq @SCalcCRC               ; Yes, calc CRC
    lda #$00                    ; Fill rest of 128 bytes with $00
    sta RECVB,x
    beq @LdBuff3                ; Branch always
@LdBuff4:
    inc PTR                     ; INC address pointer
    bne @LdBuff5
    inc PTR+1
@LdBuff5:
    inx
    cpx #$82                    ; last byte in block?
    bne @LdBuff1                ; no, get the next
@SCalcCRC:
    jsr CalcCRC
    lda CRC+1                   ; save Hi byte of CRC to buffer
    sta RECVB,y
    iny
    lda CRC                     ; save lo byte of CRC to buffer
    sta RECVB,y
@Resend:
    ldx #$00
    lda #(SOH)
    jsr ACIA_write_byte         ; send SOH
@SendBlk:
    lda RECVB,x                 ; Send 132 bytes in buffer to the console
    jsr ACIA_write_byte
    inx
    cpx #$84                    ; last byte?
    bne @SendBlk                ; no, get next
    jsr GetByte                 ; Wait for Ack/Nack
    bcc @Seterror               ; No chr received after 3 seconds, resend
    cmp #(ACK)                  ; Chr received... is it:
    beq @LdBuffer               ; ACK, send next block
    cmp #(NAK)
    beq @Seterror               ; NAK, INC errors and resend
    cmp #(ESC)
    beq @PrtAbort               ; Esc pressed to abort
    ; fall through to error counter
@Seterror:
    inc ERRCNT                  ; INC error counter
    lda ERRCNT
    cmp #$0A                    ; are there 10 errors? (YMODEM spec for failure)
    bne @Resend                 ; no, resend block
@PrtAbort:
    jsr ACIA_flush_rbuff
    ACIA_writeln YM_error_msg      ; print error msg and exit
@Done:
    lda #(EOT)
    jsr ACIA_write_byte
    ACIA_writeln YM_success_msg    ; All Done..Print msg and exit
.endif
    rts

;================================================================================
;
;   YMODEM_recv: Receive data via YMODEM protocol through ACIA
;
;   ————————————————————————————————————
;   Preparatory Ops: Load address must be stored in PTR,PTR+1
;
;   Returned Values:
;   ————————————————————————————————————
;
;================================================================================

YMODEM_recv:
    ACIA_writeln YM_start_msg      ; send prompt and info
    jsr LCD_clear_video_ram
    jsr LCD_clear_screen
    stz BLKNO                   ; YMODEM starts w/ block #0, which we ignore
    stz BFLAG
    stz CRC
    stz CRC+1
@StartCRC:
    jsr ACIA_flush_rbuff
    lda #'C'                    ; "C" start with CRC mode
    jsr ACIA_write_byte         ; send it
    jsr GetByte                 ; wait for input
    bcs @GotByte                ; byte received, process it
    bcc @StartCRC               ; resend "C"

@StartBlk:
    jsr GetByte                 ; get first byte of block
    bcc @StartBlk               ; timed out, keep waiting...
@GotByte:
    cmp #(ESC)                  ; quitting?
    bne @GotByte1               ; no
    lda #$FE                    ; Error code in "A" of desired
    ;sta $1000                   ; XXX DEBUGGING
    rts                         ; YES - do BRK or change to RTS if desired
@GotByte1:
    cmp #(SOH)                  ; Start of block?
    beq @BegBlk                 ; yes
    cmp #(EOT)
    beq @done                   ; Not SOH or EOT, so flush buffer & send NAK
    jmp @BadByte1
@done:
    jmp @RDone                  ; EOT - all done!
@BegBlk:
    ldx #$00
@GetBlk:
    jsr GetByte                 ; get next character
    bcc @BadByte                ; chr rcv error, flush and send NAK
@GetBlk2:
    sta RECVB,x                 ; good char, save it in the rcv buffer
    inx                         ; INC buffer pointer
    cpx #132                    ; <01> <FE> <128 bytes> <CRCH> <CRCL>
    bne @GetBlk                 ; get 132 characters
    ldx #$00
    lda RECVB,x                 ; get block # from buffer
    cmp BLKNO                   ; compare to expected block #
    beq @GoodBlk1               ; matched!
    ACIA_writeln YM_error_msg   ; Unexpected block number - abort
    LCD_writeln YM_error_msg    ; Unexpected block number - abort
    jsr ACIA_flush_rbuff        ; mismatched - flush buffer and then do BRK
    lda #$FD                    ; put error code in "A" if desired
    ;sta $1000                   ; XXX DEBUGGING
    rts                         ; unexpected block # - fatal error - BRK or RTS

@BadByte:
    ldy #02
    ldx #00
    jsr LCD_set_cursor
    lda #'B'
    jsr LCD_send_data
    jsr ACIA_flush_rbuff
    lda #(NAK)
    jsr ACIA_write_byte         ; send NAK to resend block
    jmp @StartBlk

@GoodBlk1:
    eor #$ff                    ; 1's comp of block #
    inx
    cmp RECVB,x                 ; compare with expected 1's comp of block #
    beq @GoodBlk2               ; matched!
    ACIA_writeln YM_error_msg   ; Unexpected block number - abort
    LCD_writeln YM_error_msg    ; Unexpected block number - abort
    jsr ACIA_flush_rbuff        ; mismatched - flush buffer and then do BRK
    lda #$FC                    ; put error code in "A" if desired
    ;sta $1000                   ; XXX DEBUGGING
    rts                         ; bad 1's comp of block#
@GoodBlk2:
    jsr CalcCRC                 ; calc CRC
    lda RECVB,y                 ; get hi CRC from buffer
    cmp CRC+1                   ; compare to calculated hi CRC
    bne @BadCRCH                ; bad CRC, send NAK
    iny
    lda RECVB,y                 ; get lo CRC from buffer
    cmp CRC                     ; compare to calculated lo CRC
    bne @BadCRCL
    jmp @GoodCRC                ; good CRC
@BadCRCH:
    lda #'H'
    bra @BadCRC
@BadCRCL:
    lda #'L'
@BadCRC:
    ldy #01
    ldx #00
    jsr LCD_set_cursor
    jsr LCD_send_data
    jsr ACIA_flush_rbuff
    lda #(NAK)
    jsr ACIA_write_byte         ; send NAK to resend block
    jmp @StartBlk

@BadByte1:
    ldy #01
    ldx #04
    jsr LCD_set_cursor
    jsr LIB_bin_to_hex
    pha
    txa
    jsr LCD_send_data
    pla
    jsr LCD_send_data
    jsr ACIA_flush_rbuff
    lda #(NAK)
    jsr ACIA_write_byte         ; send NAK to resend block
    jmp @StartBlk               ; Start over, get the block again
@GoodCRC:
    ldx #$02
    lda BLKNO                   ; get the block number
    cmp #$00                    ; YMODEM block #0?
    bne @CopyBlk                ; no, copy all 128 bytes
    lda BFLAG                   ; is it really block 0
    bne @CopyBlk                ; no, copy all 128 bytes
    ;
    ; What we have is YMODEM's blk 0, which we just ignore
    ;
    inc BFLAG                   ; set the flag so we won't trigger again
    inc BLKNO                   ; done. INC the block #
    lda #(ACK)                  ; send ACK
    jsr ACIA_write_byte
    jmp @StartCRC               ; and restart the actual data xfer
@CopyBlk:
    ldy  #$00                   ; set offset to zero
@CopyBlk3:
    lda RECVB,x                 ; get data byte from buffer
    sta (PTR),y                 ; save to target
    inc PTR                     ; point to next address
    bne @CopyBlk4               ; did it step over page boundary?
    inc PTR+1                   ; adjust high address for page crossing
@CopyBlk4:
    inx                         ; point to next data byte
    cpx #$82                    ; is it the last byte (all 128)?
    bne @CopyBlk3               ; no, get the next one
@IncBlk:
    inc BLKNO                   ; done. INC the block #
    lda #(ACK)                  ; send ACK
    jsr ACIA_write_byte
    ldy #00
    ldx #02
    jsr LCD_set_cursor
    lda BLKNO
    jsr LIB_bin_to_hex
    pha
    txa
    jsr LCD_send_data
    pla
    jsr LCD_send_data
    jmp @StartBlk               ; get next block

@RDone:
    lda #(ACK)                  ; last block, send ACK and exit.
    jsr ACIA_write_byte
    jsr ACIA_flush_rbuff
    lda #(EOT)
    jsr ACIA_write_byte
    ACIA_writeln YM_success_msg
    rts
;
;=========================================================================
;
; subroutines
;
GetByte:
    lda #150                    ; wait for chr input and cycle timing loop
    sta DELAY                   ; set low value of timing loop
@StartCRCLp:
    jsr ACIA_read_byte          ; get chr from serial port, don't wait
    bcs @GotByte                ; got one, so exit
    lda #20
    jsr LIB_delay1ms
    dec DELAY                   ; 3 sec wait
    bne @StartCRCLp             ; look for character again
    clc                         ; if loop times out, CLC, else SEC and return
@GotByte:
    rts                         ; with character in "A"

;
;=========================================================================
;
;  CRC subroutines
;
CalcCRC:
    stz CRC
    stz CRC+1
    ldy #$02
@CalcCRC1:
    lda RECVB,y
    eor CRC+1                   ; Quick CRC computation with lookup tables
    tax                         ; updates the two bytes at CRC & CRC+1
    lda CRC                     ; with the byte send in the "A" register
    eor CRChi,x
    sta CRC+1
    lda CRClo,x
    sta CRC
    iny
    cpy #$82                    ; done yet?
    bne @CalcCRC1               ; no, get next
    rts                         ; y=82 on exit

.segment "RODATA"

YM_start_msg:      .asciiz "Begin YMODEM transfer.  Press <Esc> to abort...\n\r"
YM_error_msg:      .asciiz "Transfer Error!\n\r"
YM_success_msg:    .asciiz "\n\rTransfer Successful!\n\r"

.segment "RODATA_PA"

; The following tables are used to calculate the CRC for the 128 bytes
; in the YMODEM data blocks.  You can use these tables if you plan to
; store this program in ROM.  If you choose to build them at run-time,
; then just delete them and define the two labels: CRClo & CRChi.
;
; low byte CRC lookup table (should be page aligned)
.align 256
CRClo:  .byte $00,$21,$42,$63,$84,$A5,$C6,$E7,$08,$29,$4A,$6B,$8C,$AD,$CE,$EF
        .byte $31,$10,$73,$52,$B5,$94,$F7,$D6,$39,$18,$7B,$5A,$BD,$9C,$FF,$DE
        .byte $62,$43,$20,$01,$E6,$C7,$A4,$85,$6A,$4B,$28,$09,$EE,$CF,$AC,$8D
        .byte $53,$72,$11,$30,$D7,$F6,$95,$B4,$5B,$7A,$19,$38,$DF,$FE,$9D,$BC
        .byte $C4,$E5,$86,$A7,$40,$61,$02,$23,$CC,$ED,$8E,$AF,$48,$69,$0A,$2B
        .byte $F5,$D4,$B7,$96,$71,$50,$33,$12,$FD,$DC,$BF,$9E,$79,$58,$3B,$1A
        .byte $A6,$87,$E4,$C5,$22,$03,$60,$41,$AE,$8F,$EC,$CD,$2A,$0B,$68,$49
        .byte $97,$B6,$D5,$F4,$13,$32,$51,$70,$9F,$BE,$DD,$FC,$1B,$3A,$59,$78
        .byte $88,$A9,$CA,$EB,$0C,$2D,$4E,$6F,$80,$A1,$C2,$E3,$04,$25,$46,$67
        .byte $B9,$98,$FB,$DA,$3D,$1C,$7F,$5E,$B1,$90,$F3,$D2,$35,$14,$77,$56
        .byte $EA,$CB,$A8,$89,$6E,$4F,$2C,$0D,$E2,$C3,$A0,$81,$66,$47,$24,$05
        .byte $DB,$FA,$99,$B8,$5F,$7E,$1D,$3C,$D3,$F2,$91,$B0,$57,$76,$15,$34
        .byte $4C,$6D,$0E,$2F,$C8,$E9,$8A,$AB,$44,$65,$06,$27,$C0,$E1,$82,$A3
        .byte $7D,$5C,$3F,$1E,$F9,$D8,$BB,$9A,$75,$54,$37,$16,$F1,$D0,$B3,$92
        .byte $2E,$0F,$6C,$4D,$AA,$8B,$E8,$C9,$26,$07,$64,$45,$A2,$83,$E0,$C1
        .byte $1F,$3E,$5D,$7C,$9B,$BA,$D9,$F8,$17,$36,$55,$74,$93,$B2,$D1,$F0

; hi byte CRC lookup table (should be page aligned)
.align 256
CRChi:  .byte $00,$10,$20,$30,$40,$50,$60,$70,$81,$91,$A1,$B1,$C1,$D1,$E1,$F1
        .byte $12,$02,$32,$22,$52,$42,$72,$62,$93,$83,$B3,$A3,$D3,$C3,$F3,$E3
        .byte $24,$34,$04,$14,$64,$74,$44,$54,$A5,$B5,$85,$95,$E5,$F5,$C5,$D5
        .byte $36,$26,$16,$06,$76,$66,$56,$46,$B7,$A7,$97,$87,$F7,$E7,$D7,$C7
        .byte $48,$58,$68,$78,$08,$18,$28,$38,$C9,$D9,$E9,$F9,$89,$99,$A9,$B9
        .byte $5A,$4A,$7A,$6A,$1A,$0A,$3A,$2A,$DB,$CB,$FB,$EB,$9B,$8B,$BB,$AB
        .byte $6C,$7C,$4C,$5C,$2C,$3C,$0C,$1C,$ED,$FD,$CD,$DD,$AD,$BD,$8D,$9D
        .byte $7E,$6E,$5E,$4E,$3E,$2E,$1E,$0E,$FF,$EF,$DF,$CF,$BF,$AF,$9F,$8F
        .byte $91,$81,$B1,$A1,$D1,$C1,$F1,$E1,$10,$00,$30,$20,$50,$40,$70,$60
        .byte $83,$93,$A3,$B3,$C3,$D3,$E3,$F3,$02,$12,$22,$32,$42,$52,$62,$72
        .byte $B5,$A5,$95,$85,$F5,$E5,$D5,$C5,$34,$24,$14,$04,$74,$64,$54,$44
        .byte $A7,$B7,$87,$97,$E7,$F7,$C7,$D7,$26,$36,$06,$16,$66,$76,$46,$56
        .byte $D9,$C9,$F9,$E9,$99,$89,$B9,$A9,$58,$48,$78,$68,$18,$08,$38,$28
        .byte $CB,$DB,$EB,$FB,$8B,$9B,$AB,$BB,$4A,$5A,$6A,$7A,$0A,$1A,$2A,$3A
        .byte $FD,$ED,$DD,$CD,$BD,$AD,$9D,$8D,$7C,$6C,$5C,$4C,$3C,$2C,$1C,$0C
        .byte $EF,$FF,$CF,$DF,$AF,$BF,$8F,$9F,$6E,$7E,$4E,$5E,$2E,$3E,$0E,$1E

