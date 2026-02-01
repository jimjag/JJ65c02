.setcpu "w65c02"

.include "minios.inc"
.include "sysram.inc"
.include "tty.inc"
.include "console.inc"

.importzp BASIC_ZP_start
.export SUPER_main
ENABLE_ASSEMBLER = 1
; ********************************************************
; * SUPERMON based on JIM BUTTERFIELD's SUPERMON+ 64 *
; ********************************************************

; Adapted from J.B. Langston's reformatted and annotated SUPERMON+ 64
; source by Andrew Taylor.. Original Commodore PET version by Wozniak & Baum,
; Russo, Seiler, and Butterfield
;:
; * The e'X'it command returns to the miniOS main menu
; * The input routine handles ^h as backspace and lower case letters
;   are converted to upper case

; -----------------------------------------------------------------------------
; variables
.segment "ZEROPAGE"

UseTTY  := BASIC_ZP_start
ACMD    := UseTTY+1         ; addressing command
LENGTH  := ACMD+1           ; length of operand
MNEMW   := LENGTH+1         ; 3 letter mnemonic buffer
SAVX    := MNEMW+3          ; 1 byte temp storage, often to save X register
OPCODE  := SAVX+1           ; current opcode for assembler/disassembler
UPFLG   := OPCODE+1         ; flag: count up (bit 7 clear) or down (bit 7 set)
DIGCNT  := UPFLG+1          ; digit count
INDIG   := DIGCNT+1         ; numeric value of single digit
NUMBIT  := INDIG+1          ; numeric base of input
STASH   := NUMBIT+1         ; 2-byte temp storage
U0AA0   := STASH+2          ; work buffer
U0AAE   := U0AA0+10         ; end of work buffer
STAGE   := U0AAE+1          ; staging buffer for filename, search, etc.
ESTAGE  := STAGE+30         ; end of staging buffer
INBUFF  := ESTAGE+1         ; 40-character input buffer
ENDIN   := INBUFF+40        ; end of input buffer

; the next 7 locations are used to store the registers when
; entering the monitor and restore them when exiting.

PCH     := ENDIN+1          ; program counter high byte
PCL     := PCH+1            ; program counter low byte
SR      := PCL+1            ; status register
ACC     := SR+1             ; accumulator
XR      := ACC+1            ; X register
YR      := XR+1             ; Y register
SP      := YR+1             ; stack pointer

STORE   := SP+1             ; 2-byte temp storage
CHRPNT  := STORE+2          ; current position in input buffer
SAVY    := CHRPNT+1         ; temp storage, often to save Y register
U9F     := SAVY+1           ; index into assembler work buffer

DISPMEM_BPL      := U9F+1   ; number of bytes per line to display in DISPMEM
DISPMEM_BPL_LOG2 := DISPMEM_BPL+1    ; log 2 of DISPMEM_BPL

; temporary pointers
TMP0    := R0; DISPMEM_BPL_LOG2+1  ; used to return input, often holds end address
TMP2    := R1; TMP0+2              ; usually holds start address - 2 bytes

; -----------------------------------------------------------------------------
; kernal entry points (KIM)
GETCH   = MN_IOVRBW_c          ; blocking input a character (like CHRIN) and echo it
OUTCH   = MN_IOVW_c            ; output a character (like CHROUT)

; -----------------------------------------------------------------------------
; set up origin

.segment "CODE"

;:
; -----------------------------------------------------------------------------
; initial entry point

SUPER_main:
    lda #(EHBASIC_ZP_CORRUPTED_FLAG)
    tsb MINIOS_STATUS
    ldy #MSG4-MSGBAS            ; display banner
    jsr SNDMSG
    lda SUPAD
    ldx SUPAD+1
    jsr WRADDR                  ; print it in 4 hex digits
    jsr CRLF
    lda #16
    sta DISPMEM_BPL
    lda #4
    sta DISPMEM_BPL_LOG2

; -----------------------------------------------------------------------------
; display registers [R]
DSPLYR:
    ldy #MSG2-MSGBAS            ; display headers
    jsr SNDCLR
    lda #$3B                    ; prefix registers with "; " to allow editing
    jsr CHROUT
    lda #$20
    jsr CHROUT
    lda PCH                     ; print 2-byte program counter
    jsr WRTWO
    ldy #1                      ; start 1 byte after PC high byte
DISJ:
    lda PCH,Y                   ; loop through rest of the registers
    jsr WRBYTE                  ; print 1-byte register value
    iny
    cpy #7                      ; there are a total of 5 registers to print
    bcc DISJ

; -----------------------------------------------------------------------------
; main loop
STRT:
    jsr CRLF                    ; new line
    ldx #0                      ; point at start of input buffer
    stx CHRPNT
SMOVE:
    jsr INPUT                   ; CHRIN kernal call to input a character
    cmp #$61
    blt @CONT
    sec
    sbc #$20
@CONT:
    cmp #$08                    ; check for backspace
    bne NBS
    dex                         ; if backspace, backup
    bpl SMOVE                   ; too far?
    inx                         ; go back
    jmp SMOVE
NBS:
    sta INBUFF,X                ; store in input buffer
    inx
    cpx #ENDIN-INBUFF           ; error if buffer is full
    bcs ERROR
    cmp #$0D                    ; keep reading until CR
    bne SMOVE
    lda #0                      ; null-terminate input buffer
    sta INBUFF-1,X              ; (replacing the CR)
ST1:
    jsr GETCHR                  ; get a character from the buffer
    beq STRT                    ; start over if buffer is empty
    cmp #$20                    ; skip leading spaces
    beq ST1
S0:
    ldx #KEYTOP-KEYW            ; loop through valid command characters
S1:
    cmp KEYW,X                  ; see if input character matches
    beq S2                      ; command matched, dispatch it
    dex                         ; no match, check next command
    bpl S1                      ; keep trying until we've checked them all
                            ; then fall through to error handler

; -----------------------------------------------------------------------------
; handle error
ERROR:
    ldy #MSG3-MSGBAS            ; display '?' to indicate error and go to new line
    jsr SNDMSG
    jmp STRT                    ; back to main loop

; -----------------------------------------------------------------------------
; dispatch command
S2:
    cpx #$10                    ; last 4 commands are base conversions
    bcs CNVLNK                  ;   which are handled by the same subroutine
    txa                         ; remaining commands dispatch through vector table
    asl A                       ; multiply index of command by 2
    tax                         ;   since table contains 2-byte addresses
    lda KADDR+1,X               ; push address from vector table onto stack
    pha                         ;   so that the RTS from GETPAR will jump there
    lda KADDR,X
    pha
    jmp GETPAR                  ; get the first parameter for the command
CNVLNK:
    jmp CONVRT                  ; handle base conversion

; -----------------------------------------------------------------------------
; exit monitor [X]
EXIT:
    jmp MINIOS_main_menu        ; jump to miniOS

; -----------------------------------------------------------------------------
; display memory [M]
DSPLYM:
    bcs DSPM11                  ; start from previous end addr if no address given
    jsr COPY12                  ; save start address in TMP2
    jsr GETPAR                  ; get end address in TMP0
    bcc DSMNEW                  ; did user specify one?
DSPM11:
    lda #$0B                    ; if not, show 12 lines by default
    sta TMP0
    bne DSPBYT                  ; always true, but BNE uses 1 byte less than JMP
DSMNEW:
    jsr SUB12                   ; end addr given, calc bytes between start and end
    bcc MERROR                  ; error if start is after end
    ldx DISPMEM_BPL_LOG2        ; divide by 8 (shift right 3 times)
DSPM01:
    lsr TMP0+1
    ror TMP0
    dex
    bne DSPM01
DSPBYT:
    jsr STOP                    ; check for stop key
    beq DSPMX                   ; exit early if pressed
    jsr DISPMEM                 ; display 1 line containing 8 bytes
    lda DISPMEM_BPL             ; increase start address by 8 bytes
    jsr BUMPAD2
    jsr SUBA1                   ; decrement line counter
    bcs DSPBYT                  ; show another line until it's < 0
DSPMX:
    jmp STRT                    ; back to main loop
MERROR:
    jmp ERROR                   ; handle error

; -----------------------------------------------------------------------------
; alter registers [;]
ALTR:
    jsr COPY1P                  ; store first parameter in PC
    ldy #0                      ; init counter
ALTR1:
    jsr GETPAR                  ; get value for next register
    bcs ALTRX                   ; exit early if no more values given
    lda TMP0                    ; store in memory, offset from SR
    sta SR,Y                    ; these locations will be transferred to the
    iny                         ;   actual registers before exiting the monitor
    cpy #$05                    ; have we updated all 5 yet?
    bcc ALTR1                   ; if not, get next
ALTRX:
    jmp STRT                    ; back to main loop

; -----------------------------------------------------------------------------
; alter memory [>]
ALTM:
    bcs ALTMX                   ; exit if no parameter provided
    jsr COPY12                  ; copy parameter to start address
    ldy #0
ALTM1:
    jsr GETPAR                  ; get value for next byte of memory
    bcs ALTMX                   ; if none given, exit early
    lda TMP0                    ; poke value into memory at start address + Y
    sta (TMP2),Y
    iny                         ; next byte
    cpy #8                      ; have we read 8 bytes yet?
    bcc ALTM1                   ; if not, read the next one
ALTMX:
    ;lda #$91                   ; move cursor up
    ;jsr CHROUT
    jsr DISPMEM                 ; re-display line to make ascii match hex
    jmp STRT                    ; back to main loop

; -----------------------------------------------------------------------------
; goto (run) [G]
GOTO:
    ldx SP                      ; load stack pointer from memory
    txs                         ; save in SP register
GOTO2:
    jsr COPY1P                  ; copy provided address to PC
    sei                         ; disable interrupts
    lda PCH                     ; push PC high byte on stack
    pha
    lda PCL                     ; push PC low byte on stack
    pha
    lda SR                      ; push status byte on stack
    pha
    lda ACC                     ; load accumulator from memory
    ldx XR                      ; load X from memory
    ldy YR                      ; load Y from memory
    rti                         ; return from interrupt (pops PC and SR)

; jump to subroutine [J]
JSUB:
    ldx SP                      ; load stack pointer from memory
    txs                         ; save value in SP register
    jsr GOTO2                   ; same as goto command
    sty YR                      ; save Y to memory
    stx XR                      ; save X to memory
    sta ACC                     ; save accumulator to memory
    php                         ; push processor status on stack
    pla                         ; pull processor status into A
    sta SR                      ; save processor status to memory
    jmp DSPLYR                  ; display registers

; -----------------------------------------------------------------------------
; display 8 bytes of memory
DISPMEM:
    jsr CRLF                    ; new line
    lda #'>'                    ; prefix > so memory can be edited in place
    jsr CHROUT
    jsr SHOWAD                  ; show address of first byte on line
    ldy #0
    beq DMEMGO                  ; SHOWAD already printed a space after the address
DMEMLP:
    jsr SPACE                   ; print space between bytes
DMEMGO:
    lda (TMP2),Y                ; load byte from start address + Y
    jsr WRTWO                   ; output hex digits for byte
    iny                         ; next byte
    cpy DISPMEM_BPL             ; have we output 8 bytes yet?
    bcc DMEMLP                  ; if not, output next byte
LDY #MSG5-MSGBAS    ; if so, output : and turn on reverse video
    jsr SNDMSG                  ;   before displaying ascii representation
    ldy #0                      ; back to first byte in line
DCHAR:
    lda (TMP2),Y                ; load byte at start address + Y
    tax                         ; stash in X
    cmp #$7E                    ; is it greater than $7E
    bcs DDOT                    ; if so, print . instead
    txa                         ; if not, restore character
    and #$7F                    ; clear top bit
    cmp #$20                    ; is it a printable character (>= $20)?
    txa                         ; restore character
    bcs DCHROK                  ; if printable, output character
DDOT:
    lda #$2E                    ; if not, output '.' instaed
DCHROK:
    jsr CHROUT
    iny                         ; next byte
    cpy DISPMEM_BPL             ; have we output 8 bytes yet?
    bcc DCHAR                   ; if not, output next byte
    rts

; -----------------------------------------------------------------------------
; compare memory [C]
COMPAR:
    lda #0                      ; bit 7 clear signals compare
        .byte $2C           ; absolute BIT opcode consumes next word (LDA #$80)

; transfer memory [T]
TRANS:
    lda #$80                    ; bit 7 set signals transfer
    sta SAVY                    ; save compare/transfer flag in SAVY
    lda #0                      ; assume we're counting up (bit 7 clear)
    sta UPFLG                   ; save direction flag
    jsr GETDIF                  ; get two addresses and calculate difference
                            ;   TMP2 = source start
                            ;   STASH = source end
                            ;   STORE = length
    bcs TERROR                  ; carry set indicates error
    jsr GETPAR                  ; get destination address in TMP0
    bcc TOKAY                   ; carry set indicates error
TERROR:
    jmp ERROR                   ; handle error
TOKAY:
    bit SAVY                    ; transfer or compare?
    bpl COMPAR1                 ; high bit clear indicates compare
    lda TMP2                    ; if it's a transfer, we must take steps
    cmp TMP0                    ;   to avoid overwriting the source bytes before
    lda TMP2+1                  ;   they have been transferred
    sbc TMP0+1                  ; compare source (TMP2) to destination (TMP0)
    bcs COMPAR1                 ; and count up if source is before than desitnation
    lda STORE                   ; otherwise, start at end and count down...
    adc TMP0                    ; add length (STORE) to desintation (TMP0)
    sta TMP0                    ; to calculate end of destination
    lda STORE+1
    adc TMP0+1
    sta TMP0+1
    ldx #1                      ; change source pointer from beginning to end
TDOWN:
    lda STASH,X                 ; TMP2 = source end (STASH)
    sta TMP2,X
    dex
    bpl TDOWN
    lda #$80                    ; high bit set in UPFLG means count down
    sta UPFLG
COMPAR1:
    jsr CRLF                    ; new line
    ldy #0                      ; no offset from pointer
TCLOOP:
    jsr STOP                    ; check for stop key
    beq TEXIT                   ; exit if pressed
    lda (TMP2),Y                ; load byte from source
    bit SAVY                    ; transfer or compare?
    bpl COMPAR2                 ; skip store if comparing
    sta (TMP0),Y                ; otherwise, store in destination
COMPAR2:
    cmp (TMP0),Y                ; compare to destination
    beq TMVAD                   ; don't show address if equal
    jsr SHOWAD                  ; show address
TMVAD:
    bit UPFLG                   ; counting up or down?
    bmi TDECAD                  ; high bit set means we're counting down
    inc TMP0                    ; increment destination low byte
    bne TINCOK
    inc TMP0+1                  ; carry to high byte if necessary
    bne TINCOK
    jmp ERROR                   ; error if high byte overflowed
TDECAD:
    jsr SUBA1                   ; decrement destination (TMP0)
    jsr SUB21                   ; decrement source (TMP2)
    jmp TMOR
TINCOK:
    jsr ADDA2                   ; increment source (TMP2)
TMOR:
    jsr SUB13                   ; decrement length
    bcs TCLOOP                  ; loop until length is 0
TEXIT:
    jmp STRT                    ; back to main loop

; -----------------------------------------------------------------------------
; hunt memory [H]
HUNT:
    jsr GETDIF                  ; get start (TMP2) and end (TMP0) of haystack
    bcs HERROR                  ; carry indicates error
    ldy #0
    jsr GETCHR                  ; get a single character
    cmp #'''                    ; is it a single quote?
    bne NOSTRH                  ; if not, input needle as hex bytes
    jsr GETCHR                  ; if so, input needle as string
    cmp #0
    beq HERROR                  ; error if needle isn't at least one byte
HPAR:
    sta STAGE,Y                 ; save char in staging area
    iny
    jsr GETCHR                  ; get another char
    beq HTGO                    ; if it's null start searching
    cpy #ESTAGE-STAGE           ; have we filled up the needle staging area?
    bne HPAR                    ; if not, get another character
    beq HTGO                    ; if so, start searching
NOSTRH:
    jsr RDPAR                   ; read hex bytes if string not indicated
HLP:
    lda TMP0                    ; save last read byte in staging area
    sta STAGE,Y
    iny                         ; get another hex byte
    jsr GETPAR
    bcs HTGO                    ; if there is none, start searching
    cpy #ESTAGE-STAGE           ; have we filled up the needle staging area?
    bne HLP                     ; if not, get another byte
HTGO:
    sty SAVY                    ; save length of needle
    jsr CRLF                    ; new line
HSCAN:
    ldy #0
HLP3:
    lda (TMP2),Y                ; get first byte in haystack
    cmp STAGE,Y                 ; compare it to first byte of needle
    bne HNOFT                   ; if it doesn't match, we haven't found anything
    iny                         ; if it does, check the next byte
    cpy SAVY                    ; have we reached the end of the needle?
    bne HLP3                    ; if not, keep comparing bytes
    jsr SHOWAD                  ; match found, show address
HNOFT:
    jsr STOP                    ; no match, check for stop key
    beq HEXIT                   ; exit prematurely if pressed
    jsr ADDA2                   ; increment haystack pointer
    jsr SUB13                   ; decrement haystack length
    bcs HSCAN                   ; still more haystack? keep searching
HEXIT:
    jmp STRT                    ; back to main loop
HERROR:
    jmp ERROR                   ; handle error

; -----------------------------------------------------------------------------
; fill memory [F]
FILL:
    jsr GETDIF                  ; start in TMP2, end in STASH, length in STORE
    bcs AERROR                  ; carry set indicates error
    jsr GETPAR                  ; get value to fill in TMP0
    bcs AERROR                  ; carry set indicates error
    jsr GETCHR                  ; any more characters triggers an error
    bne AERROR
    ldy #0                      ; no offset
FILLP:
    lda TMP0                    ; load value to fill in accumulator
    sta (TMP2),Y                ; store fill value in current address
    jsr STOP                    ; check for stop key
    beq FSTART                  ; if pressed, back to main loop
    jsr ADDA2                   ; increment address
    jsr SUB13                   ; decrement length
    bcs FILLP                   ; keep going until length reaches 0
FSTART:
    jmp STRT                    ; back to main loop

AERROR:
    jmp ERROR                   ; handle error
.IFDEF ENABLE_ASSEMBLER
; -----------------------------------------------------------------------------
; assemble [A.]

; read in mnemonic
ASSEM:
    bcs AERROR                  ; error if no address given
    jsr COPY12                  ; copy address to TMP2
AGET1:
    ldx #0
    stx U0AA0+1                 ; clear byte that mnemonic gets shifted into
    stx DIGCNT                  ; clear digit count
AGET2:
    jsr GETCHR                  ; get a char
    bne ALMOR                   ; proceed if the character isn't null
    cpx #0                      ; it's null, have read a mnemonic yet?
    beq FSTART                  ; if not, silently go back to main loop
ALMOR:
    cmp #$20                    ; skip leading spaces
    beq AGET1
    sta MNEMW,X                 ; put character in mnemonic buffer
    inx
    cpx #3                      ; have we read 3 characters yet?
    bne AGET2                   ; if not, get next character

; compress mnemonic into two bytes
ASQEEZ:
    dex                         ; move to previous char
    bmi AOPRND                  ; if we're done with mnemonic, look for operand
    lda MNEMW,X                 ; get current character
    sec                         ; pack 3-letter mnemonic into 2 bytes (15 bits)
    sbc #$3F                    ; subtract $3F from ascii code so A-Z = 2 to 27
    ldy #$05                    ; letters now fit in 5 bits; shift them out
ASHIFT:
    lsr A                       ;   into the first two bytes of the inst buffer
    ror U0AA0+1                 ; catch the low bit from accumulator in right byte
    ror U0AA0                   ; catch the low bit from right byte in left byte
    dey                         ; count down bits
    bne ASHIFT                  ; keep looping until we reach zero
    beq ASQEEZ                  ; unconditional branch to handle next char
;AERROR:
    ;jmp ERROR                   ; handle error

; parse operand
AOPRND:
    ldx #2                      ; mnemonic is in first two bytes so start at third
ASCAN:
    lda DIGCNT                  ; did we find address digits last time?
    bne AFORM1                  ; if so, look for mode chars
    jsr RDVAL                   ; otherwise, look for an address
    beq AFORM0                  ; we didn't find an address, look for characters
    bcs AERROR                  ; carry flag indicates error
    lda #'$'
    sta U0AA0,X                 ; prefix addresses with $
    inx                         ; next position in buffer
    ldy #4                      ; non-zero page addresses are 4 hex digits
    lda NUMBIT                  ; check numeric base in which address was given
    cmp #8                      ; for addresses given in octal or binary
    bcc AADDR                   ;   use only the high byte to determine page
    cpy DIGCNT                  ; for decimal or hex, force non-zero page addressing
    beq AFILL0                  ;   if address was given with four digits or more
AADDR:
    lda TMP0+1                  ; check whether high byte of address is zero
    bne AFILL0                  ; non-zero high byte means we're not in zero page
    ldy #2                      ; if it's in zero page, addr is 2 hex digits
AFILL0:
    lda #$30                    ; use 0 as placeholder for each hex digit in addr
AFIL0L:
    sta U0AA0,X                 ; put placeholder in assembly buffer
    inx                         ; move to next byte in buffer
    dey                         ; decrement number of remaining digits
    bne AFIL0L                  ; loop until all digits have been placed
AFORM0:
    dec CHRPNT                  ; non-numeric input; back 1 char to see what it was
AFORM1:
    jsr GETCHR                  ; get next character
    beq AESCAN                  ; if there is none, we're finished scanning
    cmp #$20                    ; skip spaces
    beq ASCAN
    sta U0AA0,X                 ; store character in assembly buffer
    inx                         ; move to next byte in buffer
    cpx #U0AAE-U0AA0            ; is instruction buffer full?
    bcc ASCAN                   ; if not, keep scanning
    bcs AERROR                  ; error if buffer is full

; find matching opcode
AESCAN:
    stx STORE                   ; save number of bytes in assembly buffer
    ldx #0                      ; start at opcode $00 and check every one until
    stx OPCODE                  ;   we find one that matches our criteria
ATRYOP:
    ldx #0
    stx U9F                     ; reset index into work buffer
    lda OPCODE
    jsr INSTXX                  ; look up instruction format for current opcode
    ldx ACMD                    ; save addressing command for later
    stx STORE+1
    tax                         ; use current opcode as index
    lda IDX_NAME, x
    tax
    lda MNEMR,X                 ; check right byte of compressed mnemonic
    jsr CHEKOP
    lda MNEML,X                 ; check left byte of compressed mnemonic
    jsr CHEKOP
    ldx #6                      ; 6 possible characters to check against operand
TRYIT:
    cpx #3                      ; are we on character 3?
    bne TRYMOD                  ; if not, check operand characters
    ldy LENGTH                  ; otherwise, check number of bytes in operand
    beq TRYMOD                  ; if zero, check operand characters
TRYAD:
    lda ACMD                    ; otherwise, look for an address
    cmp #$E8                    ; special case for relative addressing mode
                            ;   since it's specified with 4 digits in assembly
                            ;   but encoded with only 1 byte in object code
    lda #$30                    ; '0' is the digit placeholder we're looking for
    bcs TRY4B                   ; ACMD >= $E8 indicates relative addressing
    jsr CHEK2B                  ; ACMD < $E8 indicates normal addressing
    dey                         ; consume byte
    bne TRYAD                   ; check for 2 more digits if not zero-page
TRYMOD:
    asl ACMD                    ; shift a bit out of the addressing command
    bcc UB4DF                   ; if it's zero, skip checking current character
    lda CHAR1-1,X
    jsr CHEKOP                  ; otherwise first character against operand
    lda CHAR2-1,X               ; get second character to check
    beq UB4DF                   ; if it's zero, skip checking it
    jsr CHEKOP                  ; otherwise check it against hte operand
UB4DF:
    dex                         ; move to next character
    bne TRYIT                   ; repeat tests
    beq TRYBRAN
TRY4B:
    jsr CHEK2B                  ; check for 4 digit address placeholder
    jsr CHEK2B                  ;   by checking for 2 digits twice
TRYBRAN:
    lda STORE                   ; get number of bytes in assembly buffer
    cmp U9F                     ; more bytes left to check?
    beq ABRAN                   ; if not, we've found a match; build instruction
    jmp BUMPOP                  ; if so, this opcode doesn't match; try the next

; convert branches to relative address
ABRAN:
    ldy LENGTH                  ; get number of bytes in operand
    beq A1BYTE                  ; if none, just output the opcode
    lda STORE+1                 ; otherwise check the address format
    cmp #$9D                    ; is it a relative branch?
    bne OBJPUT                  ; if not, skip relative branch calculation
    lda TMP0                    ; calculate the difference between the current
    sbc TMP2                    ;   address and the branch target (low byte)
    tax                         ; save it in X
    lda TMP0+1                  ; borrow from the high byte if necessary
    sbc TMP2+1
    bcc ABBACK                  ; if result is negative, we're branching back
    bne SERROR                  ; high bytes must be equal when branching forward
    cpx #$82                    ; difference between low bytes must be < 130
    bcs SERROR                  ; error if the address is too far away
    bcc ABRANX
ABBACK:
    tay                         ; when branching backward high byte of target must
    iny                         ;   be 1 less than high byte of current address
    bne SERROR                  ; if not, it's too far away
    cpx #$82                    ; difference between low bytes must be < 130
    bcc SERROR                  ; if not, it's too far away
ABRANX:
    dex                         ; adjust branch target relative to the
    dex                         ;   instruction following this one
    txa
    ldy LENGTH                  ; load length of operand
    bne OBJP2                   ; don't use the absolute address

; assemble machine code
OBJPUT:
    lda TMP0-1,Y                ; get the operand
OBJP2:
    sta (TMP2),Y                ; store it after the opcode
    dey
    bne OBJPUT                  ; copy the other byte of operand if there is one
A1BYTE:
    lda OPCODE                  ; put opcode into instruction
    sta (TMP2),Y
    jsr CRLF                    ; carriage return
;        LDA #$0A            ; back up one line   ** removed; no screen
;        JSR CHROUT			  	  ** editor with TTY
;        LDY #MSG7-MSGBAS    ; "A " prefix
;        JSR SNDCLR          ; clear line
    jsr DISLIN                  ; disassemble the instruction we just assembled
    inc LENGTH                  ; instruction length = operand length + 1 byte
    lda LENGTH                  ;   for the opcode
    jsr BUMPAD2                 ; increment address by length of instruction
; -----------------------------------------------------------------------------
; AUTO ADVANCE ADDRESS FOR TTY OPERATION (DHH)
    jsr CRLF                    ; carriage return
    ldx #0                      ; point at start of input buffer
    stx CHRPNT
    lda #$41                    ; 'A'
    sta INBUFF,X                ; PRE-LOAD INPUT BUFFER WITH COMMAND
    inx
    lda #$20                    ; space
    sta INBUFF,X
    inx
    stx SAVX
    lda TMP2+1                  ; GET MSB OF ADDR
    jsr DOADDR                  ; PUT IN BUFFER
    lda TMP2                    ; NOW DO LSB
    jsr DOADDR
    lda #$20                    ; space
    sta INBUFF,X
    inx
    stx SAVX

    ldx #$00                    ; PRINT OUT BUFFER ('A ADDR ')
ADLOOP:
    lda INBUFF,X
    jsr CHROUT
    inx
    cpx SAVX
    bne ADLOOP
    jmp SMOVE                   ; TO INPUT, WITH BUFFER & INDEX SET (was JMP STRT)
SERROR:
    jmp ERROR                   ; handle error


DOADDR:
    jsr ASCTWO                  ; CONVERT BYTE IN AC INTO HEX DIGITS
    stx STASH                   ; RETURNS W/ AC=HI NYB, XR=LO NYB
    ldx SAVX                    ; GET INDEX BACK
    sta INBUFF,X
    inx
    lda STASH                   ; GET THE LOW NYBBLE
    sta INBUFF,X
    inx
    stx SAVX
    rts

; check characters in operand
CHEK2B:
    jsr CHEKOP                  ; check two bytes against value in accumulator
CHEKOP:
    stx SAVX                    ; stash X
    ldx U9F                     ; get current index into work buffer
    cmp U0AA0,X                 ; check whether this opcode matches the buffer
    beq OPOK                    ;   matching so far, check the next criteria
    pla                         ; didn't match, so throw away return address
    pla                         ;   on the stack because we're starting over
BUMPOP:
    inc OPCODE                  ; check the next opcode
    beq SERROR                  ; error if we tried every opcode and none fit
    jmp ATRYOP                  ; start over with new opcode
OPOK:
    inc U9F                     ; opcode matches so far; check the next criteria
    ldx SAVX                    ; restore X
    rts
.ENDIF ; ENABLE_ASSEMBLER
; -----------------------------------------------------------------------------
; disassemble [D]
DISASS:
    bcs DIS0AD                  ; if no address was given, start from last address
    jsr COPY12                  ; copy start address to TMP2
    jsr GETPAR                  ; get end address in TMP0
    bcc DIS2AD                  ; if one was given, skip default
DIS0AD:
    lda #$14                    ; disassemble 14 bytes by default
    sta TMP0                    ; store length in TMP0
    bne DISGO                   ; skip length calculation
DIS2AD:
    jsr SUB12                   ; calculate number of bytes between start and end
    bcc DERROR                  ; error if end address is before start address
DISGO:
    jsr CLINE                   ; clear the current line
    jsr STOP                    ; check for stop key
    beq DISEXIT                 ; exit early if pressed
    jsr DSOUT1                  ; output disassembly prefix ". "
    inc LENGTH
    lda LENGTH                  ; add length of last instruction to start address
    jsr BUMPAD2
    lda LENGTH                  ; subtract length of last inst from end address
    jsr SUBA2
    bcs DISGO
DISEXIT:
    jmp STRT                    ; back to mainloop
DERROR:
    jmp ERROR

DSOUT1:
    lda #'.'                    ; output ". " prefix to allow edit and reassemble
    jsr CHROUT
    jsr SPACE

DISLIN:
    jsr SHOWAD                  ; show the address of the instruction
    jsr SPACE                   ; insert a space
    ldy #0                      ; no offset
    lda (TMP2),Y                ; load operand of current instruction
    jsr INSTXX                  ; get mnemonic and addressing mode for opcode
    pha                         ; save index into mnemonic table
    ldx LENGTH                  ; get length of operand
    inx                         ; add 1 byte for opcode
DSBYT:
    dex                         ; decrement index
    bpl DSHEX                   ; show hex for byte being disassembled
    sty SAVY                    ; save index
    ldy #MSG8-MSGBAS            ; skip 3 spaces
    jsr SNDMSG
    ldy SAVY                    ; restore index
    jmp NXBYT
DSHEX:
    lda (TMP2),Y                ; show hex for byte
    jsr WRBYTE

NXBYT:
    iny                         ; next byte
    cpy #3                      ; have we output 3 bytes yet?
    bcc DSBYT                   ; if not, loop
    pla                         ; restore index into mnemonic table
    ldx #3                      ; 3 letters in mnemonic
    jsr PROPXX                  ; print mnemonic
    ldx #6                      ; 6 possible address mode character combos
PRADR1:
    cpx #3                      ; have we checked the third combo yet?
    bne PRADR3                  ; if so, output the leading characters
    ldy LENGTH                  ; get the length of the operand
    beq PRADR3                  ; if it's zero, there's no operand to print
PRADR2:
    lda ACMD                    ; otherwise, get the addressing mode
    cmp #$E8                    ; check for relative addressing
    php                         ; save result of check
    lda (TMP2),Y                ; get the operand
    plp                         ; restore result of check
    bcs RELAD                   ; handle a relative address
    jsr WRTWO                   ; output digits from address
    dey
    bne PRADR2                  ; repeat for next byte of operand, if there is one
PRADR3:
    asl ACMD                    ; check whether addr mode uses the current char
    bcc PRADR4                  ; if not, skip it
    lda CHAR1-1,X               ; look up the first char in the table
    jsr CHROUT                  ; print first char
    lda CHAR2-1,X               ; look up the second char in the table
    beq PRADR4                  ; if there's no second character, skip it
    jsr CHROUT                  ; print second char
PRADR4:
    dex                         ; next potential address mode character
    bne PRADR1                  ; loop if we haven't checked them all yet
    rts                         ; back to caller
RELAD:
    jsr UB64D                   ; calculate absolute address from relative
    clc
    adc #1                      ; adjust address relative to next instruction
    bne RELEND                  ; don't increment high byte unless we overflowed
    inx                         ; increment high byte
RELEND:
    jmp WRADDR                  ; print address

UB64D:
    ldx TMP2+1                  ; get high byte of current address
    tay                         ; is relative address positive or negative?
    bpl RELC2                   ; if positive, leave high byte alone
    dex                         ; if negative, decrement high byte
RELC2:
    adc TMP2                    ; add relative address to low byte
    bcc RELC3                   ; if there's no carry, we're done
    inx                         ; if there's a carry, increment the high byte
RELC3:
    rts

; -----------------------------------------------------------------------------
; get opcode mode and length

; Note: the labels are different, but the code of this subroutine is almost
; identical to the INSDS2 subroutine of the Apple Mini-Assembler on page 78 of
; the Apple II Red Book. I'm not sure exactly where this code originated
; (MOS or Apple) but it's clear that this part of Supermon64 and the
; Mini-Asssembler share a common heritage.  The comments showing the way the
; opcodes are transformed into indexes for the mnemonic lookup table come
; from the Mini-Assembler source.

INSTXX:
    tay                         ; stash opcode in accumulator in Y for later
    tax                         ; and use it as index
    lda IDX_MODE2, X
GETFMT:
    tax
    lda MODE2, X                ; lookup operand format using selected nybble
    sta ACMD                    ; save for later use
    and #$03                    ; lower 2 bits indicate number of bytes in operand
    sta LENGTH
    lda IDX_NAME, y
    ldy #0
    rts

; -----------------------------------------------------------------------------
; extract and print packed mnemonics
PROPXX:
    tay
    lda MNEML,Y                 ;   and place a temporary copy in STORE
    sta STORE
    lda MNEMR,Y
    sta STORE+1
PRMN1:
    lda #0                      ; clear accumulator
    ldy #$05                    ; shift 5 times
PRMN2:
    asl STORE+1                 ; shift right byte
    rol STORE                   ; rotate bits from right byte into left byte
    rol A                       ; rotate bits from left byte into accumulator
    dey                         ; next bit
    bne PRMN2                   ; loop until all bits shifted
    adc #$3F                    ; calculate ascii code for letter by adding to '?'
    jsr CHROUT                  ; output letter
    dex                         ; next letter
    bne PRMN1                   ; loop until all 3 letters are output
    jmp SPACE                   ; output space

; -----------------------------------------------------------------------------
; read parameters
RDPAR:
    dec CHRPNT                  ; back up one char
GETPAR:
    jsr RDVAL                   ; read the value
    bcs GTERR                   ; carry set indicates error
    jsr GOTCHR                  ; check previous character
    bne CKTERM                  ; if it's not null, check if it's a valid separator
    dec CHRPNT                  ; back up one char
    lda DIGCNT                  ; get number of digits read
    bne GETGOT                  ; found some digits
    beq GTNIL                   ; didn't find any digits
CKTERM:
    cmp #$20                    ; space or comma are valid separators
    beq GETGOT                  ; anything else is an error
    cmp #','
    beq GETGOT
GTERR:
    pla                         ; encountered error
    pla                         ; get rid of command vector pushed on stack
    jmp ERROR                   ; handle error
GTNIL:
    sec                         ; set carry to indicate no parameter found
        .byte $24           ; BIT ZP opcode consumes next byte (CLC)
GETGOT:
    clc                         ; clear carry to indicate paremeter returned
    lda DIGCNT                  ; return number of digits in A
    rts                         ; return to address pushed from vector table

; -----------------------------------------------------------------------------
; read a value in the specified base
RDVAL:
    lda #0                      ; clear temp
    sta TMP0
    sta TMP0+1
    sta DIGCNT                  ; clear digit counter
    txa                         ; save X and Y
    pha
    tya
    pha
RDVMOR:
    jsr GETCHR                  ; get next character from input buffer
    beq RDNILK                  ; null at end of buffer
    cmp #$20                    ; skip spaces
    beq RDVMOR
    ldx #3                      ; check numeric base [$+&%]
GNMODE:
    cmp HIKEY,X
    beq GOTMOD                  ; got a match, set up base
    dex
    bpl GNMODE                  ; check next base
    inx                         ; default to hex
    dec CHRPNT                  ; back up one character
GOTMOD:
    ldy MODTAB,X                ; get base value
    lda LENTAB,X                ; get bits per digit
    sta NUMBIT                  ; store bits per digit
NUDIG:
    jsr GETCHR                  ; get next char in A
RDNILK:
    beq RDNIL                   ; end of number if no more characters
    sec
    sbc #$30                    ; subtract ascii value of 0 to get numeric value
    bcc RDNIL                   ; end of number if character was less than 0
    cmp #$0A
    bcc DIGMOR                  ; not a hex digit if less than A
    sbc #$07                    ; 7 chars between ascii 9 and A, so subtract 7
    cmp #$10                    ; end of number if char is greater than F
    bcs RDNIL
DIGMOR:
    sta INDIG                   ; store the digit
    cpy INDIG                   ; compare base with the digit
    bcc RDERR                   ; error if the digit >= the base
    beq RDERR
    inc DIGCNT                  ; increment the number of digits
    cpy #10
    bne NODECM                  ; skip the next part if not using base 10
    ldx #1
DECLP1:
    lda TMP0,X                  ; stash the previous 16-bit value for later use
    sta STASH,X
    dex
    bpl DECLP1
NODECM:
    ldx NUMBIT                  ; number of bits to shift
TIMES2:
    asl TMP0                    ; shift 16-bit value by specified number of bits
    rol TMP0+1
    bcs RDERR                   ; error if we overflowed 16 bits
    dex
    bne TIMES2                  ; shift remaining bits
    cpy #10
    bne NODEC2                  ; skip the next part if not using base 10
    asl STASH                   ; shift the previous 16-bit value one bit left
    rol STASH+1
    bcs RDERR                   ; error if we overflowed 16 bits
    lda STASH                   ; add shifted previous value to current value
    adc TMP0
    sta TMP0
    lda STASH+1
    adc TMP0+1
    sta TMP0+1
    bcs RDERR                   ; error if we overflowed 16 bits
NODEC2:
    clc
    lda INDIG                   ; load current digit
    adc TMP0                    ; add current digit to low byte
    sta TMP0                    ; and store result back in low byte
    txa                         ; A=0
    adc TMP0+1                  ; add carry to high byte
    sta TMP0+1                  ; and store result back in high byte
    bcc NUDIG                   ; get next digit if we didn't overflow
RDERR:
    sec                         ; set carry to indicate error
        .byte $24           ; BIT ZP opcode consumes next byte (CLC)
RDNIL:
    clc                         ; clear carry to indicate success
    sty NUMBIT                  ; save base of number
    pla                         ; restore X and Y
    tay
    pla
    tax
    lda DIGCNT                  ; return number of digits in A
    rts

; -----------------------------------------------------------------------------
; print address
SHOWAD:
    lda TMP2
    ldx TMP2+1

WRADDR:
    pha                         ; save low byte
    txa                         ; put high byte in A
    jsr WRTWO                   ; output high byte
    pla                         ; restore low byte

WRBYTE:
    jsr WRTWO                   ; output byte in A

SPACE:
    lda #$20                    ; output space
    bne FLIP

CHOUT:
    cmp #$0D                    ; output char with special handling of CR
    bne FLIP
CRLF:
    lda #$0D                    ; load CR in A
    jsr CHROUT                  ; otherwise output CR+LF
    lda #$0A                    ; output LF
FLIP:
    jmp CHROUT

FRESH:
    jsr CRLF                    ; output CR
    lda #$20                    ; load space in A
    jsr CHROUT
    jmp SNCLR

; -----------------------------------------------------------------------------
; output two hex digits for byte
WRTWO:
    stx SAVX                    ; save X
    jsr ASCTWO                  ; get hex chars for byte in X (lower) and A (upper)
    jsr CHROUT                  ; output upper nybble
    txa                         ; transfer lower to A
    ldx SAVX                    ; restore X
    jmp CHROUT                  ; output lower nybble

; -----------------------------------------------------------------------------
; convert byte in A to hex digits
ASCTWO:
    pha                         ; save byte
    jsr ASCII                   ; do low nybble
    tax                         ; save in X
    pla                         ; restore byte
    lsr A                       ; shift upper nybble down
    lsr A
    lsr A
    lsr A

; convert low nybble in A to hex digit
ASCII:
    and #$0F                    ; clear upper nibble
    cmp #$0A                    ; if less than A, skip next step
    bcc ASC1
    adc #6                      ; skip ascii chars between 9 and A
ASC1:
    adc #$30                    ; add ascii char 0 to value
    rts

; -----------------------------------------------------------------------------
; get prev char from input buffer
GOTCHR:
    dec CHRPNT

; get next char from input buffer
GETCHR:
    stx SAVX
    ldx CHRPNT                  ; get pointer to next char
    lda INBUFF,X                ; load next char in A
    beq NOCHAR                  ; null, :, or ? signal end of buffer
    cmp #':'
    beq NOCHAR
    cmp #'?'
NOCHAR:
    php
    inc CHRPNT                  ; next char
    ldx SAVX
    plp                         ; Z flag will signal last character
    rts

; -----------------------------------------------------------------------------
; copy TMP0 to TMP2
COPY12:
    lda TMP0                    ; low byte
    sta TMP2
    lda TMP0+1                  ; high byte
    sta TMP2+1
    rts

; -----------------------------------------------------------------------------
; subtract TMP2 from TMP0
SUB12:
    sec
    lda TMP0                    ; subtract low byte
    sbc TMP2
    sta TMP0
    lda TMP0+1
    sbc TMP2+1                  ; subtract high byte
    sta TMP0+1
    rts

; -----------------------------------------------------------------------------
; subtract from TMP0
SUBA1:
    lda #1                      ; shortcut to decrement by 1
SUBA2:
    sta SAVX                    ; subtrahend in accumulator
    sec
    lda TMP0                    ; minuend in low byte
    sbc SAVX
    sta TMP0
    lda TMP0+1                  ; borrow from high byte
    sbc #0
    sta TMP0+1
    rts

; -----------------------------------------------------------------------------
; subtract 1 from STORE
SUB13:
    sec
    lda STORE
    sbc #1                      ; decrement low byte
    sta STORE
    lda STORE+1
    sbc #0                      ; borrow from high byte
    sta STORE+1
    rts

; -----------------------------------------------------------------------------
; add to TMP2
ADDA2:
    lda #1                      ; shortcut to increment by 1
BUMPAD2:
    clc
    adc TMP2                    ; add value in accumulator to low byte
    sta TMP2
    bcc BUMPEX
    inc TMP2+1                  ; carry to high byte
BUMPEX:
    rts

; -----------------------------------------------------------------------------
; subtract 1 from TMP2
SUB21:
    sec
    lda TMP2                    ; decrement low byte
    sbc #1
    sta TMP2
    lda TMP2+1                  ; borrow from high byte
    sbc #0
    sta TMP2+1
    rts

; -----------------------------------------------------------------------------
; copy TMP0 to PC
COPY1P:
    bcs CPY1PX                  ; do nothing if parameter is empty
    lda TMP0                    ; copy low byte
    ldy TMP0+1                  ; copy high byte
    sta PCL
    sty PCH
CPY1PX:
    rts

; -----------------------------------------------------------------------------
; get start/end addresses and calc difference
GETDIF:
    bcs GDIFX                   ; exit with error if no parameter given
    jsr COPY12                  ; save start address in TMP2
    jsr GETPAR                  ; get end address in TMP0
    bcs GDIFX                   ; exit with error if no parameter given
    lda TMP0                    ; save end address in STASH
    sta STASH
    lda TMP0+1
    sta STASH+1
    jsr SUB12                   ; subtract start address from end address
    lda TMP0
    sta STORE                   ; save difference in STORE
    lda TMP0+1
    sta STORE+1
    bcc GDIFX                   ; error if start address is after end address
    clc                         ; clear carry to indicate success
        .byte $24           ; BIT ZP opcode consumes next byte (SEC)
GDIFX:
    sec                         ; set carry to indicate error
    rts

; -----------------------------------------------------------------------------
; convert base [$+&%]
CONVRT:
    jsr RDPAR                   ; read a parameter
    jsr FRESH                   ; next line and clear
    lda #'$'                    ; output $ sigil for hex
    jsr CHROUT
    lda TMP0                    ; load the 16-bit value entered
    ldx TMP0+1
    jsr WRADDR                  ; print it in 4 hex digits
    jsr FRESH
    lda #'+'                    ; output + sigil for decimal
    jsr CHROUT
    jsr CVTDEC                  ; convert to BCD using hardware mode
    lda #0                      ; clear digit counter
    ldx #6                      ; max digits + 1
    ldy #3                      ; bits per digit - 1
    jsr NMPRNT                  ; print result without leading zeros
    jsr FRESH                   ; next line and clear
    lda #'&'                    ; print & sigil for octal
    jsr CHROUT
    lda #0                      ; clear digit counter
    ldx #8                      ; max digits + 1
    ldy #2                      ; bits per digit - 1
    jsr PRINUM                  ; output number
    jsr FRESH                   ; next line and clear
    lda #'%'                    ; print % sigil for binary
    jsr CHROUT
    lda #0                      ; clear digit counter
    ldx #$18                    ; max digits + 1
    ldy #0                      ; bits per digit - 1
    jsr PRINUM                  ; output number
    jmp STRT                    ; back to mainloop

; -----------------------------------------------------------------------------
; convert binary to BCD

CVTDEC:
    jsr COPY12                  ; copy value from TMP0 to TMP2
    lda #0
    ldx #2                      ; clear 3 bytes in work buffer
DECML1:
    sta U0AA0,X
    dex
    bpl DECML1
    ldy #16                     ; 16 bits in input
    php                         ; save status register
    sei                         ; make sure no interrupts occur with BCD enabled
    sed
DECML2:
    asl TMP2                    ; rotate bytes out of input low byte
    rol TMP2+1                  ; .. into high byte and carry bit
    ldx #2                      ; process 3 bytes
DECDBL:
    lda U0AA0,X                 ; load current value of byte
    adc U0AA0,X                 ; add it to itself plus the carry bit
    sta U0AA0,X                 ; store it back in the same location
    dex                         ; decrement byte counter
    bpl DECDBL                  ; loop until all bytes processed
    dey                         ; decrement bit counter
    bne DECML2                  ; loop until all bits processed
    plp                         ; restore processor status
    rts

; load the input value and fall through to print it
PRINUM:
    pha                         ; save accumulator
    lda TMP0                    ; copy input low byte to work buffer
    sta U0AA0+2
    lda TMP0+1                  ; copy input high byte to work buffer
    sta U0AA0+1
    lda #0                      ; clear overflow byte in work buffer
    sta U0AA0
    pla                         ; restore accumulator

; print number in specified base without leading zeros
NMPRNT:
    sta DIGCNT                  ; number of digits in accumulator
    sty NUMBIT                  ; bits per digit passed in Y register
DIGOUT:
    ldy NUMBIT                  ; get bits to process
    lda #0                      ; clear accumulator
ROLBIT:
    asl U0AA0+2                 ; shift bits out of low byte
    rol U0AA0+1                 ; ... into high byte
    rol U0AA0                   ; ... into overflow byte
    rol A                       ; ... into accumulator
    dey                         ; decrement bit counter
    bpl ROLBIT                  ; loop until all bits processed
    tay                         ; check whether accumulator is 0
    bne NZERO                   ; if not, print it
    cpx #1                      ; have we output the max number of digits?
    beq NZERO                   ; if not, print it
    ldy DIGCNT                  ; how many digits have we output?
    beq ZERSUP                  ; skip output if digit is 0
NZERO:
    inc DIGCNT                  ; increment digit counter
    ora #$30                    ; add numeric value to ascii '0' to get ascii char
    jsr CHROUT                  ; output character
ZERSUP:
    dex                         ; decrement number of leading zeros
    bne DIGOUT                  ; next digit
    rts

; -----------------------------------------------------------------------------
; print and clear routines
CLINE:
    jsr CRLF                    ; send CR+LF
    jmp SNCLR                   ; clear line
SNDCLR:
    jsr SNDMSG
SNCLR:
    rts                 ; KIM CHANGE: no screen editor, don't worry about clearing to eol

; -----------------------------------------------------------------------------
; display message from table
SNDMSG:
    lda MSGBAS,Y                ; Y contains offset in msg table
    php
    and #$7F                    ; strip high bit before output
    jsr CHOUT
    iny
    plp
    bpl SNDMSG                  ; loop until high bit is set
    rts

STOP:
    lda #$FF
    rts

; -----------------------------------------------------------------------------
CHROUT:
    jmp (OUTCH)

; -----------------------------------------------------------------------------
INPUT:
    jmp (GETCH)

; -----------------------------------------------------------------------------
; message table; last character has high bit set
MSGBAS =*
MSG2:   .byte $0D               ; header for registers
        .byte "   PC  SR AC XR YR SP   V1.2"
        .byte $0D+$80
MSG3:   .byte '?',$0D+$80       ; syntax error: ? on its own line
MSG4:   .byte $0D, $0D, "SUPERMON+ " ; SUPERMON KIM banner
        .byte "@ ", '$'+$80
MSG5:   .byte $3A+$80           ; KIM CHANGE: just a ':'
MSG6:   .byte " ERRO"           ; I/O error: display " ERROR"
        .byte 'R'+$80
MSG7:   .byte $41,$20+$80       ; assemble next instruction: "A " + addr
MSG8:   .byte "  "              ; pad non-existent byte: skip 3 spaces
        .byte $20+$80


.segment "RODATA"
; -----------------------------------------------------------------------------

; addressing mode format definitions indexed by opcode from IDX_MODE2 table

; left 6 bits define which characters appear in the assembly operand
; left 3 bits are before the address; next 3 bits are after

; right-most 2 bits define length of binary operand

; index               654 321
; 1st character       $(# ,),
; 2nd character        $$ X Y    length  format      idx mode
MODE2:  .byte $00   ; 000 000    00                  0   error
        .byte $21   ; 001 000    01      #$00        1   immediate
        .byte $81   ; 100 000    01      $00         2   zero-page
        .byte $82   ; 100 000    10      $0000       3   absolute
        .byte $00   ; 000 000    00                  4   implied
        .byte $00   ; 000 000    00                  5   accumulator
        .byte $59   ; 010 110    01      ($00,X)     6   indirect,X
        .byte $4D   ; 010 011    01      ($00),Y     7   indirect,Y
        .byte $91   ; 100 100    01      $00,X       8   zero-page,X
        .byte $92   ; 100 100    10      $0000,X     9   absolute,X
        .byte $86   ; 100 001    10      $0000,Y     A   absolute,Y
        .byte $4A   ; 010 010    10      ($0000)     B   indirect
        .byte $85   ; 100 001    01      $00,Y       C   zero-page,Y
        .byte $9D   ; 100 111    01      $0000*      D   relative

; * relative is special-cased so format bits don't match


; character lookup tables for the format definitions in MODE2

CHAR1:  .byte $2C,$29,$2C       ; ','  ')'  ','
        .byte $23,$28,$24       ; '#'  '('  '$'

CHAR2:  .byte $59,$00,$58       ; 'Y'   0   'X'
        .byte $24,$24,$00       ; '$'  '$'   0

; -----------------------------------------------------------------------------
; 3-letter mnemonics packed into two bytes (5 bits per letter)
MNEML:
    .byte $1c,$84,$00,$ad,$15,$13,$8a,$39    ; BRK ORA ??? TSB ASL RBa PHP BRa
    .byte $1c,$ac,$13,$23,$53,$39,$5d,$13    ; BPL TRB RBb CLC INC BRb JSR AND
    .byte $1a,$9c,$13,$8b,$39,$1b,$13,$a1    ; BIT ROL RBc PLP BRc BMI RBd SEC
    .byte $29,$39,$9d,$34,$6d,$13,$8a,$5b    ; DEC BRd RTI EOR LSR RBe PHA JMP
    .byte $39,$1d,$13,$23,$8a,$39,$9d,$11    ; BRe BVC RBf CLI PHY BRf RTS ADC
    .byte $a5,$9c,$13,$8b,$39,$1d,$13,$a1    ; STZ ROR RBg PLA BRg BVS RBh SEI
    .byte $8b,$39,$1c,$a5,$a5,$a5,$14,$29    ; PLY BRh BRA STA STY STX SBa DEY
    .byte $ae,$3a,$19,$14,$ae,$ae,$3a,$69    ; TXA BSa BCC SBb TYA TXS BSb LDY
    .byte $69,$69,$14,$a8,$a8,$3a,$19,$14    ; LDA LDX SBc TAY TAX BSc BCS SBd
    .byte $23,$ad,$3a,$24,$23,$14,$53,$29    ; CLV TSX BSd CPY CMP SBe INY DEX
    .byte $c0,$3a,$1b,$14,$23,$8a,$a5,$3a    ; WAI BSe BNE SBf CLD PHX STP BSf
    .byte $24,$a0,$14,$53,$7c,$3a,$19,$14    ; CPX SBC SBg INX NOP BSg BEQ SBh
    .byte $a1,$8b,$3a                        ; SED PLX BSh

;
MNEMR:
    .byte $d8,$c4,$00,$06,$1a,$1c,$62,$c4    ; BRK ORA ??? TSB ASL RBa PHP BRa
    .byte $5a,$c6,$1c,$48,$c8,$c6,$26,$ca    ; BPL TRB RBb CLC INC BRb JSR AND
    .byte $aa,$1a,$1c,$62,$c8,$94,$1c,$88    ; BIT ROL RBc PLP BRc BMI RBd SEC
    .byte $88,$ca,$54,$26,$26,$1c,$44,$a2    ; DEC BRd RTI EOR LSR RBe PHA JMP
    .byte $cc,$c8,$1c,$54,$74,$ce,$68,$48    ; BRe BVC RBf CLI PHY BRf RTS ADC
    .byte $76,$26,$1d,$44,$d0,$e8,$1d,$94    ; STZ ROR RBg PLA BRg BVS RBh SEI
    .byte $74,$d2,$c4,$44,$74,$72,$1c,$b4    ; PLY BRh BRA STA STY STX SBa DEY
    .byte $44,$44,$08,$1c,$84,$68,$46,$74    ; TXA BSa BCC SBb TYA TXS BSb LDY
    .byte $44,$72,$1c,$b4,$b2,$48,$28,$1c    ; LDA LDX SBc TAY TAX BSc BCS SBd
    .byte $6e,$32,$4a,$74,$a2,$1c,$f4,$b2    ; CLV TSX BSd CPY CMP SBe INY DEX
    .byte $94,$4c,$cc,$1c,$4a,$72,$62,$4e    ; WAI BSe BNE SBf CLD PHX STP BSf
    .byte $72,$c8,$1d,$f2,$22,$50,$a4,$1d    ; CPX SBC SBg INX NOP BSg BEQ SBh
    .byte $8a,$72,$52                        ; SED PLX BSh

;
; for each opcode, index to the MNEML and MNEMR tables
IDX_NAME:
    .byte $00,$01,$02,$02,$03,$01,$04,$05,$06,$01,$04,$02,$03,$01,$04,$07
    .byte $08,$01,$01,$02,$09,$01,$04,$0a,$0b,$01,$0c,$02,$09,$01,$04,$0d
    .byte $0e,$0f,$02,$02,$10,$0f,$11,$12,$13,$0f,$11,$02,$10,$0f,$11,$14
    .byte $15,$0f,$0f,$02,$10,$0f,$11,$16,$17,$0f,$18,$02,$02,$0f,$11,$19
    .byte $1a,$1b,$02,$02,$02,$1b,$1c,$1d,$1e,$1b,$1c,$02,$1f,$1b,$1c,$20
    .byte $21,$1b,$1b,$02,$02,$1b,$1c,$22,$23,$1b,$24,$02,$02,$1b,$1c,$25
    .byte $26,$27,$02,$02,$28,$27,$29,$2a,$2b,$27,$29,$02,$1f,$27,$29,$2c
    .byte $2d,$27,$27,$02,$28,$27,$29,$2e,$2f,$27,$30,$02,$1f,$27,$29,$31
    .byte $32,$33,$02,$02,$34,$33,$35,$36,$37,$02,$38,$02,$34,$33,$35,$39
    .byte $3a,$33,$33,$02,$34,$33,$35,$3b,$3c,$33,$3d,$02,$28,$33,$28,$3e
    .byte $3f,$40,$41,$02,$3f,$40,$41,$42,$43,$40,$44,$02,$3f,$40,$41,$45
    .byte $46,$40,$40,$02,$3f,$40,$41,$47,$48,$40,$49,$02,$3f,$40,$41,$4a
    .byte $4b,$4c,$02,$02,$4b,$4c,$18,$4d,$4e,$4c,$4f,$50,$4b,$4c,$18,$51
    .byte $52,$4c,$4c,$02,$02,$4c,$18,$53,$54,$4c,$55,$56,$02,$4c,$18,$57
    .byte $58,$59,$02,$02,$58,$59,$0c,$5a,$5b,$59,$5c,$02,$58,$59,$0c,$5d
    .byte $5e,$59,$59,$02,$02,$59,$0c,$5f,$60,$59,$61,$02,$02,$59,$0c,$62

;
; for each opcode, index to the MODE2 addressing mode table
IDX_MODE2:
    .byte $4,$6,$0,$0,$2,$2,$2,$2,$4,$1,$5,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$2,$8,$8,$2,$4,$a,$5,$0,$3,$9,$9,$8
    .byte $3,$6,$0,$0,$2,$2,$2,$2,$4,$1,$5,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$8,$8,$8,$2,$4,$a,$5,$0,$0,$9,$9,$8
    .byte $4,$6,$0,$0,$0,$2,$2,$2,$4,$1,$5,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$0,$8,$8,$2,$4,$a,$4,$0,$0,$9,$9,$8
    .byte $4,$6,$0,$0,$2,$2,$2,$2,$4,$1,$5,$0,$0,$3,$3,$8
    .byte $d,$7,$e,$0,$8,$8,$8,$2,$4,$a,$4,$0,$9,$9,$9,$8
    .byte $d,$6,$0,$0,$2,$2,$2,$2,$4,$0,$4,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$8,$8,$c,$2,$4,$a,$4,$0,$3,$9,$9,$8
    .byte $1,$6,$1,$0,$2,$2,$2,$2,$4,$1,$4,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$8,$8,$c,$2,$4,$a,$4,$0,$9,$9,$a,$8
    .byte $1,$6,$0,$0,$2,$2,$2,$2,$4,$1,$4,$4,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$0,$8,$8,$2,$4,$a,$4,$4,$0,$9,$9,$8
    .byte $1,$6,$0,$0,$2,$2,$2,$2,$4,$1,$4,$0,$3,$3,$3,$8
    .byte $d,$7,$e,$0,$0,$8,$8,$2,$4,$a,$4,$0,$0,$9,$9,$8


; -----------------------------------------------------------------------------
; single-character commands
.IFDEF ENABLE_ASSEMBLER
KEYW:   .byte "ACDFGHJMRTX.>;"
; vectors corresponding to commands above
KADDR:  .WORD ASSEM-1,COMPAR-1,DISASS-1,FILL-1
        .WORD GOTO-1,HUNT-1,JSUB-1,DSPLYM-1
        .WORD DSPLYR-1,TRANS-1,EXIT-1
        .WORD ASSEM-1,ALTM-1,ALTR-1
.ELSE
KEYW:   .byte "CDFGHJMRTX>;"
; vectors corresponding to commands above
KADDR:  .WORD COMPAR-1,DISASS-1,FILL-1
        .WORD GOTO-1,HUNT-1,JSUB-1,DSPLYM-1
        .WORD DSPLYR-1,TRANS-1,EXIT-1
        .WORD ALTM-1,ALTR-1
.ENDIF

HIKEY:  .byte "$+&%"
KEYTOP  =*

; -----------------------------------------------------------------------------
MODTAB: .byte $10,$0A,$08,02    ; modulo number systems
LENTAB: .byte $04,$03,$03,$01   ; bits per digit

LINKAD: .WORD SUPER_main             ; address of brk handler
SUPAD:  .WORD SUPER_main             ; address of entry point
