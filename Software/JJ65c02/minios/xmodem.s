; XMODEM/CRC Sender/Receiver for the 65C02
;
; By Daryl Rictor Aug 2002
;
; A simple file transfer program to allow transfers between the SBC  and a
; console device utilizing the x-modem/CRC transfer protocol.  Requires
; ~1200 bytes of either RAM or ROM, 132 bytes of RAM for the receive buffer,
; and 12 bytes of zero page RAM for variable storage.
;
;**************************************************************************
; This implementation of XMODEM/CRC does NOT conform strictly to the
; XMODEM protocol standard in that it (1) does not accurately time character
; reception or (2) fall back to the Checksum mode.

; (1) For timing, it uses a crude timing loop to provide approximate
; DELAYs.  These have been calibrated against a 1MHz CPU clock.  I have
; found that CPU clock speed of up to 5MHz also work but may not in
; every case.  Windows HyperTerminal worked quite well at both speeds!
;
; (2) Most modern terminal programs support XMODEM/CRC which can detect a
; wider range of transmission errors so the fallback to the simple checksum
; calculation was not implemented to save space.
;**************************************************************************
;
; Files transferred via XMODEM-CRC will have the load address contained in
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
; One note,xMODEM sends 128 byte blocks.  If the block of memory that
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

.export XMODEM_send
.export XMODEM_recv

LASTBLK = Z0        ; flag for last block
BLKNO = Z1          ; block number
ERRCNT = Z2         ; error counter 10 is the limit
BFLAG = Z3          ; block flag
DELAY = Z4          ; DELAY counter
PTR = ACIA_SPTR     ; data pointer (two byte variable)
EOFP = LCD_SPTR     ; end of file address pointer (2 bytes)
CRC = TEXT_BLK      ; CRC lo byte  (two byte variable)

.segment "CODE"

;^^^^^^^^^^^^^^^^^^^^^^ Start of Program ^^^^^^^^^^^^^^^^^^^^^^
;
; Xmodem/CRC transfer routines
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
;   XMODEM_send: Send data via xmodem protocol through ACIA
;
;   ————————————————————————————————————
;   Preparatory Ops:
;
;   Returned Values:
;   ————————————————————————————————————
;
;================================================================================

XMODEM_send:
    ACIA_writeln XM_start_msg      ; send prompt and info
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
    cmp #$0A                    ; are there 10 errors? (Xmodem spec for failure)
    bne @Resend                 ; no, resend block
@PrtAbort:
    jsr Flush                   ; yes, too many errors, flush buffer,
    ACIA_writeln XM_error_msg      ; print error msg and exit
@Done:
    lda #(EOT)
    jsr ACIA_write_byte
    ACIA_writeln XM_success_msg    ; All Done..Print msg and exit
    rts

;================================================================================
;
;   XMODEM_recv: Receive data via xmodem protocol through ACIA
;
;   ————————————————————————————————————
;   Preparatory Ops:
;
;   Returned Values:
;   ————————————————————————————————————
;
;================================================================================

XMODEM_recv:
    ACIA_writeln XM_start_msg      ; send prompt and info
    lda #$01
    sta BLKNO                   ; set block # to 1
    sta BFLAG                   ; set flag to get address from block 1
    stz CRC
    stz CRC+1
@StartCRC:
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
    bne @BadCRC                 ; Not SOH or EOT, so flush buffer & send NAK
    jmp @RDone                  ; EOT - all done!
@BegBlk:
    ldx #$00
@GetBlk:
    jsr GetByte                 ; get next character
    bcc @BadCRC                 ; chr rcv error, flush and send NAK
@GetBlk2:
    sta RECVB,x                 ; good char, save it in the rcv buffer
    inx                         ; INC buffer pointer
    cpx #132                    ; <01> <FE> <128 bytes> <CRCH> <CRCL>
    bne @GetBlk                 ; get 132 characters
    ldx #$00
    lda RECVB,x                 ; get block # from buffer
    cmp BLKNO                   ; compare to expected block #
    beq @GoodBlk1               ; matched!
    ACIA_writeln XM_error_msg      ; Unexpected block number - abort
    jsr Flush                   ; mismatched - flush buffer and then do BRK
    lda #$FD                    ; put error code in "A" if desired
    ;sta $1000                   ; XXX DEBUGGING
    rts                         ; unexpected block # - fatal error - BRK or RTS
@GoodBlk1:
    eor #$ff                    ; 1's comp of block #
    inx
    cmp RECVB,x                 ; compare with expected 1's comp of block #
    beq @GoodBlk2               ; matched!
    ACIA_writeln XM_error_msg      ; Unexpected block number - abort
    jsr Flush                   ; mismatched - flush buffer and then do BRK
    lda #$FC                    ; put error code in "A" if desired
    ;sta $1000                   ; XXX DEBUGGING
    rts                         ; bad 1's comp of block#
@GoodBlk2:
    jsr CalcCRC                 ; calc CRC
    lda RECVB,y                 ; get hi CRC from buffer
    cmp CRC+1                   ; compare to calculated hi CRC
    bne @BadCRC                 ; bad CRC, send NAK
    iny
    lda RECVB,y                 ; get lo CRC from buffer
    cmp CRC                     ; compare to calculated lo CRC
    beq @GoodCRC                ; good CRC
@BadCRC:
    jsr Flush                   ; flush the input port
    lda #(NAK)
    jsr ACIA_write_byte         ; send NAK to resend block
    jmp @StartBlk               ; Start over, get the block again
@GoodCRC:
    ldx #$02
    lda BLKNO                   ; get the block number
    cmp #$01                    ; 1st block?
    bne @CopyBlk                ; no, copy all 128 bytes
    lda BFLAG                   ; is it really block 1, not block 257, 513 etc.
    beq @CopyBlk                ; no, copy all 128 bytes
    lda RECVB,x                 ; get target address from 1st 2 bytes of blk 1
    sta PTR                     ; save lo address
    inx
    lda RECVB,x                 ; get hi address
    sta PTR+1                   ; save it
    inx                         ; point to first byte of data
    dec BFLAG                   ; set the flag so we won't get another address
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
    jmp @StartBlk               ; get next block

@RDone:
    lda #(ACK)                  ; last block, send ACK and exit.
    jsr ACIA_write_byte
    jsr Flush                   ; get leftover characters, if any
    lda #(EOT)
    jsr ACIA_write_byte
    ACIA_writeln XM_success_msg
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
    jsr LIB_DELAY1ms
    dec DELAY                   ; 3 sec wait
    bne @StartCRCLp             ; look for character again
    clc                         ; if loop times out, CLC, else SEC and return
@GotByte:
    rts                         ; with character in "A"
;
Flush:
    jsr GetByte                 ; read the port
    bcs Flush                   ; if chr recvd, wait for another
    rts                         ; else done
;
;=========================================================================
;
;  CRC subroutines
;
CalcCRC:
    lda #$00                    ; yes, calculate the CRC for the 128 bytes
    sta CRC
    sta CRC+1
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

