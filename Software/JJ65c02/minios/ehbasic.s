.setcpu "65c02"
.feature labels_without_colons

.export BASIC_init
;.export warm_start
;.export LAB_IGBY
;.export LAB_GBYT
;.export Bpntrl
;.export Bpntrh

.include "minios.inc"
.include "sysram.inc"
.include "tty.inc"

; Enhanced BASIC to assemble under 6502 simulator, $ver 2.22p5

; $E7E1 $E7CF $E7C6 $E7D3 $E7D1 $E7D5 $E7CF $E81E $E825

; 2.00      new revision numbers start here
; 2.01      fixed LCASE$() and UCASE$()
; 2.02      new get value routine done
; 2.03      changed RND() to galoise method
; 2.04      fixed SPC()
; 2.05      new get value routine fixed
; 2.06      changed USR() code
; 2.07      fixed STR$()
; 2.08      changed INPUT and READ to remove need for $00 start to input buffer
; 2.09      fixed RND()
; 2.10      integrated missed changes from an earlier version
; 2.20      added ELSE to IF .. THEN and fixed IF .. GOTO <statement> to cause error
; 2.21      fixed IF .. THEN RETURN to not cause error
; 2.22      fixed RND() breaking the get byte routine
; 2.22p     patched to disable use of decimal mode and fix Ibuff issues
;              (bugsnquirks.txt notes 2, 4 and 5)
;              tabs converted to spaces, tabwidth=6
; 2.22p2    fixed can't continue error on 1st statement after direct mode
;              changed INPUT to throw "break in line ##" on empty line input
; 2.22p3    fixed RAM above code / Ibuff above EhBASIC patch breaks STR$()
;              fix provided by github user mgcaret
; 2.22p4    fixed string compare of equal strings in direct mode returns FALSE
;              fixed FALSE stored to a variable after a string compare
;                 is > 0 and < 1E-16
;              added additional stack floor protection for background interrupts
;              fixed conditional LOOP & NEXT cannot find their data strucure on stack
; 2.22p5    fixes issues reported by users Ruud and dclxvi on the 6502.org forum
;      5.0     http://forum.6502.org/viewtopic.php?f=5&t=5500
;              sanity check for RAM top allows values below RAM base
;      5.1-7   http://forum.6502.org/viewtopic.php?f=5&t=5606
;              1-7 coresponds to the bug# in the thread
;      5.1     TO expression with a subtract may evaluate with the sign bit flipped
;      5.3     call to LAB_1B5B may return to an address -$100 (page not incremented)
;      5.4     string concatenate followed by MINUS or NOT() crashes EhBASIC
;      5.5     garbage collection may cause an overlap with temporary strings
;      5.6     floating point multiply rounding bug
;      5.7     VAL() may cause string variables to be trashed

.segment "ZEROPAGE"

; the following locations are bulk initialized from StrTab at LAB_GMEM
warm_start      .res 1          ; BASIC warm start entry point
warm_start_lo   .res 1          ; BASIC warm start vector jump low byte
warm_start_hi   .res 8          ; BASIC warm start vector jump high byte

Usrjmp          .res 1          ; USR function JMP address
Usrjpl          .res 1          ; USR function JMP vector low byte
Usrjph          .res 1          ; USR function JMP vector high byte
Nullct          .res 1          ; nulls output after each line
TPos            .res 1          ; BASIC terminal position byte
TWidth          .res 1          ; BASIC terminal width byte
Iclim           .res 1          ; input column limit
Itempl          .res 1          ; temporary integer low byte
Itemph          .res 1          ; temporary integer high byte
; end bulk initialize from StrTab at LAB_GMEM

nums_1          = Itempl        ; number to bin/hex string convert MSB
nums_2          = Itemph        ; number to bin/hex string convert
nums_3          .res 1          ; number to bin/hex string convert LSB

Srchc           .res 1          ; search character
Temp3           = Srchc         ; temp byte used in number routines
Scnquo          .res 1          ; scan-between-quotes flag
Asrch           = Scnquo        ; alt search character

XOAw_l          = Srchc         ; eXclusive OR, OR and AND word low byte
XOAw_h          = Scnquo        ; eXclusive OR, OR and AND word high byte

Ibptr           .res 1          ; input buffer pointer
Dimcnt          = Ibptr         ; # of dimensions
Tindx           = Ibptr         ; token index

Defdim          .res 1          ; default DIM flag
Dtypef          .res 1          ; data type flag, $FF=string, $00=numeric
Oquote          .res 1          ; open quote flag (b7) (Flag: DATA scan; LIST quote; memory)
clear_gc_flag   .res 1          ; garbage collected flag
Sufnxf          .res 1          ; subscript/FNX flag, 1xxx xxx = FN(0xxx xxx)
Imode           .res 1          ; input mode flag, $00=INPUT, $80=READ

Cflag           .res 1          ; comparison evaluation flag
TabSiz          .res 1          ; TAB step size (was input flag)

next_s          .res 1          ; next descriptor stack address
                                ; these two bytes form a word pointer to the item
                                ; currently on top of the descriptor stack
last_sl         .res 1          ; last descriptor stack address low byte
last_sh         .res 1          ; last descriptor stack address high byte (always $00)

des_sk          .res 9          ; descriptor stack start address (temp strings)

;               .res 1          ; End of descriptor stack

ut1_pl          .res 1          ; utility pointer 1 low byte
ut1_ph          .res 1          ; utility pointer 1 high byte
ut2_pl          .res 1          ; utility pointer 2 low byte
ut2_ph          .res 1          ; utility pointer 2 high byte

Temp_2          = ut1_pl        ; temp byte for block move

FACt_1          .res 1          ; FAC temp mantissa1
FACt_2          .res 1          ; FAC temp mantissa2
FACt_3          .res 1          ; FAC temp mantissa3

dims_l          = FACt_2        ; array dimension size low byte
dims_h          = FACt_3        ; array dimension size high byte

TempB           .res 1          ; temp page 0 byte

Smeml           .res 1          ; start of mem low byte       (Start-of-Basic)
Smemh           .res 1          ; start of mem high byte      (Start-of-Basic)
Svarl           .res 1          ; start of vars low byte      (Start-of-Variables)
Svarh           .res 1          ; start of vars high byte     (Start-of-Variables)
Sarryl          .res 1          ; var mem end low byte        (Start-of-Arrays)
Sarryh          .res 1          ; var mem end high byte       (Start-of-Arrays)
Earryl          .res 1          ; array mem end low byte      (End-of-Arrays)
Earryh          .res 1          ; array mem end high byte     (End-of-Arrays)
Sstorl          .res 1          ; string storage low byte     (String storage (moving down))
Sstorh          .res 1          ; string storage high byte    (String storage (moving down))
Sutill          .res 1          ; string utility ptr low byte
Sutilh          .res 1          ; string utility ptr high byte
Ememl           .res 1          ; end of mem low byte         (Limit-of-memory)
Ememh           .res 1          ; end of mem high byte        (Limit-of-memory)
Clinel          .res 1          ; current line low byte       (Basic line number)
Clineh          .res 1          ; current line high byte      (Basic line number)
Blinel          .res 1          ; break line low byte         (Previous Basic line number)
Blineh          .res 1          ; break line high byte        (Previous Basic line number)

Cpntrl          .res 1          ; continue pointer low byte
Cpntrh          .res 1          ; continue pointer high byte

Dlinel          .res 1          ; current DATA line low byte
Dlineh          .res 1          ; current DATA line high byte

Dptrl           .res 1          ; DATA pointer low byte
Dptrh           .res 1          ; DATA pointer high byte

Rdptrl          .res 1          ; read pointer low byte
Rdptrh          .res 1          ; read pointer high byte

Varnm1          .res 1          ; current var name 1st byte
Varnm2          .res 1          ; current var name 2nd byte

Cvaral          .res 1          ; current var address low byte
Cvarah          .res 1          ; current var address high byte

Frnxtl          .res 1          ; var pointer for FOR/NEXT low byte
Frnxth          .res 1          ; var pointer for FOR/NEXT high byte

Tidx1           = Frnxtl        ; temp line index

Lvarpl          = Frnxtl        ; let var pointer low byte
Lvarph          = Frnxth        ; let var pointer high byte

prstk           .res 1          ; precedence stacked flag

comp_f          .res 1          ; compare function flag, bits 0,1 and 2 used
                                ; bit 2 set if >
                                ; bit 1 set if =
                                ; bit 0 set if <

func_l          .res 1          ; function pointer low byte
func_h          .res 1          ; function pointer high byte

garb_l          = func_l        ; garbage collection working pointer low byte
garb_h          = func_h        ; garbage collection working pointer high byte

des_2l          .res 1          ; string descriptor_2 pointer low byte
des_2h          .res 1          ; string descriptor_2 pointer high byte

g_step          .res 1          ; garbage collect step size

Fnxjmp          .res 1          ; jump vector for functions
Fnxjpl          .res 1          ; functions jump vector low byte
Fnxjph          .res 1          ; functions jump vector high byte

g_indx          = Fnxjpl        ; garbage collect temp index

FAC2_r          = Fnxjph        ; FAC2 rounding byte

Adatal          .res 1          ; array data pointer low byte
Adatah          .res 1          ; array data pointer high  byte

Nbendl          = Adatal        ; new block end pointer low byte
Nbendh          = Adatah        ; new block end pointer high  byte

Obendl          .res 1          ; old block end pointer low byte
Obendh          .res 1          ; old block end pointer high  byte

numexp          .res 1          ; string to float number exponent count
expcnt          .res 1          ; string to float exponent count

numbit          = numexp        ; bit count for array element calculations

numdpf          .res 1          ; string to float decimal point flag
expneg          .res 1          ; string to float eval exponent -ve flag

Astrtl          = numdpf        ; array start pointer low byte
Astrth          = expneg        ; array start pointer high  byte

Histrl          = numdpf        ; highest string low byte
Histrh          = expneg        ; highest string high  byte

Baslnl          = numdpf        ; BASIC search line pointer low byte
Baslnh          = expneg        ; BASIC search line pointer high  byte

Fvar_l          = numdpf        ; find/found variable pointer low byte
Fvar_h          = expneg        ; find/found variable pointer high  byte

Ostrtl          = numdpf        ; old block start pointer low byte
Ostrth          = expneg        ; old block start pointer high  byte

Vrschl          = numdpf        ; variable search pointer low byte
Vrschh          = expneg        ; variable search pointer high  byte

FAC1_e          .res 1          ; FAC1 exponent
FAC1_1          .res 1          ; FAC1 mantissa1
FAC1_2          .res 1          ; FAC1 mantissa2
FAC1_3          .res 1          ; FAC1 mantissa3
FAC1_s          .res 1          ; FAC1 sign (b7)

str_ln          = FAC1_e        ; string length
str_pl          = FAC1_1        ; string pointer low byte
str_ph          = FAC1_2        ; string pointer high byte

des_pl          = FAC1_2        ; string descriptor pointer low byte
des_ph          = FAC1_3        ; string descriptor pointer high byte

mids_l          = FAC1_3        ; MID$ string temp length byte

negnum          .res 1          ; string to float eval -ve flag
numcon          = negnum        ; series evaluation constant count

FAC1_o          .res 1          ; FAC1 overflow byte

FAC2_e          .res 1          ; FAC2 exponent
FAC2_1          .res 1          ; FAC2 mantissa1
FAC2_2          .res 1          ; FAC2 mantissa2
FAC2_3          .res 1          ; FAC2 mantissa3
FAC2_s          .res 1          ; FAC2 sign (b7)

FAC_sc          .res 1          ; FAC sign comparison, Acc#1 vs #2
FAC1_r          .res 1          ; FAC1 rounding byte

ssptr_l         = FAC_sc        ; string start pointer low byte
ssptr_h         = FAC1_r        ; string start pointer high byte

sdescr          = FAC_sc        ; string descriptor pointer

csidx           .res 1          ; line crunch save index
Asptl           = csidx         ; array size/pointer low byte
Aspth          .res 1           ; array size/pointer high byte

Btmpl           = Asptl         ; BASIC pointer temp low byte
Btmph           = Aspth         ; BASIC pointer temp low byte

Cptrl           = Asptl         ; BASIC pointer temp low byte
Cptrh           = Aspth         ; BASIC pointer temp low byte

Sendl           = Asptl         ; BASIC pointer temp low byte
Sendh           = Aspth         ; BASIC pointer temp low byte

; the following locations are bulk initialized from LAB_2CEE at LAB_2D4E
LAB_IGBY        .res 6          ; get next BASIC byte subroutine

LAB_GBYT        .res 1          ; get current BASIC byte subroutine
Bpntrl          .res 1          ; BASIC execute (get byte) pointer low byte
Bpntrh          .res 20         ; BASIC execute (get byte) pointer high byte
                                ; plus extra space
; end of get BASIC char subroutine
; end bulk initialize from LAB_2CEE at LAB_2D4E

Rbyte4          .res 1          ; extra PRNG byte
Rbyte1          .res 1          ; most significant PRNG byte
Rbyte2          .res 1          ; middle PRNG byte
Rbyte3          .res 1          ; least significant PRNG byte

NmiBase         .res 3          ; NMI handler enabled/setup/triggered flags
                                ; bit function
                                ; === ========
                                ; 7   interrupt enabled
                                ; 6   interrupt setup
                                ; 5   interrupt happened
;               .res 1          ; NMI handler addr low byte
;               .res 1          ; NMI handler addr high byte
IrqBase         .res 3          ; IRQ handler enabled/setup/triggered flags
;               .res 1          ; IRQ handler addr low byte
;               .res 1          ; IRQ handler addr high byte

Decss           .res 1          ; number to decimal string start
Decssp1         .res 16         ; number to decimal string start

; token values needed for BASIC
; primary command tokens (can start a statement)
.enum
    token_END = $80
    token_FOR
    token_NEXT
    token_DATA
    token_INPUT
    token_DIM
    token_READ
    token_LET
    token_DEC
    token_GOTO
    token_RUN
    token_IF
    token_RESTORE
    token_GOSUB
    token_RETIRQ
    token_RETNMI
    token_RETURN
    token_REM
    token_STOP
    token_ON
    token_NULL
    token_INC
    token_WAIT
    token_LOAD
    token_SAVE
    token_DEF
    token_POKE
    token_DOKE
    token_CALL
    token_DO
    token_LOOP
    token_PRINT
    token_CONT
    token_LIST
    token_CLEAR
    token_NEW
    token_WIDTH
    token_GET
    token_SWAP
    token_BITSET
    token_BITCLR
    token_IRQ
    token_NMI

    ; secondary command tokens, can't start a statement
    token_TAB
    token_ELSE
    token_TO
    token_FN
    token_SPC
    token_THEN
    token_NOT
    token_STEP
    token_UNTIL
    token_WHILE
    token_OFF

    ; opperator tokens
    token_PLUS                  ; + token
    token_MINUS                 ; - token
    token_MUL                   ; * token
    token_DIV                   ; / token
    token_POWER                 ; ^ token
    token_AND
    token_EOR
    token_OR
    token_RSHIFT                ; RSHIFT token
    token_LSHIFT                ; LSHIFT token
    token_GT                    ; > token
    token_EQUAL                 ; = token
    token_LT                    ; < token

    ; functions tokens
    token_SGN
    token_INT
    token_ABS
    token_USR
    token_FRE
    token_POS
    token_SQR
    token_RND
    token_LOG
    token_EXP
    token_COS
    token_SIN
    token_TAN
    token_ATN
    token_PEEK
    token_DEEK
    token_SADD
    token_LEN
    token_STRS                  ; STR$ token
    token_VAL
    token_ASC
    token_UCASES                ; UCASE$ token
    token_LCASES                ; LCASE$ token
    token_CHRS                  ; CHR$ token
    token_HEXS                  ; HEX$ token
    token_BINS                  ; BIN$ token
    token_BITTST
    token_MAX
    token_MIN
    token_PI
    token_TWOPI
    token_VPTR
    token_LEFTS                 ; LEFT$ token
    token_RIGHTS                ; RIGHT$ token
    token_MIDS                  ; MID$ token
.endenum

; offsets from a base of X or Y

PLUS_0            = $00       ; X or Y plus 0
PLUS_1            = $01       ; X or Y plus 1
PLUS_2            = $02       ; X or Y plus 2
PLUS_3            = $03       ; X or Y plus 3

LAB_STAK          = $0100     ; stack bottom, no offset

LAB_SKFE          = LAB_STAK+$FE
                              ; flushed stack address
LAB_SKFF          = LAB_STAK+$FF
                              ; flushed stack address

; the following locations are bulk initialized from PG2_TABS at cold_start
ctrl_c_flag     = $0500             ; BASIC CTRL-C flag, 00 = enabled, 01 = dis
ctrl_c_byte     = ctrl_c_flag+1     ; BASIC CTRL-C byte
ctrl_c_timeout  = ctrl_c_byte+1     ; BASIC CTRL-C byte timeout
ctrl_c_vector            = ctrl_c_timeout+1  ; ctrl c check vector
; end bulk initialize from PG2_TABS at cold_start

; the following locations are bulk initialized by min_mon.asm from LAB_vec at LAB_stlp
VEC_IN            = ctrl_c_vector+2 ; input vector
VEC_OUT           = VEC_IN+2        ; output vector
VEC_LD            = VEC_OUT+2       ; load vector
VEC_SV            = VEC_LD+2        ; save vector
; end bulk initialize by min_mon.asm from LAB_vec at LAB_stlp

; Ibuffs can now be anywhere in RAM, ensure that the max length is < $80,
; the input buffer must not cross a page boundary and must not overlap with
; program RAM pages!

;Ibuffs            = IRQ_vec+$14
Ibuffs            = $0700
                              ; start of input buffer after IRQ/NMI code
Ibuffe            = Ibuffs+$47; end of input buffer

Ram_base          = $1000     ; start of user RAM (set as needed, should be page aligned)
Ram_top           = $6000     ; end of user RAM+1 (set as needed, should be page aligned)

Stack_floor       = 16        ; bytes left free on stack for background interrupts

.segment "CODE"

; BASIC cold start entry point
; new page 2 initialisation, copy block to ctrl_c_flag on
cold_start:
    ldy   #PG2_TABE-PG2_TABS-1    ; byte count-1
LAB_2D13
    lda   PG2_TABS,Y          ; get byte
    sta   ctrl_c_flag,Y       ; store in page 2
    dey                       ; decrement count
    bpl   LAB_2D13            ; loop if not done

    ldx   #$FF                ; set byte
    stx   Clineh              ; set current line high byte (set immediate mode)
    txs                       ; reset stack pointer

    lda   #$4C                ; code for JMP
    sta   Fnxjmp              ; save for jump vector for functions

; copy block from LAB_2CEE to $00BC - $00D7
    ldx   #StrTab-LAB_2CEE  ; set byte count
LAB_2D4E
    lda   LAB_2CEE-1,X      ; get byte from table
    sta   LAB_IGBY-1,X      ; save byte in page zero
    dex                     ; decrement count
    bne   LAB_2D4E          ; loop if not all done

; copy block from StrTab to $0000 - $0012
LAB_GMEM
    ldx   #EndTab-StrTab-1  ; set byte count-1
TabLoop
    lda   StrTab,X          ; get byte from table
    sta   warm_start,X          ; save byte in page zero
    dex                     ; decrement count
    bpl   TabLoop           ; loop if not all done

; set-up start values
    lda   #$00              ; clear A
    sta   NmiBase           ; clear NMI handler enabled flag
    sta   IrqBase           ; clear IRQ handler enabled flag
    sta   FAC1_o            ; clear FAC1 overflow byte
    sta   last_sh           ; clear descriptor stack top item pointer high byte

    lda   #$0E              ; set default tab size
    sta   TabSiz            ; save it
    lda   #$03              ; set garbage collect step size for descriptor stack
    sta   g_step            ; save it
    ldx   #des_sk           ; descriptor stack start
    stx   next_s            ; set descriptor stack pointer
    jsr   print_newline          ; print CR/LF
    lda   #<LAB_MSZM        ; point to memory size message (low addr)
    ldy   #>LAB_MSZM        ; point to memory size message (high addr)
    jsr   print_string          ; print null terminated string from memory
    jsr   get_input          ; print "? " and get BASIC input
    stx   Bpntrl            ; set BASIC execute pointer low byte
    sty   Bpntrh            ; set BASIC execute pointer high byte
    jsr   LAB_GBYT          ; get last byte back

    bne   LAB_2DAA          ; branch if not null (user typed something)

    ldy   #$00              ; else clear Y
                              ; character was null so get memory size the hard way
                              ; we get here with Y=0 and Itempl/h = Ram_base
LAB_2D93
    inc   Itempl            ; increment temporary integer low byte
    bne   LAB_2D99          ; branch if no overflow

    inc   Itemph            ; increment temporary integer high byte
    lda   Itemph            ; get high byte
    cmp   #>Ram_top         ; compare with top of RAM+1
    beq   LAB_2DB6          ; branch if match (end of user RAM)

LAB_2D99
    lda   #$55              ; set test byte
    sta   (Itempl),Y        ; save via temporary integer
    cmp   (Itempl),Y        ; compare via temporary integer
    bne   LAB_2DB6          ; branch if fail

    asl                     ; shift test byte left (now $AA)
    sta   (Itempl),Y        ; save via temporary integer
    cmp   (Itempl),Y        ; compare via temporary integer
    beq   LAB_2D93          ; if ok go do next byte

    bne   LAB_2DB6          ; branch if fail

LAB_2DAA
    jsr   LAB_2887          ; get FAC1 from string
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$98              ; compare with exponent = 2^24
    bcs   LAB_GMEM          ; if too large go try again

    jsr   LAB_F2FU          ; save integer part of FAC1 in temporary integer
                              ; (no range check)

LAB_2DB6
    lda   Itempl            ; get temporary integer low byte
    ldy   Itemph            ; get temporary integer high byte
; *** begin patch  2.22p5.0 RAM top sanity check ***
; *** replace
;      CPY   #<Ram_base+1      ; compare with start of RAM+$100 high byte
; +++ with
    cpy   #>Ram_base+1      ; compare with start of RAM+$100 high byte
; *** end patch    2.22p5.0 ***
    bcc   LAB_GMEM          ; if too small go try again


; uncomment these lines if you want to check on the high limit of memory. Note if
; Ram_top is set too low then this will fail. default is ignore it and assume the
; users know what they're doing!

;     CPY   #>Ram_top         ; compare with top of RAM high byte
;     BCC   MEM_OK            ; branch if < RAM top

;     BNE   LAB_GMEM          ; if too large go try again
                              ; else was = so compare low bytes
;     CMP   #<Ram_top         ; compare with top of RAM low byte
;     BEQ   MEM_OK            ; branch if = RAM top

;     BCS   LAB_GMEM          ; if too large go try again

;MEM_OK
    sta   Ememl             ; set end of mem low byte
    sty   Ememh             ; set end of mem high byte
    sta   Sstorl            ; set bottom of string space low byte
    sty   Sstorh            ; set bottom of string space high byte

    ldy   #<Ram_base        ; set start addr low byte
    ldx   #>Ram_base        ; set start addr high byte
    sty   Smeml             ; save start of mem low byte
    stx   Smemh             ; save start of mem high byte

; this line is only needed if Ram_base is not $xx00
      .IF   Ram_base&$FF>0
    ldy   #$00              ; clear Y
      .ENDIF

    tya                     ; clear A
    sta   (Smeml),Y         ; clear first byte
    inc   Smeml             ; increment start of mem low byte

; these two lines are only needed if Ram_base is $xxFF
      .IF   Ram_base&$FF=$FF
    bne   LAB_2E05          ; branch if no rollover
    inc   Smemh             ; increment start of mem high byte
LAB_2E05
      .ENDIF

    jsr   print_newline       ; print CR/LF
    jsr   LAB_1463            ; do "NEW" and "CLEAR"
    lda   Ememl               ; get end of mem low byte
    sec                       ; set carry for subtract
    sbc   Smeml               ; subtract start of mem low byte
    tax                       ; copy to X
    lda   Ememh               ; get end of mem high byte
    sbc   Smemh               ; subtract start of mem high byte
    jsr   LAB_295E            ; print XA as unsigned integer (bytes free)
    lda   #<LAB_SMSG          ; point to sign-on message (low addr)
    ldy   #>LAB_SMSG          ; point to sign-on message (high addr)
    jsr   print_string        ; print null terminated string from memory
    lda   #<LAB_1274          ; warm start vector low byte
    ldy   #>LAB_1274          ; warm start vector high byte
    sta   warm_start_lo       ; save warm start vector low byte
    sty   warm_start_hi       ; save warm start vector high byte
    jmp   (warm_start_lo)     ; go do warm start

; open up space in memory
; move (Ostrtl)-(Obendl) to new block ending at (Nbendl)

; Nbendl,Nbendh - new block end address (A/Y)
; Obendl,Obendh - old block end address
; Ostrtl,Ostrth - old block start address

; returns with ..

; Nbendl,Nbendh - new block start address (high byte - $100)
; Obendl,Obendh - old block start address (high byte - $100)
; Ostrtl,Ostrth - old block start address (unchanged)
LAB_11CF
    jsr   check_avail_mem          ; check available memory, "Out of memory" error if no room
                              ; addr to check is in AY (low/high)
    sta   Earryl            ; save new array mem end low byte
    sty   Earryh            ; save new array mem end high byte

; open up space in memory
; move (Ostrtl)-(Obendl) to new block ending at (Nbendl)
; don't set array end
LAB_11D6
    sec                     ; set carry for subtract
    lda   Obendl            ; get block end low byte
    sbc   Ostrtl            ; subtract block start low byte
    tay                     ; copy MOD(block length/$100) byte to Y
    lda   Obendh            ; get block end high byte
    sbc   Ostrth            ; subtract block start high byte
    tax                     ; copy block length high byte to X
    inx                     ; +1 to allow for count=0 exit
    tya                     ; copy block length low byte to A
    beq   LAB_120A          ; branch if length low byte=0

                              ; block is (X-1)*256+Y bytes, do the Y bytes first

    sec                     ; set carry for add + 1, two's complement
    eor   #$FF              ; invert low byte for subtract
    adc   Obendl            ; add block end low byte

    sta   Obendl            ; save corrected old block end low byte
    bcs   LAB_11F3          ; branch if no underflow

    dec   Obendh            ; else decrement block end high byte
    sec                     ; set carry for add + 1, two's complement
LAB_11F3
    tya                     ; get MOD(block length/$100) byte
    eor   #$FF              ; invert low byte for subtract
    adc   Nbendl            ; add destination end low byte
    sta   Nbendl            ; save modified new block end low byte
    bcs   LAB_1203          ; branch if no underflow

    dec   Nbendh            ; else decrement block end high byte
    bcc   LAB_1203          ; branch always

LAB_11FF
    lda   (Obendl),Y        ; get byte from source
    sta   (Nbendl),Y        ; copy byte to destination
LAB_1203
    dey                     ; decrement index
    bne   LAB_11FF          ; loop until Y=0

                              ; now do Y=0 indexed byte
    lda   (Obendl),Y        ; get byte from source
    sta   (Nbendl),Y        ; save byte to destination
LAB_120A
    dec   Obendh            ; decrement source pointer high byte
    dec   Nbendh            ; decrement destination pointer high byte
    dex                     ; decrement block count
    bne   LAB_1203          ; loop until count = $0

    rts

; check room on stack for A bytes
; stack too deep? do OM error

LAB_1212
; *** patch - additional stack floor protection for background interrupts
; *** add
      .IF   Stack_floor
    clc                     ; prep ADC
    adc   #Stack_floor      ; stack pointer lower limit before interrupts
      .ENDIF
; *** end patch
    sta   TempB             ; save result in temp byte
    tsx                     ; copy stack
    cpx   TempB             ; compare new "limit" with stack
    bcc   LAB_OMER          ; if stack < limit do "Out of memory" error then warm start

    rts

; check available memory, "Out of memory" error if no room
; addr to check is in AY (low/high)
check_avail_mem
    cpy   Sstorh            ; compare bottom of string mem high byte
    bcc   LAB_124B          ; if less then exit (is ok)

    bne   LAB_1229          ; skip next test if greater (tested <)

                              ; high byte was =, now do low byte
    cmp   Sstorl            ; compare with bottom of string mem low byte
    bcc   LAB_124B          ; if less then exit (is ok)

                              ; addr is > string storage ptr (oops!)
LAB_1229
    pha                     ; push addr low byte
    ldx   #$08              ; set index to save Adatal to expneg inclusive
    tya                     ; copy addr high byte (to push on stack)

                              ; save misc numeric work area
LAB_122D
    pha                     ; push byte
    lda   Adatal-1,X        ; get byte from Adatal to expneg ( ,$00 not pushed)
    dex                     ; decrement index
    bpl   LAB_122D          ; loop until all done

    jsr   garbage_collection          ; garbage collection routine

                              ; restore misc numeric work area
    ldx   #$00              ; clear the index to restore bytes
LAB_1238
    pla                     ; pop byte
    sta   Adatal,X          ; save byte to Adatal to expneg
    inx                     ; increment index
    cpx   #$08              ; compare with end + 1
    bmi   LAB_1238          ; loop if more to do

    pla                     ; pop addr high byte
    tay                     ; copy back to Y
    pla                     ; pop addr low byte
    cpy   Sstorh            ; compare bottom of string mem high byte
    bcc   LAB_124B          ; if less then exit (is ok)

    bne   LAB_OMER          ; if greater do "Out of memory" error then warm start

                              ; high byte was =, now do low byte
    cmp   Sstorl            ; compare with bottom of string mem low byte
    bcs   LAB_OMER          ; if >= do "Out of memory" error then warm start

                              ; ok exit, carry clear
LAB_124B
    rts

; do "Out of memory" error then warm start
LAB_OMER
    ldx   #$0C                ; error code $0C ("Out of memory" error)

; do error #X, then warm start
LAB_XERR
    jsr   print_newline       ; print CR/LF

    lda   LAB_BAER,X          ; get error message pointer low byte
    ldy   LAB_BAER+1,X        ; get error message pointer high byte
    jsr   print_string        ; print null terminated string from memory

    jsr   LAB_1491            ; flush stack and clear continue flag
    lda   #<LAB_EMSG          ; point to " Error" low addr
    ldy   #>LAB_EMSG          ; point to " Error" high addr
LAB_1269
    jsr   print_string        ; print null terminated string from memory
    ldy   Clineh              ; get current line high byte
    iny                       ; increment it
    beq   LAB_1274            ; go do warm start (was immediate mode)

                                ; else print line number
    jsr   LAB_2953            ; print " in line [LINE #]"

; BASIC warm start entry point
; wait for Basic command
LAB_1274
                                ; clear ON IRQ/NMI bytes
    lda   #$00                ; clear A
    sta   IrqBase             ; clear enabled byte
    sta   NmiBase             ; clear enabled byte
    lda   #<LAB_RMSG          ; point to "Ready" message low byte
    ldy   #>LAB_RMSG          ; point to "Ready" message high byte
    jsr   print_string        ; go do print string

; wait for Basic command (no "Ready")
LAB_127D
    jsr   LAB_1357            ; call for BASIC input
LAB_1280
    stx   Bpntrl            ; set BASIC execute pointer low byte
    sty   Bpntrh            ; set BASIC execute pointer high byte
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_127D          ; loop while null

; got to interpret input line now ..
    ldx   #$FF              ; current line to null value
    stx   Clineh            ; set current line high byte
    bcc   LAB_1295          ; branch if numeric character (handle new BASIC line)

                              ; no line number .. immediate mode
    jsr   LAB_13A6          ; crunch keywords into Basic tokens
    jmp   LAB_15F6          ; go scan and interpret code

; handle new BASIC line
LAB_1295
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    jsr   LAB_13A6          ; crunch keywords into Basic tokens
    sty   Ibptr             ; save index pointer to end of crunched line
    jsr   LAB_SSLN          ; search BASIC for temp integer line number
    bcc   LAB_12E6          ; branch if not found

                              ; aroooogah! line # already exists! delete it
    ldy   #$01              ; set index to next line pointer high byte
    lda   (Baslnl),Y        ; get next line pointer high byte
    sta   ut1_ph            ; save it
    lda   Svarl             ; get start of vars low byte
    sta   ut1_pl            ; save it
    lda   Baslnh            ; get found line pointer high byte
    sta   ut2_ph            ; save it
    lda   Baslnl            ; get found line pointer low byte
    dey                     ; decrement index
    sbc   (Baslnl),Y        ; subtract next line pointer low byte
    clc                     ; clear carry for add
    adc   Svarl             ; add start of vars low byte
    sta   Svarl             ; save new start of vars low byte
    sta   ut2_pl            ; save destination pointer low byte
    lda   Svarh             ; get start of vars high byte
    adc   #$FF              ; -1 + carry
    sta   Svarh             ; save start of vars high byte
    sbc   Baslnh            ; subtract found line pointer high byte
    tax                     ; copy to block count
    sec                     ; set carry for subtract
    lda   Baslnl            ; get found line pointer low byte
    sbc   Svarl             ; subtract start of vars low byte
    tay                     ; copy to bytes in first block count
    bcs   LAB_12D0          ; branch if overflow

    inx                     ; increment block count (correct for =0 loop exit)
    dec   ut2_ph            ; decrement destination high byte
LAB_12D0
    clc                     ; clear carry for add
    adc   ut1_pl            ; add source pointer low byte
    bcc   LAB_12D8          ; branch if no overflow

    dec   ut1_ph            ; else decrement source pointer high byte
    clc                     ; clear carry

                              ; close up memory to delete old line
LAB_12D8
    lda   (ut1_pl),Y        ; get byte from source
    sta   (ut2_pl),Y        ; copy to destination
    iny                     ; increment index
    bne   LAB_12D8          ; while <> 0 do this block

    inc   ut1_ph            ; increment source pointer high byte
    inc   ut2_ph            ; increment destination pointer high byte
    dex                     ; decrement block count
    bne   LAB_12D8          ; loop until all done

                              ; got new line in buffer and no existing same #
LAB_12E6
    lda   Ibuffs            ; get byte from start of input buffer
    beq   LAB_1319          ; if null line just go flush stack/vars and exit

                              ; got new line and it isn't empty line
    lda   Ememl             ; get end of mem low byte
    ldy   Ememh             ; get end of mem high byte
    sta   Sstorl            ; set bottom of string space low byte
    sty   Sstorh            ; set bottom of string space high byte
    lda   Svarl             ; get start of vars low byte  (end of BASIC)
    sta   Obendl            ; save old block end low byte
    ldy   Svarh             ; get start of vars high byte (end of BASIC)
    sty   Obendh            ; save old block end high byte
    adc   Ibptr             ; add input buffer pointer    (also buffer length)
    bcc   LAB_1301          ; branch if no overflow from add

    iny                     ; else increment high byte
LAB_1301
    sta   Nbendl            ; save new block end low byte (move to, low byte)
    sty   Nbendh            ; save new block end high byte
    jsr   LAB_11CF          ; open up space in memory
                              ; old start pointer Ostrtl,Ostrth set by the find line call
    lda   Earryl            ; get array mem end low byte
    ldy   Earryh            ; get array mem end high byte
    sta   Svarl             ; save start of vars low byte
    sty   Svarh             ; save start of vars high byte
    ldy   Ibptr             ; get input buffer pointer    (also buffer length)
    dey                     ; adjust for loop type
LAB_1311
    lda   Ibuffs-4,Y        ; get byte from crunched line
    sta   (Baslnl),Y        ; save it to program memory
    dey                     ; decrement count
    cpy   #$03              ; compare with first byte-1
    bne   LAB_1311          ; continue while count <> 3

    lda   Itemph            ; get line # high byte
    sta   (Baslnl),Y        ; save it to program memory
    dey                     ; decrement count
    lda   Itempl            ; get line # low byte
    sta   (Baslnl),Y        ; save it to program memory
    dey                     ; decrement count
    lda   #$FF              ; set byte to allow chain rebuild. if you didn't set this
                              ; byte then a zero already here would stop the chain rebuild
                              ; as it would think it was the [EOT] marker.
    sta   (Baslnl),Y        ; save it to program memory

LAB_1319
    jsr   LAB_1477          ; reset execution to start, clear vars and flush stack
    ldx   Smeml             ; get start of mem low byte
    lda   Smemh             ; get start of mem high byte
    ldy   #$01              ; index to high byte of next line pointer
LAB_1325
    stx   ut1_pl            ; set line start pointer low byte
    sta   ut1_ph            ; set line start pointer high byte
    lda   (ut1_pl),Y        ; get it
    beq   LAB_133E          ; exit if end of program

; rebuild chaining of Basic lines

    ldy   #$04              ; point to first code byte of line
                              ; there is always 1 byte + [EOL] as null entries are deleted
LAB_1330
    iny                     ; next code byte
    lda   (ut1_pl),Y        ; get byte
    bne   LAB_1330          ; loop if not [EOL]

    sec                     ; set carry for add + 1
    tya                     ; copy end index
    adc   ut1_pl            ; add to line start pointer low byte
    tax                     ; copy to X
    ldy   #$00              ; clear index, point to this line's next line pointer
    sta   (ut1_pl),Y        ; set next line pointer low byte
    tya                     ; clear A
    adc   ut1_ph            ; add line start pointer high byte + carry
    iny                     ; increment index to high byte
    sta   (ut1_pl),Y        ; save next line pointer low byte
    bcc   LAB_1325          ; go do next line, branch always, carry clear


LAB_133E
    jmp   LAB_127D          ; else we just wait for Basic command, no "Ready"

; print "? " and get BASIC input
get_input
    jsr   LAB_18E3          ; print "?" character
    jsr   LAB_18E0          ; print " "
    bne   LAB_1357          ; call for BASIC input and return

; receive line from keyboard
                              ; $08 as delete key (BACKSPACE on standard keyboard)
LAB_134B
    jsr   print_a_register          ; go print the character
    dex                     ; decrement the buffer counter (delete)
      .byte $2C               ; make LDX into BIT abs

; call for BASIC input (main entry point)
LAB_1357
    ldx   #$00              ; clear BASIC line buffer pointer
LAB_1359
    jsr   V_INPT            ; call scan input device
    bcc   LAB_1359          ; loop if no byte

    beq   LAB_1359          ; loop until valid input (ignore NULLs)

    cmp   #$07              ; compare with [BELL]
    beq   LAB_1378          ; branch if [BELL]

    cmp   #$0D              ; compare with [CR]
    beq   LAB_1384          ; do CR/LF exit if [CR]

    cpx   #$00              ; compare pointer with $00
    bne   LAB_1374          ; branch if not empty

; next two lines ignore any non print character and [SPACE] if input buffer empty
    cmp   #$21              ; compare with [SP]+1
    bcc   LAB_1359          ; if < ignore character

LAB_1374
    cmp   #$08              ; compare with [BACKSPACE] (delete last character)
    beq   LAB_134B          ; go delete last character

LAB_1378
    cpx   #Ibuffe-Ibuffs    ; compare character count with max
    bcs   LAB_138E          ; skip store and do [BELL] if buffer full

    sta   Ibuffs,X          ; else store in buffer
    inx                     ; increment pointer
LAB_137F
    jsr   print_a_register          ; go print the character
    bne   LAB_1359          ; always loop for next character

LAB_1384
    jmp   LAB_1866          ; do CR/LF exit to BASIC

; announce buffer full
LAB_138E
    lda   #$07              ; [BELL] character into A
    bne   LAB_137F          ; go print the [BELL] but ignore input character
                              ; branch always

; crunch keywords into Basic tokens
; position independent buffer version ..
; faster, dictionary search version ....
LAB_13A6
    ldy   #$FF              ; set save index (makes for easy math later)

    sec                     ; set carry for subtract
    lda   Bpntrl            ; get basic execute pointer low byte
    sbc   #<Ibuffs          ; subtract input buffer start pointer
    tax                     ; copy result to X (index past line # if any)

    stx   Oquote            ; clear open quote/DATA flag
LAB_13AC
    lda   Ibuffs,X          ; get byte from input buffer
    beq   LAB_13EC          ; if null save byte then exit

    cmp   #'_'              ; compare with "_"
    bcs   LAB_13EC          ; if >= go save byte then continue crunching

    cmp   #'<'              ; compare with "<"
    bcs   LAB_13CC          ; if >= go crunch now

    cmp   #'0'              ; compare with "0"
    bcs   LAB_13EC          ; if >= go save byte then continue crunching

    sta   Scnquo            ; save buffer byte as search character
    cmp   #$22              ; is it quote character?
    beq   LAB_1410          ; branch if so (copy quoted string)

    cmp   #'*'              ; compare with "*"
    bcc   LAB_13EC          ; if < go save byte then continue crunching

                              ; else crunch now
LAB_13CC
    bit   Oquote            ; get open quote/DATA token flag
    bvs   LAB_13EC          ; branch if b6 of Oquote set (was DATA)
                              ; go save byte then continue crunching

    stx   TempB             ; save buffer read index
    sty   csidx             ; copy buffer save index
    ldy   #<TAB_1STC        ; get keyword first character table low address
    sty   ut2_pl            ; save pointer low byte
    ldy   #>TAB_1STC        ; get keyword first character table high address
    sty   ut2_ph            ; save pointer high byte
    ldy   #$00              ; clear table pointer

LAB_13D0
    cmp   (ut2_pl),Y        ; compare with keyword first character table byte
    beq   LAB_13D1          ; go do word_table_chr if match

    bcc   LAB_13EA          ; if < keyword first character table byte go restore
                              ; Y and save to crunched

    iny                     ; else increment pointer
    bne   LAB_13D0          ; and loop (branch always)

; have matched first character of some keyword
LAB_13D1
    tya                     ; copy matching index
    asl                     ; *2 (bytes per pointer)
    tax                     ; copy to new index
    lda   TAB_CHRT,X        ; get keyword table pointer low byte
    sta   ut2_pl            ; save pointer low byte
    lda   TAB_CHRT+1,X      ; get keyword table pointer high byte
    sta   ut2_ph            ; save pointer high byte

    ldy   #$FF              ; clear table pointer (make -1 for start)

    ldx   TempB             ; restore buffer read index

LAB_13D6
    iny                     ; next table byte
    lda   (ut2_pl),Y        ; get byte from table
LAB_13D8
    bmi   LAB_13EA          ; all bytes matched so go save token

    inx                     ; next buffer byte
    cmp   Ibuffs,X          ; compare with byte from input buffer
    beq   LAB_13D6          ; go compare next if match

    bne   LAB_1417          ; branch if >< (not found keyword)

LAB_13EA
    ldy   csidx             ; restore save index

                              ; save crunched to output
LAB_13EC
    inx                     ; increment buffer index (to next input byte)
    iny                     ; increment save index (to next output byte)
    sta   Ibuffs,Y          ; save byte to output
    cmp   #$00              ; set the flags, set carry
    beq   LAB_142A          ; do exit if was null [EOL]

                              ; A holds token or byte here
    sbc   #':'              ; subtract ":" (carry set by CMP #00)
    beq   LAB_13FF          ; branch if it was ":" (is now $00)

                              ; A now holds token-$3A
    cmp   #token_DATA-$3A      ; compare with DATA token - $3A
    bne   LAB_1401          ; branch if not DATA

                              ; token was : or DATA
LAB_13FF
    sta   Oquote            ; save token-$3A (clear for ":", token_DATA-$3A for DATA)
LAB_1401
    eor   #token_REM-$3A       ; effectively subtract REM token offset
    bne   LAB_13AC          ; If wasn't REM then go crunch rest of line

    sta   Asrch             ; else was REM so set search for [EOL]

                              ; loop for REM, "..." etc.
LAB_1408
    lda   Ibuffs,X          ; get byte from input buffer
    beq   LAB_13EC          ; branch if null [EOL]

    cmp   Asrch             ; compare with stored character
    beq   LAB_13EC          ; branch if match (end quote)

                              ; entry for copy string in quotes, don't crunch
LAB_1410
    iny                     ; increment buffer save index
    sta   Ibuffs,Y          ; save byte to output
    inx                     ; increment buffer read index
    bne   LAB_1408          ; loop while <> 0 (should never be 0!)

                              ; not found keyword this go
LAB_1417
    ldx   TempB             ; compare has failed, restore buffer index (start byte!)

                              ; now find the end of this word in the table
LAB_141B
    lda   (ut2_pl),Y        ; get table byte
    php                     ; save status
    iny                     ; increment table index
    plp                     ; restore byte status
    bpl   LAB_141B          ; if not end of keyword go do next

    lda   (ut2_pl),Y        ; get byte from keyword table
    bne   LAB_13D8          ; go test next word if not zero byte (end of table)

                              ; reached end of table with no match
    lda   Ibuffs,X          ; restore byte from input buffer
    bpl   LAB_13EA          ; branch always (all bytes in buffer are $00-$7F)
                              ; go save byte in output and continue crunching

                              ; reached [EOL]
LAB_142A
    iny                     ; increment pointer
    iny                     ; increment pointer (makes it next line pointer high byte)
    sta   Ibuffs,Y          ; save [EOL] (marks [EOT] in immediate mode)
    iny                     ; adjust for line copy
    iny                     ; adjust for line copy
    iny                     ; adjust for line copy
; *** begin patch for when Ibuffs is $xx00 - Daryl Rictor ***
; *** insert
      .IF   Ibuffs&$FF=0
    lda   Bpntrl            ; test for $00
    bne   LAB_142P          ; not $00
    dec   Bpntrh            ; allow for increment when $xx00
LAB_142P
      .ENDIF
; *** end   patch for when Ibuffs is $xx00 - Daryl Rictor ***
; end of patch
    dec   Bpntrl            ; allow for increment
    rts

; search Basic for temp integer line number from start of mem

LAB_SSLN
    lda   Smeml             ; get start of mem low byte
    ldx   Smemh             ; get start of mem high byte

; search Basic for temp integer line number from AX
; returns carry set if found
; returns Baslnl/Baslnh pointer to found or next higher (not found) line
; old 541 new 507
LAB_SHLN
    ldy   #$01              ; set index
    sta   Baslnl            ; save low byte as current
    stx   Baslnh            ; save high byte as current
    lda   (Baslnl),Y        ; get pointer high byte from addr
    beq   LAB_145F          ; pointer was zero so we're done, do 'not found' exit

    ldy   #$03              ; set index to line # high byte
    lda   (Baslnl),Y        ; get line # high byte
    dey                     ; decrement index (point to low byte)
    cmp   Itemph            ; compare with temporary integer high byte
    bne   LAB_1455          ; if <> skip low byte check

    lda   (Baslnl),Y        ; get line # low byte
    cmp   Itempl            ; compare with temporary integer low byte
LAB_1455
    bcs   LAB_145E          ; else if temp < this line, exit (passed line#)

LAB_1456
    dey                     ; decrement index to next line ptr high byte
    lda   (Baslnl),Y        ; get next line pointer high byte
    tax                     ; copy to X
    dey                     ; decrement index to next line ptr low byte
    lda   (Baslnl),Y        ; get next line pointer low byte
    bcc   LAB_SHLN          ; go search for line # in temp (Itempl/Itemph) from AX
                              ; (carry always clear)

LAB_145E
    beq   LAB_1460          ; exit if temp = found line #, carry is set

LAB_145F
    clc                     ; clear found flag
LAB_1460
    rts

; perform NEW
cmd_NEW:
    bne   LAB_1460          ; exit if not end of statement (to do syntax error)
LAB_1463
    lda   #$00              ; clear A
    tay                     ; clear Y
    sta   (Smeml),Y         ; clear first line, next line pointer, low byte
    iny                     ; increment index
    sta   (Smeml),Y         ; clear first line, next line pointer, high byte
    clc                     ; clear carry
    lda   Smeml             ; get start of mem low byte
    adc   #$02              ; calculate end of BASIC low byte
    sta   Svarl             ; save start of vars low byte
    lda   Smemh             ; get start of mem high byte
    adc   #$00              ; add any carry
    sta   Svarh             ; save start of vars high byte

; reset execution to start, clear vars and flush stack
LAB_1477
    clc                     ; clear carry
    lda   Smeml             ; get start of mem low byte
    adc   #$FF              ; -1
    sta   Bpntrl            ; save BASIC execute pointer low byte
    lda   Smemh             ; get start of mem high byte
    adc   #$FF              ; -1+carry
    sta   Bpntrh            ; save BASIC execute pointer high byte

; "CLEAR" command gets here
LAB_147A
    lda   Ememl             ; get end of mem low byte
    ldy   Ememh             ; get end of mem high byte
    sta   Sstorl            ; set bottom of string space low byte
    sty   Sstorh            ; set bottom of string space high byte
    lda   Svarl             ; get start of vars low byte
    ldy   Svarh             ; get start of vars high byte
    sta   Sarryl            ; save var mem end low byte
    sty   Sarryh            ; save var mem end high byte
    sta   Earryl            ; save array mem end low byte
    sty   Earryh            ; save array mem end high byte
    jsr   LAB_161A          ; perform RESTORE command

; flush stack and clear continue flag
LAB_1491
    ldx   #des_sk           ; set descriptor stack pointer
    stx   next_s            ; save descriptor stack pointer
    pla                     ; pull return address low byte
    tax                     ; copy return address low byte
    pla                     ; pull return address high byte
    stx   LAB_SKFE          ; save to cleared stack
    sta   LAB_SKFF          ; save to cleared stack
    ldx   #$FD              ; new stack pointer
    txs                     ; reset stack
    lda   #$00              ; clear byte
;*** fix p2: no longer necessary as the continue pointer is saved anyway
;      STA   Cpntrh            ; clear continue pointer high byte
    sta   Sufnxf            ; clear subscript/FNX flag
LAB_14A6
    rts

; perform CLEAR
cmd_CLEAR:
    beq   LAB_147A          ; if no following token go do "CLEAR"
                              ; else there was a following token (go do syntax error)
    rts

; perform LIST [n][-m]
; bigger, faster version (a _lot_ faster)

cmd_LIST
    bcc   LAB_14BD          ; branch if next character numeric (LIST n..)

    beq   LAB_14BD          ; branch if next character [NULL] (LIST)

    cmp   #token_MINUS         ; compare with token for -
    bne   LAB_14A6          ; exit if not - (LIST -m)

                              ; LIST [[n][-m]]
                              ; this bit sets the n , if present, as the start and end
LAB_14BD
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    jsr   LAB_SSLN          ; search BASIC for temp integer line number
                              ; (pointer in Baslnl/Baslnh)
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_14D4          ; branch if no more characters

                              ; this bit checks the - is present
    cmp   #token_MINUS         ; compare with token for -
    bne   LAB_1460          ; return if not "-" (will be Syntax error)

                              ; LIST [n]-m
                              ; the - was there so set m as the end value
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    bne   LAB_1460          ; exit if not ok

LAB_14D4
    lda   Itempl            ; get temporary integer low byte
    ora   Itemph            ; OR temporary integer high byte
    bne   LAB_14E2          ; branch if start set

    lda   #$FF              ; set for -1
    sta   Itempl            ; set temporary integer low byte
    sta   Itemph            ; set temporary integer high byte
LAB_14E2
    ldy   #$01              ; set index for line
    sty   Oquote            ; clear open quote flag
    jsr   print_newline          ; print CR/LF
    lda   (Baslnl),Y        ; get next line pointer high byte
                              ; pointer initially set by search at LAB_14BD
    beq   LAB_152B          ; if null all done so exit
    jsr   LAB_1629          ; do CRTL-C check vector

    iny                     ; increment index for line
    lda   (Baslnl),Y        ; get line # low byte
    tax                     ; copy to X
    iny                     ; increment index
    lda   (Baslnl),Y        ; get line # high byte
    cmp   Itemph            ; compare with temporary integer high byte
    bne   LAB_14FF          ; branch if no high byte match

    cpx   Itempl            ; compare with temporary integer low byte
    beq   LAB_1501          ; branch if = last line to do (< will pass next branch)

LAB_14FF                      ; else ..
    bcs   LAB_152B          ; if greater all done so exit

LAB_1501
    sty   Tidx1             ; save index for line
    jsr   LAB_295E          ; print XA as unsigned integer
    lda   #$20              ; space is the next character
LAB_1508
    ldy   Tidx1             ; get index for line
    and   #$7F              ; mask top out bit of character
LAB_150C
    jsr   print_a_register          ; go print the character
    cmp   #$22              ; was it " character
    bne   LAB_1519          ; branch if not

                              ; we are either entering or leaving a pair of quotes
    lda   Oquote            ; get open quote flag
    eor   #$FF              ; toggle it
    sta   Oquote            ; save it back
LAB_1519
    iny                     ; increment index
    lda   (Baslnl),Y        ; get next byte
    bne   LAB_152E          ; branch if not [EOL] (go print character)
    tay                     ; else clear index
    lda   (Baslnl),Y        ; get next line pointer low byte
    tax                     ; copy to X
    iny                     ; increment index
    lda   (Baslnl),Y        ; get next line pointer high byte
    stx   Baslnl            ; set pointer to line low byte
    sta   Baslnh            ; set pointer to line high byte
    bne   LAB_14E2          ; go do next line if not [EOT]
                              ; else ..
LAB_152B
    rts

LAB_152E
    bpl   LAB_150C          ; just go print it if not token byte

                              ; else was token byte so uncrunch it (maybe)
    bit   Oquote            ; test the open quote flag
    bmi   LAB_150C          ; just go print character if open quote set

    ldx   #>LAB_KEYT        ; get table address high byte
    asl                     ; *2
    asl                     ; *4
    bcc   LAB_152F          ; branch if no carry

    inx                     ; else increment high byte
    clc                     ; clear carry for add
LAB_152F
    adc   #<LAB_KEYT        ; add low byte
    bcc   LAB_1530          ; branch if no carry

    inx                     ; else increment high byte
LAB_1530
    sta   ut2_pl            ; save table pointer low byte
    stx   ut2_ph            ; save table pointer high byte
    sty   Tidx1             ; save index for line
    ldy   #$00              ; clear index
    lda   (ut2_pl),Y        ; get length
    tax                     ; copy length
    iny                     ; increment index
    lda   (ut2_pl),Y        ; get 1st character
    dex                     ; decrement length
    beq   LAB_1508          ; if no more characters exit and print

    jsr   print_a_register          ; go print the character
    iny                     ; increment index
    lda   (ut2_pl),Y        ; get keyword address low byte
    pha                     ; save it for now
    iny                     ; increment index
    lda   (ut2_pl),Y        ; get keyword address high byte
    ldy   #$00
    sta   ut2_ph            ; save keyword pointer high byte
    pla                     ; pull low byte
    sta   ut2_pl            ; save keyword pointer low byte
LAB_1540
    lda   (ut2_pl),Y        ; get character
    dex                     ; decrement character count
    beq   LAB_1508          ; if last character exit and print

    jsr   print_a_register          ; go print the character
    iny                     ; increment index
    bne   LAB_1540          ; loop for next character

; perform FOR

basic_FOR
    lda   #$80              ; set FNX
    sta   Sufnxf            ; set subscript/FNX flag
    jsr   basic_LET           ; go do LET
    pla                     ; pull return address
    pla                     ; pull return address
    lda   #$10              ; we need 16d bytes !
    jsr   LAB_1212          ; check room on stack for A bytes
    jsr   LAB_SNBS          ; scan for next BASIC statement ([:] or [EOL])
    clc                     ; clear carry for add
    tya                     ; copy index to A
    adc   Bpntrl            ; add BASIC execute pointer low byte
    pha                     ; push onto stack
    lda   Bpntrh            ; get BASIC execute pointer high byte
    adc   #$00              ; add carry
    pha                     ; push onto stack
    lda   Clineh            ; get current line high byte
    pha                     ; push onto stack
    lda   Clinel            ; get current line low byte
    pha                     ; push onto stack
    lda   #token_TO            ; get "TO" token
    jsr   LAB_SCCA          ; scan for CHR$(A) , else do syntax error then warm start
    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
; *** begin patch  2.22p5.1   TO expression may get sign bit flipped
; *** add
    jsr   LAB_27BA          ; round FAC1
; *** end   patch  2.22p5.1   TO expression may get sign bit flipped
    lda   FAC1_s            ; get FAC1 sign (b7)
    ora   #$7F              ; set all non sign bits
    and   FAC1_1            ; and FAC1 mantissa1
    sta   FAC1_1            ; save FAC1 mantissa1
    lda   #<LAB_159F        ; set return address low byte
    ldy   #>LAB_159F        ; set return address high byte
    sta   ut1_pl            ; save return address low byte
    sty   ut1_ph            ; save return address high byte
    jmp   LAB_1B66          ; round FAC1 and put on stack (returns to next instruction)

LAB_159F
    lda   #<LAB_259C        ; set 1 pointer low addr (default step size)
    ldy   #>LAB_259C        ; set 1 pointer high addr
    jsr   LAB_UFAC          ; unpack memory (AY) into FAC1
    jsr   LAB_GBYT          ; scan memory
    cmp   #token_STEP          ; compare with STEP token
    bne   LAB_15B3          ; jump if not "STEP"

                              ;.was step so ..
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
LAB_15B3
    jsr   LAB_27CA          ; return A=FF,C=1/-ve A=01,C=0/+ve
    sta   FAC1_s            ; set FAC1 sign (b7)
                              ; this is +1 for +ve step and -1 for -ve step, in NEXT we
                              ; compare the FOR value and the TO value and return +1 if
                              ; FOR > TO, 0 if FOR = TO and -1 if FOR < TO. the value
                              ; here (+/-1) is then compared to that result and if they
                              ; are the same (+ve and FOR > TO or -ve and FOR < TO) then
                              ; the loop is done

; *** begin patch  2.22p5.3   potential return address -$100 (page not incremented) ***
; *** add
;   .IF [* & $FF] == $FD
;      NOP                     ; return address of JSR +1 (on  next page)
;   .ENDIF
; *** end   patch  2.22p5.3   potential return address -$100 (page not incremented) ***
    jsr   LAB_1B5B          ; push sign, round FAC1 and put on stack
    lda   Frnxth            ; get var pointer for FOR/NEXT high byte
    pha                     ; push on stack
    lda   Frnxtl            ; get var pointer for FOR/NEXT low byte
    pha                     ; push on stack
    lda   #token_FOR           ; get FOR token
    pha                     ; push on stack

; interpreter inner loop

LAB_15C2
    jsr   LAB_1629          ; do CRTL-C check vector
    lda   Bpntrl            ; get BASIC execute pointer low byte
    ldy   Bpntrh            ; get BASIC execute pointer high byte

    ldx   Clineh            ; continue line is $FFxx for immediate mode
                              ; ($00xx for RUN from immediate mode)
    inx                     ; increment it (now $00 if immediate mode)
;*** fix p2: skip no longer necessary as the continue pointer is saved anyway
;      BEQ   LAB_15D1          ; branch if null (immediate mode)

    sta   Cpntrl            ; save continue pointer low byte
    sty   Cpntrh            ; save continue pointer high byte
LAB_15D1
    ldy   #$00              ; clear index
    lda   (Bpntrl),Y        ; get next byte
    beq   LAB_15DC          ; branch if null [EOL]

    cmp   #':'              ; compare with ":"
    beq   LAB_15F6          ; branch if = (statement separator)

LAB_15D9
    jmp   LAB_SNER          ; else syntax error then warm start

                              ; have reached [EOL]
LAB_15DC
    ldy   #$02              ; set index
    lda   (Bpntrl),Y        ; get next line pointer high byte
    clc                     ; clear carry for no "BREAK" message
    beq   LAB_1651          ; if null go to immediate mode (was immediate or [EOT]
                              ; marker)

    iny                     ; increment index
    lda   (Bpntrl),Y        ; get line # low byte
    sta   Clinel            ; save current line low byte
    iny                     ; increment index
    lda   (Bpntrl),Y        ; get line # high byte
    sta   Clineh            ; save current line high byte
    tya                     ; A now = 4
    adc   Bpntrl            ; add BASIC execute pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    bcc   LAB_15F6          ; branch if no overflow

    inc   Bpntrh            ; else increment BASIC execute pointer high byte
LAB_15F6
    jsr   LAB_IGBY          ; increment and scan memory

LAB_15F9
    jsr   LAB_15FF          ; go interpret BASIC code from (Bpntrl)

LAB_15FC
    jmp   LAB_15C2          ; loop

; interpret BASIC code from (Bpntrl)

LAB_15FF
    beq   LAB_1628          ; exit if zero [EOL]

LAB_1602
    asl                     ; *2 bytes per vector and normalise token
    bcs   LAB_1609          ; branch if was token

    jmp   basic_LET           ; else go do implied LET

LAB_1609
    cmp   #(token_TAB-$80)*2   ; compare normalised token * 2 with TAB
    bcs   LAB_15D9          ; branch if A>=TAB (do syntax error then warm start)
                              ; only tokens before TAB can start a line
    tay                     ; copy to index
    lda   LAB_CTBL+1,Y      ; get vector high byte
    pha                     ; onto stack
    lda   LAB_CTBL,Y        ; get vector low byte
    pha                     ; onto stack
    jmp   LAB_IGBY          ; jump to increment and scan memory
                              ; then "return" to vector

; CTRL-C check jump. this is called as a subroutine but exits back via a jump if a
; key press is detected.

LAB_1629
    jmp   (ctrl_c_vector)          ; ctrl c check vector

; if there was a key press it gets back here ..

LAB_1636
    cmp   #$03              ; compare with CTRL-C

; perform STOP

basic_STOP
    bcs   LAB_163B          ; branch if token follows STOP
                              ; else just END
; END

basic_END
    clc                     ; clear the carry, indicate a normal program end
LAB_163B
    bne   LAB_167A          ; if wasn't CTRL-C or there is a following byte return

    lda   Bpntrh            ; get the BASIC execute pointer high byte
;*** fix p2: skip no longer necessary as the continue pointer is saved anyway
;      EOR   #>Ibuffs          ; compare with buffer address high byte (Cb unchanged)
;      BEQ   LAB_164F          ; branch if the BASIC pointer is in the input buffer
;                              ; (can't continue in immediate mode)
;                              ; else ..
;      EOR   #>Ibuffs          ; correct the bits
    ldy   Bpntrl            ; get BASIC execute pointer low byte
    sty   Cpntrl            ; save continue pointer low byte
    sta   Cpntrh            ; save continue pointer high byte
LAB_1647
    lda   Clinel            ; get current line low byte
    ldy   Clineh            ; get current line high byte
    sta   Blinel            ; save break line low byte
    sty   Blineh            ; save break line high byte
LAB_164F
    pla                     ; pull return address low
    pla                     ; pull return address high
LAB_1651
    bcc   LAB_165E          ; if was program end just do warm start

                              ; else ..
    lda   #<LAB_BMSG        ; point to "Break" low byte
    ldy   #>LAB_BMSG        ; point to "Break" high byte
    jmp   LAB_1269          ; print "Break" and do warm start

LAB_165E
    jmp   LAB_1274          ; go do warm start

; perform RESTORE

basic_RESTORE
    bne   basic_RESTOREn      ; branch if next character not null (RESTORE n)

LAB_161A
    sec                     ; set carry for subtract
    lda   Smeml             ; get start of mem low byte
    sbc   #$01              ; -1
    ldy   Smemh             ; get start of mem high byte
    bcs   LAB_1624          ; branch if no underflow

LAB_uflow
    dey                     ; else decrement high byte
LAB_1624
    sta   Dptrl             ; save DATA pointer low byte
    sty   Dptrh             ; save DATA pointer high byte
LAB_1628
    rts

                              ; is RESTORE n
basic_RESTOREn
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    jsr   LAB_SNBL          ; scan for next BASIC line
    lda   Clineh            ; get current line high byte
    cmp   Itemph            ; compare with temporary integer high byte
    bcs   LAB_reset_search  ; branch if >= (start search from beginning)

    tya                     ; else copy line index to A
    sec                     ; set carry (+1)
    adc   Bpntrl            ; add BASIC execute pointer low byte
    ldx   Bpntrh            ; get BASIC execute pointer high byte
    bcc   LAB_go_search     ; branch if no overflow to high byte

    inx                     ; increment high byte
    bcs   LAB_go_search     ; branch always (can never be carry clear)

; search for line # in temp (Itempl/Itemph) from start of mem pointer (Smeml)

LAB_reset_search
    lda   Smeml             ; get start of mem low byte
    ldx   Smemh             ; get start of mem high byte

; search for line # in temp (Itempl/Itemph) from (AX)

LAB_go_search

    jsr   LAB_SHLN          ; search Basic for temp integer line number from AX
    bcs   LAB_line_found    ; if carry set go set pointer

    jmp   LAB_16F7          ; else go do "Undefined statement" error

LAB_line_found
                              ; carry already set for subtract
    lda   Baslnl            ; get pointer low byte
    sbc   #$01              ; -1
    ldy   Baslnh            ; get pointer high byte
    bcs   LAB_1624          ; branch if no underflow (save DATA pointer and return)

    bcc   LAB_uflow         ; else decrement high byte then save DATA pointer and
                              ; return (branch always)

; perform NULL

LAB_NULL
    jsr   LAB_GTBY          ; get byte parameter
    stx   Nullct            ; save new NULL count
LAB_167A
    rts

; perform CONT

basic_CONT
    bne   LAB_167A          ; if following byte exit to do syntax error

    ldy   Cpntrh            ; get continue pointer high byte
    cpy   #>Ibuffs          ; *** fix p2: test direct mode
    bne   LAB_166C          ; go do continue if we can

    ldx   #$1E              ; error code $1E ("Can't continue" error)
    jmp   LAB_XERR          ; do error #X, then warm start

                              ; we can continue so ..
LAB_166C
    lda   #token_ON            ; set token for ON
    jsr   LAB_IRQ           ; set IRQ flags
    lda   #token_ON            ; set token for ON
    jsr   LAB_NMI           ; set NMI flags

    sty   Bpntrh            ; save BASIC execute pointer high byte
    lda   Cpntrl            ; get continue pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    lda   Blinel            ; get break line low byte
    ldy   Blineh            ; get break line high byte
    sta   Clinel            ; set current line low byte
    sty   Clineh            ; set current line high byte
    rts

; perform RUN

cmd_RUN
    bne   LAB_1696          ; branch if RUN n
    jmp   LAB_1477          ; reset execution to start, clear variables, flush stack and
                              ; return

; does RUN n

LAB_1696
    jsr   LAB_147A          ; go do "CLEAR"
    beq   LAB_16B0          ; get n and do GOTO n (branch always as CLEAR sets Z=1)

; perform DO

basic_DO
    lda   #$05              ; need 5 bytes for DO
    jsr   LAB_1212          ; check room on stack for A bytes
    lda   Bpntrh            ; get BASIC execute pointer high byte
    pha                     ; push on stack
    lda   Bpntrl            ; get BASIC execute pointer low byte
    pha                     ; push on stack
    lda   Clineh            ; get current line high byte
    pha                     ; push on stack
    lda   Clinel            ; get current line low byte
    pha                     ; push on stack
    lda   #token_DO            ; token for DO
    pha                     ; push on stack
    jsr   LAB_GBYT          ; scan memory
    jmp   LAB_15C2          ; go do interpreter inner loop

; perform GOSUB

basic_GOSUB
    lda   #$05              ; need 5 bytes for GOSUB
    jsr   LAB_1212          ; check room on stack for A bytes
    lda   Bpntrh            ; get BASIC execute pointer high byte
    pha                     ; push on stack
    lda   Bpntrl            ; get BASIC execute pointer low byte
    pha                     ; push on stack
    lda   Clineh            ; get current line high byte
    pha                     ; push on stack
    lda   Clinel            ; get current line low byte
    pha                     ; push on stack
    lda   #token_GOSUB         ; token for GOSUB
    pha                     ; push on stack
LAB_16B0
    jsr   LAB_GBYT          ; scan memory
    jsr   basic_GOTO          ; perform GOTO n
    jmp   LAB_15C2          ; go do interpreter inner loop
                              ; (can't RTS, we used the stack!)

; perform GOTO

basic_GOTO
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    jsr   LAB_SNBL          ; scan for next BASIC line
    lda   Clineh            ; get current line high byte
    cmp   Itemph            ; compare with temporary integer high byte
    bcs   LAB_16D0          ; branch if >= (start search from beginning)

    tya                     ; else copy line index to A
    sec                     ; set carry (+1)
    adc   Bpntrl            ; add BASIC execute pointer low byte
    ldx   Bpntrh            ; get BASIC execute pointer high byte
    bcc   LAB_16D4          ; branch if no overflow to high byte

    inx                     ; increment high byte
    bcs   LAB_16D4          ; branch always (can never be carry)

; search for line # in temp (Itempl/Itemph) from start of mem pointer (Smeml)

LAB_16D0
    lda   Smeml             ; get start of mem low byte
    ldx   Smemh             ; get start of mem high byte

; search for line # in temp (Itempl/Itemph) from (AX)

LAB_16D4
    jsr   LAB_SHLN          ; search Basic for temp integer line number from AX
    bcc   LAB_16F7          ; if carry clear go do "Undefined statement" error
                              ; (unspecified statement)

                              ; carry already set for subtract
    lda   Baslnl            ; get pointer low byte
    sbc   #$01              ; -1
    sta   Bpntrl            ; save BASIC execute pointer low byte
    lda   Baslnh            ; get pointer high byte
    sbc   #$00              ; subtract carry
    sta   Bpntrh            ; save BASIC execute pointer high byte
LAB_16E5
    rts

basic_DONOK
    ldx   #$22              ; error code $22 ("LOOP without DO" error)
    jmp   LAB_XERR          ; do error #X, then warm start

; perform LOOP

cmd_LOOP
    tay                     ; save following token
    tsx                     ; copy stack pointer
    lda   LAB_STAK+3,X      ; get token byte from stack
    cmp   #token_DO            ; compare with DO token
    bne   basic_DONOK         ; branch if no matching DO

    inx                     ; dump calling routine return address
    inx                     ; dump calling routine return address
    txs                     ; correct stack
    tya                     ; get saved following token back
    beq   LoopAlways        ; if no following token loop forever
                              ; (stack pointer in X)

    cmp   #':'              ; could be ':'
    beq   LoopAlways        ; if :... loop forever

    sbc   #token_UNTIL         ; subtract token for UNTIL, we know carry is set here
    tax                     ; copy to X (if it was UNTIL then Y will be correct)
    beq   DoRest            ; branch if was UNTIL

    dex                     ; decrement result
    bne   LAB_16FC          ; if not WHILE go do syntax error and warm start
                              ; only if the token was WHILE will this fail

    dex                     ; set invert result byte
DoRest
    stx   Frnxth            ; save invert result byte
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_EVEX          ; evaluate expression
    lda   FAC1_e            ; get FAC1 exponent
    beq   DoCmp             ; if =0 go do straight compare

    lda   #$FF              ; else set all bits
DoCmp
    tsx                     ; copy stack pointer
    eor   Frnxth            ; EOR with invert byte
    bne   LoopDone          ; if <> 0 clear stack and back to interpreter loop

                              ; loop condition wasn't met so do it again
LoopAlways
    lda   LAB_STAK+2,X      ; get current line low byte
    sta   Clinel            ; save current line low byte
    lda   LAB_STAK+3,X      ; get current line high byte
    sta   Clineh            ; save current line high byte
    lda   LAB_STAK+4,X      ; get BASIC execute pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    lda   LAB_STAK+5,X      ; get BASIC execute pointer high byte
    sta   Bpntrh            ; save BASIC execute pointer high byte
    jsr   LAB_GBYT          ; scan memory
    jmp   LAB_15C2          ; go do interpreter inner loop

                              ; clear stack and back to interpreter loop
LoopDone
    inx                     ; dump DO token
    inx                     ; dump current line low byte
    inx                     ; dump current line high byte
    inx                     ; dump BASIC execute pointer low byte
    inx                     ; dump BASIC execute pointer high byte
    txs                     ; correct stack
    jmp   basic_DATA          ; go perform DATA (find : or [EOL])

; do the return without gosub error

LAB_16F4
    ldx   #$04              ; error code $04 ("RETURN without GOSUB" error)
      .byte $2C               ; makes next line BIT LAB_0EA2

LAB_16F7                      ; do undefined statement error
    ldx   #$0E              ; error code $0E ("Undefined statement" error)
    jmp   LAB_XERR          ; do error #X, then warm start

; perform RETURN

LAB_RETURN
    bne   LAB_16E5          ; exit if following token (to allow syntax error)

LAB_16E8
    pla                     ; dump calling routine return address
    pla                     ; dump calling routine return address
    pla                     ; pull token
    cmp   #token_GOSUB         ; compare with GOSUB token
    bne   LAB_16F4          ; branch if no matching GOSUB

LAB_16FF
    pla                     ; pull current line low byte
    sta   Clinel            ; save current line low byte
    pla                     ; pull current line high byte
    sta   Clineh            ; save current line high byte
    pla                     ; pull BASIC execute pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    pla                     ; pull BASIC execute pointer high byte
    sta   Bpntrh            ; save BASIC execute pointer high byte

                              ; now do the DATA statement as we could be returning into
                              ; the middle of an ON <var> GOSUB n,m,p,q line
                              ; (the return address used by the DATA statement is the one
                              ; pushed before the GOSUB was executed!)

; perform DATA

basic_DATA
    jsr   LAB_SNBS          ; scan for next BASIC statement ([:] or [EOL])

                              ; set BASIC execute pointer
LAB_170F
    tya                     ; copy index to A
    clc                     ; clear carry for add
    adc   Bpntrl            ; add BASIC execute pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    bcc   LAB_1719          ; skip next if no carry

    inc   Bpntrh            ; else increment BASIC execute pointer high byte
LAB_1719
    rts

LAB_16FC
    jmp   LAB_SNER          ; do syntax error then warm start

; scan for next BASIC statement ([:] or [EOL])
; returns Y as index to [:] or [EOL]

LAB_SNBS
    ldx   #':'              ; set look for character = ":"
      .byte $2C               ; makes next line BIT $00A2

; scan for next BASIC line
; returns Y as index to [EOL]

LAB_SNBL
    ldx   #$00              ; set alt search character = [EOL]
    ldy   #$00              ; set search character = [EOL]
    sty   Asrch             ; store search character
LAB_1725
    txa                     ; get alt search character
    eor   Asrch             ; toggle search character, effectively swap with $00
    sta   Asrch             ; save swapped search character
LAB_172D
    lda   (Bpntrl),Y        ; get next byte
    beq   LAB_1719          ; exit if null [EOL]

    cmp   Asrch             ; compare with search character
    beq   LAB_1719          ; exit if found

    iny                     ; increment index
    cmp   #$22              ; compare current character with open quote
    bne   LAB_172D          ; if not open quote go get next character

    beq   LAB_1725          ; if found go swap search character for alt search character

; perform IF

basic_IF
    jsr   LAB_EVEX          ; evaluate the expression
    jsr   LAB_GBYT          ; scan memory
    cmp   #token_THEN          ; compare with THEN token
    beq   LAB_174B          ; if it was THEN go do IF

                              ; wasn't IF .. THEN so must be IF .. GOTO
    cmp   #token_GOTO          ; compare with GOTO token
    bne   LAB_16FC          ; if it wasn't GOTO go do syntax error

    ldx   Bpntrl            ; save the basic pointer low byte
    ldy   Bpntrh            ; save the basic pointer high byte
    jsr   LAB_IGBY          ; increment and scan memory
    bcs   LAB_16FC          ; if not numeric go do syntax error

    stx   Bpntrl            ; restore the basic pointer low byte
    sty   Bpntrh            ; restore the basic pointer high byte
LAB_174B
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_174E          ; if the result was zero go look for an ELSE

    jsr   LAB_IGBY          ; else increment and scan memory
    bcs   LAB_174D          ; if not numeric go do var or keyword

LAB_174C
    jmp   basic_GOTO          ; else was numeric so do GOTO n

                              ; is var or keyword
LAB_174D
; *** patch       allow NEXT, LOOP & RETURN to find FOR, DO or GOSUB structure on stack
; *** replace
;      CMP   #token_RETURN        ; compare the byte with the token for RETURN
;      BNE   LAB_174G          ; if it wasn't RETURN go interpret BASIC code from (Bpntrl)
;                              ; and return to this code to process any following code
;
;      JMP   LAB_1602          ; else it was RETURN so interpret BASIC code from (Bpntrl)
;                              ; but don't return here
;
;LAB_174G
;      JSR   LAB_15FF          ; interpret BASIC code from (Bpntrl)
;
;; the IF was executed and there may be a following ELSE so the code needs to return
;; here to check and ignore the ELSE if present
;
;      LDY   #$00              ; clear the index
;      LDA   (Bpntrl),Y        ; get the next BASIC byte
;      CMP   #token_ELSE          ; compare it with the token for ELSE
;      BEQ   basic_DATA          ; if ELSE ignore the following statement
;
;; there was no ELSE so continue execution of IF <expr> THEN <stat> [: <stat>]. any
;; following ELSE will, correctly, cause a syntax error
;
;      RTS                     ; else return to the interpreter inner loop
;
; *** with
    pla                     ; discard interpreter loop return address
    pla                     ; so data structures are at the correct stack offset
    jsr   LAB_GBYT          ; restore token or variable
    jsr   LAB_15FF          ; interpret BASIC code from (Bpntrl)

; the IF was executed and there may be a following ELSE so the code needs to return
; here to check and ignore the ELSE if present

    ldy   #$00              ; clear the index
    lda   (Bpntrl),Y        ; get the next BASIC byte
    cmp   #token_ELSE          ; compare it with the token for ELSE
    bne   LAB_no_ELSE       ; no - continue on this line
    jsr   basic_DATA          ; yes - skip the rest of the line

; there was no ELSE so continue execution of IF <expr> THEN <stat> [: <stat>]. any
; following ELSE will, correctly, cause a syntax error

LAB_no_ELSE
    jmp LAB_15C2            ; return to the interpreter inner loop
; *** end patch  allow NEXT, LOOP & RETURN to find FOR, DO or GOSUB structure on stack

; perform ELSE after IF

LAB_174E
    ldy   #$00              ; clear the BASIC byte index
    ldx   #$01              ; clear the nesting depth
LAB_1750
    iny                     ; increment the BASIC byte index
    lda   (Bpntrl),Y        ; get the next BASIC byte
    beq   LAB_1753          ; if EOL go add the pointer and return

    cmp   #token_IF            ; compare the byte with the token for IF
    bne   LAB_1752          ; if not IF token skip the depth increment

    inx                     ; else increment the nesting depth ..
    bne   LAB_1750          ; .. and continue looking

LAB_1752
    cmp   #token_ELSE          ; compare the byte with the token for ELSE
    bne   LAB_1750          ; if not ELSE token continue looking

    dex                     ; was ELSE so decrement the nesting depth
    bne   LAB_1750          ; loop if still nested

    iny                     ; increment the BASIC byte index past the ELSE

; found the matching ELSE, now do <{n|statement}>

LAB_1753
    tya                     ; else copy line index to A
    clc                     ; clear carry for add
    adc   Bpntrl            ; add the BASIC execute pointer low byte
    sta   Bpntrl            ; save the BASIC execute pointer low byte
    bcc   LAB_1754          ; branch if no overflow to high byte

    inc   Bpntrh            ; else increment the BASIC execute pointer high byte
LAB_1754
    jsr   LAB_GBYT          ; scan memory
    bcc   LAB_174C          ; if numeric do GOTO n
                              ; the code will return to the interpreter loop at the
                              ; tail end of the GOTO <n>

    jmp   LAB_15FF          ; interpret BASIC code from (Bpntrl)
                              ; the code will return to the interpreter loop at the
                              ; tail end of the <statement>

; perform REM, skip (rest of) line

basic_REM
    jsr   LAB_SNBL          ; scan for next BASIC line
    jmp   LAB_170F          ; go set BASIC execute pointer and return, branch always

LAB_16FD
    jmp   LAB_SNER          ; do syntax error then warm start

; perform ON

basic_ON
    cmp   #token_IRQ           ; was it IRQ token ?
    bne   LAB_NOIN          ; if not go check NMI

    jmp   LAB_SIRQ          ; else go set-up IRQ

LAB_NOIN
    cmp   #token_NMI           ; was it NMI token ?
    bne   LAB_NONM          ; if not go do normal ON command

    jmp   LAB_SNMI          ; else go set-up NMI

LAB_NONM
    jsr   LAB_GTBY          ; get byte parameter
    pha                     ; push GOTO/GOSUB token
    cmp   #token_GOSUB         ; compare with GOSUB token
    beq   LAB_176B          ; branch if GOSUB

    cmp   #token_GOTO          ; compare with GOTO token
LAB_1767
    bne   LAB_16FD          ; if not GOTO do syntax error then warm start


; next character was GOTO or GOSUB

LAB_176B
    dec   FAC1_3            ; decrement index (byte value)
    bne   LAB_1773          ; branch if not zero

    pla                     ; pull GOTO/GOSUB token
    jmp   LAB_1602          ; go execute it

LAB_1773
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_GFPN          ; get fixed-point number into temp integer (skip this n)
                              ; (we could LDX #',' and JSR LAB_SNBL+2, then we
                              ; just BNE LAB_176B for the loop. should be quicker ..
                              ; no we can't, what if we meet a colon or [EOL]?)
    cmp   #$2C              ; compare next character with ","
    beq   LAB_176B          ; loop if ","

LAB_177E
    pla                     ; else pull keyword token (run out of options)
                              ; also dump +/-1 pointer low byte and exit
LAB_177F
    rts

; takes n * 106 + 11 cycles where n is the number of digits

; get fixed-point number into temp integer

LAB_GFPN
    ldx   #$00              ; clear reg
    stx   Itempl            ; clear temporary integer low byte
LAB_1785
    stx   Itemph            ; save temporary integer high byte
    bcs   LAB_177F          ; return if carry set, end of scan, character was
                              ; not 0-9

    cpx   #$19              ; compare high byte with $19
    tay                     ; ensure Zb = 0 if the branch is taken
    bcs   LAB_1767          ; branch if >=, makes max line # 63999 because next
                              ; bit does *$0A, = 64000, compare at target will fail
                              ; and do syntax error

    sbc   #'0'-1            ; subtract "0", $2F + carry, from byte
    tay                     ; copy binary digit
    lda   Itempl            ; get temporary integer low byte
    asl                     ; *2 low byte
    rol   Itemph            ; *2 high byte
    asl                     ; *2 low byte
    rol   Itemph            ; *2 high byte, *4
    adc   Itempl            ; + low byte, *5
    sta   Itempl            ; save it
    txa                     ; get high byte copy to A
    adc   Itemph            ; + high byte, *5
    asl   Itempl            ; *2 low byte, *10d
    rol                     ; *2 high byte, *10d
    tax                     ; copy high byte back to X
    tya                     ; get binary digit back
    adc   Itempl            ; add number low byte
    sta   Itempl            ; save number low byte
    bcc   LAB_17B3          ; if no overflow to high byte get next character

    inx                     ; else increment high byte
LAB_17B3
    jsr   LAB_IGBY          ; increment and scan memory
    jmp   LAB_1785          ; loop for next character

; perform DEC

basic_DEC
    lda   #<LAB_2AFD        ; set -1 pointer low byte
      .byte $2C               ; BIT abs to skip the LDA below

; perform INC

basic_INC
    lda   #<LAB_259C        ; set 1 pointer low byte
LAB_17B5
    pha                     ; save +/-1 pointer low byte
LAB_17B7
    jsr   LAB_GVAR          ; get var address
    ldx   Dtypef            ; get data type flag, $FF=string, $00=numeric
    bmi   IncrErr           ; exit if string

    sta   Lvarpl            ; save var address low byte
    sty   Lvarph            ; save var address high byte
    jsr   LAB_UFAC          ; unpack memory (AY) into FAC1
    pla                     ; get +/-1 pointer low byte
    pha                     ; save +/-1 pointer low byte
    ldy   #>LAB_259C        ; set +/-1 pointer high byte (both the same)
    jsr   LAB_246C          ; add (AY) to FAC1
    jsr   LAB_PFAC          ; pack FAC1 into variable (Lvarpl)

    jsr   LAB_GBYT          ; scan memory
    cmp   #','              ; compare with ","
    bne   LAB_177E          ; exit if not "," (either end or error)

                              ; was "," so another INCR variable to do
    jsr   LAB_IGBY          ; increment and scan memory
    jmp   LAB_17B7          ; go do next var

IncrErr
    jmp   LAB_1ABC          ; do "Type mismatch" error then warm start

; perform LET

basic_LET
    jsr   LAB_GVAR          ; get var address
    sta   Lvarpl            ; save var address low byte
    sty   Lvarph            ; save var address high byte
    lda   #token_EQUAL         ; get = token
    jsr   LAB_SCCA          ; scan for CHR$(A), else do syntax error then warm start
    lda   Dtypef            ; get data type flag, $FF=string, $00=numeric
    pha                     ; push data type flag
    jsr   LAB_EVEX          ; evaluate expression
    pla                     ; pop data type flag
    rol                     ; set carry if type = string
; *** begin patch  result of a string compare stores string pointer to variable
;                  but should store FAC1 (true/false value)
; *** replace
;      JSR   LAB_CKTM          ; type match check, set C for string
;      BNE   LAB_17D5          ; branch if string
; *** with
    jsr   LAB_CKTM          ; type match check, keep C (expected type)
    bcs   LAB_17D5          ; branch if string
; *** end patch

    jmp   LAB_PFAC          ; pack FAC1 into variable (Lvarpl) and return

; string LET

LAB_17D5
    ldy   #$02              ; set index to pointer high byte
    lda   (des_pl),Y        ; get string pointer high byte
    cmp   Sstorh            ; compare bottom of string space high byte
    bcc   LAB_17F4          ; if less assign value and exit (was in program memory)

    bne   LAB_17E6          ; branch if >
                              ; else was equal so compare low bytes
    dey                     ; decrement index
    lda   (des_pl),Y        ; get pointer low byte
    cmp   Sstorl            ; compare bottom of string space low byte
    bcc   LAB_17F4          ; if less assign value and exit (was in program memory)

                              ; pointer was >= to bottom of string space pointer
LAB_17E6
    ldy   des_ph            ; get descriptor pointer high byte
    cpy   Svarh             ; compare start of vars high byte
    bcc   LAB_17F4          ; branch if less (descriptor is on stack)

    bne   LAB_17FB          ; branch if greater (descriptor is not on stack)

                              ; else high bytes were equal so ..
    lda   des_pl            ; get descriptor pointer low byte
    cmp   Svarl             ; compare start of vars low byte
    bcs   LAB_17FB          ; branch if >= (descriptor is not on stack)

LAB_17F4
    lda   des_pl            ; get descriptor pointer low byte
    ldy   des_ph            ; get descriptor pointer high byte
    jmp   LAB_1811          ; clean stack, copy descriptor to variable and return

                              ; make space and copy string
LAB_17FB
    ldy   #$00              ; index to length
    lda   (des_pl),Y        ; get string length
    jsr   LAB_209C          ; copy string
    lda   des_2l            ; get descriptor pointer low byte
    ldy   des_2h            ; get descriptor pointer high byte
    sta   ssptr_l           ; save descriptor pointer low byte
    sty   ssptr_h           ; save descriptor pointer high byte
    jsr   LAB_228A          ; copy string from descriptor (sdescr) to (Sutill)
    lda   #<FAC1_e          ; set descriptor pointer low byte
    ldy   #>FAC1_e          ; get descriptor pointer high byte

                              ; clean stack and assign value to string variable
LAB_1811
    sta   des_2l            ; save descriptor_2 pointer low byte
    sty   des_2h            ; save descriptor_2 pointer high byte
    jsr   LAB_22EB          ; clean descriptor stack, YA = pointer
    ldy   #$00              ; index to length
    lda   (des_2l),Y        ; get string length
    sta   (Lvarpl),Y        ; copy to let string variable
    iny                     ; index to string pointer low byte
    lda   (des_2l),Y        ; get string pointer low byte
    sta   (Lvarpl),Y        ; copy to let string variable
    iny                     ; index to string pointer high byte
    lda   (des_2l),Y        ; get string pointer high byte
    sta   (Lvarpl),Y        ; copy to let string variable
    rts

; perform GET

basic_GET
    jsr   LAB_GVAR          ; get var address
    sta   Lvarpl            ; save var address low byte
    sty   Lvarph            ; save var address high byte
    jsr   INGET             ; get input byte
    ldx   Dtypef            ; get data type flag, $FF=string, $00=numeric
    bmi   basic_GETS          ; go get string character

                              ; was numeric get
    tay                     ; copy character to Y
    jsr   LAB_1FD0          ; convert Y to byte in FAC1
    jmp   LAB_PFAC          ; pack FAC1 into variable (Lvarpl) and return

basic_GETS
    pha                     ; save character
    lda   #$01              ; string is single byte
    bcs   LAB_IsByte        ; branch if byte received

    pla                     ; string is null
LAB_IsByte
    jsr   LAB_MSSP          ; make string space A bytes long A=$AC=length,
                              ; X=$AD=Sutill=ptr low byte, Y=$AE=Sutilh=ptr high byte
    beq   LAB_NoSt          ; skip store if null string

    pla                     ; get character back
    ldy   #$00              ; clear index
    sta   (str_pl),Y        ; save byte in string (byte IS string!)
LAB_NoSt
    jsr   LAB_RTST          ; check for space on descriptor stack then put address
                              ; and length on descriptor stack and update stack pointers

    jmp   LAB_17D5          ; do string LET and return

; perform PRINT

LAB_1829
    jsr   LAB_18C6          ; print string from Sutill/Sutilh
LAB_182C
    jsr   LAB_GBYT          ; scan memory

print:
    beq   print_newline          ; if nothing following just print CR/LF
LAB_1831
    cmp   #token_TAB           ; compare with TAB( token
    beq   LAB_18A2          ; go do TAB/SPC
    cmp   #token_SPC           ; compare with SPC( token
    beq   LAB_18A2          ; go do TAB/SPC
    cmp   #','              ; compare with ","
    beq   LAB_188B          ; go do move to next TAB mark
    cmp   #';'              ; compare with ";"
    beq   LAB_18BD          ; if ";" continue with PRINT processing
    jsr   LAB_EVEX          ; evaluate expression
    bit   Dtypef            ; test data type flag, $FF=string, $00=numeric
    bmi   LAB_1829          ; branch if string
    jsr   LAB_296E          ; convert FAC1 to string
    jsr   LAB_20AE          ; print " terminated string to Sutill/Sutilh
    ldy   #$00              ; clear index

; don't check fit if terminal width byte is zero

    lda   TWidth            ; get terminal width byte
    beq   LAB_185E          ; skip check if zero

    sec                     ; set carry for subtract
    sbc   TPos              ; subtract terminal position
    sbc   (des_pl),Y        ; subtract string length
    bcs   LAB_185E          ; branch if less than terminal width

    jsr   print_newline          ; else print CR/LF
LAB_185E
    jsr   LAB_18C6          ; print string from Sutill/Sutilh
    beq   LAB_182C          ; always go continue processing line

; CR/LF return to BASIC from BASIC input handler

LAB_1866
    lda   #$00              ; clear byte
    sta   Ibuffs,X          ; null terminate input
    ldx   #<Ibuffs          ; set X to buffer start-1 low byte
    ldy   #>Ibuffs          ; set Y to buffer start-1 high byte

print_newline:
    lda   #$0D              ; load [CR]
    jsr   print_a_register          ; go print the character
    lda   #$0A              ; load [LF]
    bne   print_a_register          ; go print the character and return, branch always

LAB_188B
    lda   TPos              ; get terminal position
    cmp   Iclim             ; compare with input column limit
    bcc   LAB_1897          ; branch if less

    jsr   print_newline          ; else print CR/LF (next line)
    bne   LAB_18BD          ; continue with PRINT processing (branch always)

LAB_1897
    sec                     ; set carry for subtract
LAB_1898
    sbc   TabSiz            ; subtract TAB size
    bcs   LAB_1898          ; loop if result was +ve

    eor   #$FF              ; complement it
    adc   #$01              ; +1 (twos complement)
    bne   LAB_18B6          ; always print A spaces (result is never $00)

                              ; do TAB/SPC
LAB_18A2
    pha                     ; save token
    jsr   LAB_SGBY          ; scan and get byte parameter
    cmp   #$29              ; is next character )
    bne   LAB_1910          ; if not do syntax error then warm start

    pla                     ; get token back
    cmp   #token_TAB           ; was it TAB ?
    bne   LAB_18B7          ; if not go do SPC

                              ; calculate TAB offset
    txa                     ; copy integer value to A
    sbc   TPos              ; subtract terminal position
    bcc   LAB_18BD          ; branch if result was < 0 (can't TAB backwards)

                              ; print A spaces
LAB_18B6
    tax                     ; copy result to X
LAB_18B7
    txa                     ; set flags on size for SPC
    beq   LAB_18BD          ; branch if result was = $0, already here

                              ; print X spaces
LAB_18BA
    jsr   LAB_18E0          ; print " "
    dex                     ; decrement count
    bne   LAB_18BA          ; loop if not all done

                              ; continue with PRINT processing
LAB_18BD
    jsr   LAB_IGBY          ; increment and scan memory
    bne   LAB_1831          ; if more to print go do it

    rts

; print null terminated string from memory

print_string
    jsr   LAB_20AE          ; print " terminated string to Sutill/Sutilh

; print string from Sutill/Sutilh

LAB_18C6
    jsr   LAB_22B6          ; pop string off descriptor stack, or from top of string
                              ; space returns with A = length, X=$71=pointer low byte,
                              ; Y=$72=pointer high byte
    ldy   #$00              ; reset index
    tax                     ; copy length to X
    beq   LAB_188C          ; exit (RTS) if null string

LAB_18CD
    lda   (ut1_pl),Y        ; get next byte
    jsr   print_a_register          ; go print the character
    iny                     ; increment index
    dex                     ; decrement count
    bne   LAB_18CD          ; loop if not done yet

    rts

                              ; Print single format character
; print " "
LAB_18E0
    lda #' '
      .byte $2C               ; change next line to BIT LAB_3FA9

; print "?" character
LAB_18E3
    lda #'?'

; print character in A
; now includes the null handler
; also includes infinite line length code
; note! some routines expect this one to exit with Zb=0
print_a_register:
    cmp #' '                  ; compare with " "
    bcc LAB_18F9              ; branch if less (non printing)

                                ; else printable character
    pha                       ; save the character

; don't check fit if terminal width byte is zero

    lda   TWidth            ; get terminal width
    bne   LAB_18F0          ; branch if not zero (not infinite length)

; is "infinite line" so check TAB position

    lda   TPos              ; get position
    sbc   TabSiz            ; subtract TAB size, carry set by CMP #$20 above
    bne   LAB_18F7          ; skip reset if different

    sta   TPos              ; else reset position
    beq   LAB_18F7          ; go print character

LAB_18F0
    cmp   TPos              ; compare with terminal character position
    bne   LAB_18F7          ; branch if not at end of line

    jsr   print_newline          ; else print CR/LF
LAB_18F7
    inc   TPos              ; increment terminal position
    pla                     ; get character back
LAB_18F9
    jsr   V_OUTP            ; output byte via output vector
    cmp   #$0D              ; compare with [CR]
    bne   LAB_188A          ; branch if not [CR]

                              ; else print nullct nulls after the [CR]
    stx   TempB             ; save buffer index
    ldx   Nullct            ; get null count
    beq   LAB_1886          ; branch if no nulls

    lda   #$00              ; load [NULL]
LAB_1880
    jsr   print_a_register          ; go print the character
    dex                     ; decrement count
    bne   LAB_1880          ; loop if not all done

    lda   #$0D              ; restore the character (and set the flags)
LAB_1886
    stx   TPos              ; clear terminal position (X always = zero when we get here)
    ldx   TempB             ; restore buffer index
LAB_188A
    and   #$FF              ; set the flags
LAB_188C
    rts

; handle bad input data

LAB_1904
    lda   Imode             ; get input mode flag, $00=INPUT, $00=READ
    bpl   LAB_1913          ; branch if INPUT (go do redo)

    lda   Dlinel            ; get current DATA line low byte
    ldy   Dlineh            ; get current DATA line high byte
    sta   Clinel            ; save current line low byte
    sty   Clineh            ; save current line high byte
LAB_1910
    jmp   LAB_SNER          ; do syntax error then warm start

                              ; mode was INPUT
LAB_1913
    lda   #<LAB_REDO        ; point to redo message (low addr)
    ldy   #>LAB_REDO        ; point to redo message (high addr)
    jsr   print_string          ; print null terminated string from memory
    lda   Cpntrl            ; get continue pointer low byte
    ldy   Cpntrh            ; get continue pointer high byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    sty   Bpntrh            ; save BASIC execute pointer high byte
    rts

; perform INPUT

basic_INPUT
    cmp   #$22              ; compare next byte with open quote
    bne   LAB_1934          ; branch if no prompt string

    jsr   LAB_1BC1          ; print "..." string
    lda   #$3B              ; load A with ";"
    jsr   LAB_SCCA          ; scan for CHR$(A), else do syntax error then warm start
    jsr   LAB_18C6          ; print string from Sutill/Sutilh

                              ; done with prompt, now get data
LAB_1934
    jsr   LAB_CKRN          ; check not Direct, back here if ok
    jsr   get_input          ; print "? " and get BASIC input
    lda   #$00              ; set mode = INPUT
    cmp   Ibuffs            ; test first byte in buffer
    bne   LAB_1953          ; branch if not null input

; *** change p2: keep carry set to throw break message
;      CLC                     ; was null input so clear carry to exit program
    jmp   LAB_1647          ; go do BREAK exit

; perform READ

basic_READ
    ldx   Dptrl             ; get DATA pointer low byte
    ldy   Dptrh             ; get DATA pointer high byte
    lda   #$80              ; set mode = READ

LAB_1953
    sta   Imode             ; set input mode flag, $00=INPUT, $80=READ
    stx   Rdptrl            ; save READ pointer low byte
    sty   Rdptrh            ; save READ pointer high byte

                              ; READ or INPUT next variable from list
LAB_195B
    jsr   LAB_GVAR          ; get (var) address
    sta   Lvarpl            ; save address low byte
    sty   Lvarph            ; save address high byte
    lda   Bpntrl            ; get BASIC execute pointer low byte
    ldy   Bpntrh            ; get BASIC execute pointer high byte
    sta   Itempl            ; save as temporary integer low byte
    sty   Itemph            ; save as temporary integer high byte
    ldx   Rdptrl            ; get READ pointer low byte
    ldy   Rdptrh            ; get READ pointer high byte
    stx   Bpntrl            ; set BASIC execute pointer low byte
    sty   Bpntrh            ; set BASIC execute pointer high byte
    jsr   LAB_GBYT          ; scan memory
    bne   LAB_1988          ; branch if not null

                              ; pointer was to null entry
    bit   Imode             ; test input mode flag, $00=INPUT, $80=READ
    bmi   LAB_19DD          ; branch if READ

                              ; mode was INPUT
    jsr   LAB_18E3          ; print "?" character (double ? for extended input)
    jsr   get_input          ; print "? " and get BASIC input
    stx   Bpntrl            ; set BASIC execute pointer low byte
    sty   Bpntrh            ; set BASIC execute pointer high byte
LAB_1985
    jsr   LAB_GBYT          ; scan memory
LAB_1988
    bit   Dtypef            ; test data type flag, $FF=string, $00=numeric
    bpl   LAB_19B0          ; branch if numeric

                              ; else get string
    sta   Srchc             ; save search character
    cmp   #$22              ; was it " ?
    beq   LAB_1999          ; branch if so

    lda   #':'              ; else search character is ":"
    sta   Srchc             ; set new search character
    lda   #','              ; other search character is ","
    clc                     ; clear carry for add
LAB_1999
    sta   Asrch             ; set second search character
    lda   Bpntrl            ; get BASIC execute pointer low byte
    ldy   Bpntrh            ; get BASIC execute pointer high byte

    adc   #$00              ; c is =1 if we came via the BEQ LAB_1999, else =0
    bcc   LAB_19A4          ; branch if no execute pointer low byte rollover

    iny                     ; else increment high byte
LAB_19A4
    jsr   LAB_20B4          ; print Srchc or Asrch terminated string to Sutill/Sutilh
    jsr   LAB_23F3          ; restore BASIC execute pointer from temp (Btmpl/Btmph)
    jsr   LAB_17D5          ; go do string LET
    jmp   LAB_19B6          ; go check string terminator

                              ; get numeric INPUT
LAB_19B0
    jsr   LAB_2887          ; get FAC1 from string
    jsr   LAB_PFAC          ; pack FAC1 into (Lvarpl)
LAB_19B6
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_19C5          ; branch if null (last entry)

    cmp   #','              ; else compare with ","
    beq   LAB_19C2          ; branch if ","

    jmp   LAB_1904          ; else go handle bad input data

                              ; got good input data
LAB_19C2
    jsr   LAB_IGBY          ; increment and scan memory
LAB_19C5
    lda   Bpntrl            ; get BASIC execute pointer low byte (temp READ/INPUT ptr)
    ldy   Bpntrh            ; get BASIC execute pointer high byte (temp READ/INPUT ptr)
    sta   Rdptrl            ; save for now
    sty   Rdptrh            ; save for now
    lda   Itempl            ; get temporary integer low byte (temp BASIC execute ptr)
    ldy   Itemph            ; get temporary integer high byte (temp BASIC execute ptr)
    sta   Bpntrl            ; set BASIC execute pointer low byte
    sty   Bpntrh            ; set BASIC execute pointer high byte
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_1A03          ; if null go do extra ignored message

    jsr   LAB_1C01          ; else scan for "," , else do syntax error then warm start
    jmp   LAB_195B          ; go INPUT next variable from list

                              ; find next DATA statement or do "Out of DATA" error
LAB_19DD
    jsr   LAB_SNBS          ; scan for next BASIC statement ([:] or [EOL])
    iny                     ; increment index
    tax                     ; copy character ([:] or [EOL])
    bne   LAB_19F6          ; branch if [:]

    ldx   #$06              ; set for "Out of DATA" error
    iny                     ; increment index, now points to next line pointer high byte
    lda   (Bpntrl),Y        ; get next line pointer high byte
    beq   LAB_1A54          ; branch if end (eventually does error X)

    iny                     ; increment index
    lda   (Bpntrl),Y        ; get next line # low byte
    sta   Dlinel            ; save current DATA line low byte
    iny                     ; increment index
    lda   (Bpntrl),Y        ; get next line # high byte
    iny                     ; increment index
    sta   Dlineh            ; save current DATA line high byte
LAB_19F6
    lda   (Bpntrl),Y        ; get byte
    iny                     ; increment index
    tax                     ; copy to X
    jsr   LAB_170F          ; set BASIC execute pointer
    cpx   #token_DATA          ; compare with "DATA" token
    beq   LAB_1985          ; was "DATA" so go do next READ

    bne   LAB_19DD          ; go find next statement if not "DATA"

; end of INPUT/READ routine

LAB_1A03
    lda   Rdptrl            ; get temp READ pointer low byte
    ldy   Rdptrh            ; get temp READ pointer high byte
    ldx   Imode             ; get input mode flag, $00=INPUT, $80=READ
    bpl   LAB_1A0E          ; branch if INPUT

    jmp   LAB_1624          ; save AY as DATA pointer and return

                              ; we were getting INPUT
LAB_1A0E
    ldy   #$00              ; clear index
    lda   (Rdptrl),Y        ; get next byte
    bne   LAB_1A1B          ; error if not end of INPUT

    rts

                              ; user typed too much
LAB_1A1B
    lda   #<LAB_IMSG        ; point to extra ignored message (low addr)
    ldy   #>LAB_IMSG        ; point to extra ignored message (high addr)
    jmp   print_string          ; print null terminated string from memory and return

; search the stack for FOR activity
; exit with z=1 if FOR else exit with z=0

LAB_11A1
    tsx                     ; copy stack pointer
    inx                     ; +1 pass return address
    inx                     ; +2 pass return address
    inx                     ; +3 pass calling routine return address
    inx                     ; +4 pass calling routine return address
LAB_11A6
    lda   LAB_STAK+1,X      ; get token byte from stack
    cmp   #token_FOR           ; is it FOR token
    bne   LAB_11CE          ; exit if not FOR token

                              ; was FOR token
    lda   Frnxth            ; get var pointer for FOR/NEXT high byte
    bne   LAB_11BB          ; branch if not null

    lda   LAB_STAK+2,X      ; get FOR variable pointer low byte
    sta   Frnxtl            ; save var pointer for FOR/NEXT low byte
    lda   LAB_STAK+3,X      ; get FOR variable pointer high byte
    sta   Frnxth            ; save var pointer for FOR/NEXT high byte
LAB_11BB
    cmp   LAB_STAK+3,X      ; compare var pointer with stacked var pointer (high byte)
    bne   LAB_11C7          ; branch if no match

    lda   Frnxtl            ; get var pointer for FOR/NEXT low byte
    cmp   LAB_STAK+2,X      ; compare var pointer with stacked var pointer (low byte)
    beq   LAB_11CE          ; exit if match found

LAB_11C7
    txa                     ; copy index
    clc                     ; clear carry for add
    adc   #$10              ; add FOR stack use size
    tax                     ; copy back to index
    bne   LAB_11A6          ; loop if not at start of stack

LAB_11CE
    rts

; perform NEXT

basic_NEXT
    bne   LAB_1A46          ; branch if NEXT var

    ldy   #$00              ; else clear Y
    beq   LAB_1A49          ; branch always (no variable to search for)

; NEXT var

LAB_1A46
    jsr   LAB_GVAR          ; get variable address
LAB_1A49
    sta   Frnxtl            ; store variable pointer low byte
    sty   Frnxth            ; store variable pointer high byte
                              ; (both cleared if no variable defined)
    jsr   LAB_11A1          ; search the stack for FOR activity
    beq   LAB_1A56          ; branch if found

    ldx   #$00              ; else set error $00 ("NEXT without FOR" error)
LAB_1A54
    beq   LAB_1ABE          ; do error #X, then warm start

LAB_1A56
    txs                     ; set stack pointer, X set by search, dumps return addresses

    txa                     ; copy stack pointer
    sec                     ; set carry for subtract
    sbc   #$F7              ; point to TO var
    sta   ut2_pl            ; save pointer to TO var for compare
    adc   #$FB              ; point to STEP var

    ldy   #>LAB_STAK        ; point to stack page high byte
    jsr   LAB_UFAC          ; unpack memory (STEP value) into FAC1
    tsx                     ; get stack pointer back
    lda   LAB_STAK+8,X      ; get step sign
    sta   FAC1_s            ; save FAC1 sign (b7)
    lda   Frnxtl            ; get FOR variable pointer low byte
    ldy   Frnxth            ; get FOR variable pointer high byte
    jsr   LAB_246C          ; add (FOR variable) to FAC1
    jsr   LAB_PFAC          ; pack FAC1 into (FOR variable)
    ldy   #>LAB_STAK        ; point to stack page high byte
    jsr   LAB_27FA          ; compare FAC1 with (Y,ut2_pl) (TO value)
    tsx                     ; get stack pointer back
    cmp   LAB_STAK+8,X      ; compare step sign
    beq   LAB_1A9B          ; branch if = (loop complete)

                              ; loop back and do it all again
    lda   LAB_STAK+$0D,X    ; get FOR line low byte
    sta   Clinel            ; save current line low byte
    lda   LAB_STAK+$0E,X    ; get FOR line high byte
    sta   Clineh            ; save current line high byte
    lda   LAB_STAK+$10,X    ; get BASIC execute pointer low byte
    sta   Bpntrl            ; save BASIC execute pointer low byte
    lda   LAB_STAK+$0F,X    ; get BASIC execute pointer high byte
    sta   Bpntrh            ; save BASIC execute pointer high byte
LAB_1A98
    jmp   LAB_15C2          ; go do interpreter inner loop

                              ; loop complete so carry on
LAB_1A9B
    txa                     ; stack copy to A
    adc   #$0F              ; add $10 ($0F+carry) to dump FOR structure
    tax                     ; copy back to index
    txs                     ; copy to stack pointer
    jsr   LAB_GBYT          ; scan memory
    cmp   #','              ; compare with ","
    bne   LAB_1A98          ; branch if not "," (go do interpreter inner loop)

                              ; was "," so another NEXT variable to do
    jsr   LAB_IGBY          ; else increment and scan memory
    jsr   LAB_1A46          ; do NEXT (var)

; evaluate expression and check is numeric, else do type mismatch
LAB_EVNM
    jsr   LAB_EVEX          ; evaluate expression

; check if source is numeric, else do type mismatch
LAB_CTNM
    clc                     ; destination is numeric
      .byte $24               ; makes next line BIT $38

; check if source is string, else do type mismatch
LAB_CTST
    sec                     ; required type is string

; type match check, set C for string, clear C for numeric
LAB_CKTM
    bit   Dtypef            ; test data type flag, $FF=string, $00=numeric
    bmi   LAB_1ABA          ; branch if data type is string
                              ; else data type was numeric
    bcs   LAB_1ABC          ; if required type is string do type mismatch error
LAB_1AB9
    rts
                              ; data type was string, now check required type
LAB_1ABA
    bcs   LAB_1AB9          ; exit if required type is string
                              ; else do type mismatch error
LAB_1ABC
    ldx   #$18              ; error code $18 ("Type mismatch" error)
LAB_1ABE
    jmp   LAB_XERR          ; do error #X, then warm start

; evaluate expression

LAB_EVEX
    ldx   Bpntrl            ; get BASIC execute pointer low byte
    bne   LAB_1AC7          ; skip next if not zero

    dec   Bpntrh            ; else decrement BASIC execute pointer high byte
LAB_1AC7
    dec   Bpntrl            ; decrement BASIC execute pointer low byte

LAB_EVEZ
    lda   #$00              ; set null precedence (flag done)
LAB_1ACC
    pha                     ; push precedence byte
    lda   #$02              ; 2 bytes
    jsr   LAB_1212          ; check room on stack for A bytes
    jsr   LAB_GVAL          ; get value from line
    lda   #$00              ; clear A
    sta   comp_f            ; clear compare function flag
LAB_1ADB
    jsr   LAB_GBYT          ; scan memory
LAB_1ADE
    sec                     ; set carry for subtract
    sbc   #token_GT            ; subtract token for > (lowest comparison function)
    bcc   LAB_1AFA          ; branch if < token_GT

    cmp   #$03              ; compare with ">" to "<" tokens
    bcs   LAB_1AFA          ; branch if >= token_SGN (highest evaluation function +1)

                              ; was token for > = or < (A = 0, 1 or 2)
    cmp   #$01              ; compare with token for =
    rol                     ; *2, b0 = carry (=1 if token was = or <)
                              ; (A = 0, 3 or 5)
    eor   #$01              ; toggle b0
                              ; (A = 1, 2 or 4. 1 if >, 2 if =, 4 if <)
    eor   comp_f            ; EOR with compare function flag bits
    cmp   comp_f            ; compare with compare function flag
    bcc   LAB_1B53          ; if <(comp_f) do syntax error then warm start
                              ; was more than one <, = or >)

    sta   comp_f            ; save new compare function flag
    jsr   LAB_IGBY          ; increment and scan memory
    jmp   LAB_1ADE          ; go do next character

                              ; token is < ">" or > "<" tokens
LAB_1AFA
    ldx   comp_f            ; get compare function flag
    bne   LAB_1B2A          ; branch if compare function

    bcs   LAB_1B78          ; go do functions

                              ; else was <  token_GT so is operator or lower
    adc   #token_GT-token_PLUS    ; add # of operators (+, -, *, /, ^, AND, OR or EOR)
    bcc   LAB_1B78          ; branch if < + operator

                              ; carry was set so token was +, -, *, /, ^, AND, OR or EOR
    bne   LAB_1B0B          ; branch if not + token

    bit   Dtypef            ; test data type flag, $FF=string, $00=numeric
    bpl   LAB_1B0B          ; branch if not string

                              ; will only be $00 if type is string and token was +
    jmp   LAB_224D          ; add strings, string 1 is in descriptor des_pl, string 2
                              ; is in line, and return

LAB_1B0B
    sta   ut1_pl            ; save it
    asl                     ; *2
    adc   ut1_pl            ; *3
    tay                     ; copy to index
LAB_1B13
    pla                     ; pull previous precedence
    cmp   LAB_OPPT,Y        ; compare with precedence byte
    bcs   LAB_1B7D          ; branch if A >=

    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
LAB_1B1C
    pha                     ; save precedence
LAB_1B1D
    jsr   LAB_1B43          ; get vector, execute function then continue evaluation
    pla                     ; restore precedence
    ldy   prstk             ; get precedence stacked flag
    bpl   LAB_1B3C          ; branch if stacked values

    tax                     ; copy precedence (set flags)
    beq   LAB_1B9D          ; exit if done

    bne   LAB_1B86          ; else pop FAC2 and return, branch always

LAB_1B2A
    rol   Dtypef            ; shift data type flag into Cb
    txa                     ; copy compare function flag
    sta   Dtypef            ; clear data type flag, X is 0xxx xxxx
    rol                     ; shift data type into compare function byte b0
    ldx   Bpntrl            ; get BASIC execute pointer low byte
    bne   LAB_1B34          ; branch if no underflow

    dec   Bpntrh            ; else decrement BASIC execute pointer high byte
LAB_1B34
    dec   Bpntrl            ; decrement BASIC execute pointer low byte
token_LT_PLUS  = token_LT-token_PLUS
    ldy   #token_LT_PLUS*3     ; set offset to last operator entry
    sta   comp_f            ; save new compare function flag
    bne   LAB_1B13          ; branch always

LAB_1B3C
    cmp   LAB_OPPT,Y        ;.compare with stacked function precedence
    bcs   LAB_1B86          ; branch if A >=, pop FAC2 and return

    bcc   LAB_1B1C          ; branch always

;.get vector, execute function then continue evaluation

LAB_1B43
    lda   LAB_OPPT+2,Y      ; get function vector high byte
    pha                     ; onto stack
    lda   LAB_OPPT+1,Y      ; get function vector low byte
    pha                     ; onto stack
                              ; now push sign, round FAC1 and put on stack
; *** begin patch  2.22p5.3   potential return address -$100 (page not incremented) ***
; *** add
;   .IF [* & $FF] == $FD
;      NOP                     ; return address of JSR +1 (on  next page)
;   .ENDIF
; *** end   patch  2.22p5.3   potential return address -$100 (page not incremented) ***
    jsr   LAB_1B5B          ; function will return here, then the next RTS will call
                              ; the function
    lda   comp_f            ; get compare function flag
    pha                     ; push compare evaluation byte
    lda   LAB_OPPT,Y        ; get precedence byte
    jmp   LAB_1ACC          ; continue evaluating expression

LAB_1B53
    jmp   LAB_SNER          ; do syntax error then warm start

; push sign, round FAC1 and put on stack
LAB_1B5B
    pla                     ; get return addr low byte
    sta   ut1_pl            ; save it
    inc   ut1_pl            ; increment it (was ret-1 pushed? yes!)
                              ; note! no check is made on the high byte! if the calling
                              ; routine assembles to a page edge then this all goes
                              ; horribly wrong !!!
    pla                     ; get return addr high byte
    sta   ut1_ph            ; save it
    lda   FAC1_s            ; get FAC1 sign (b7)
    pha                     ; push sign

; round FAC1 and put on stack

; *** begin patch  2.22p5.1   TO expression may get sign bit flipped
; *** replace
;LAB_1B66
;      JSR   LAB_27BA          ; round FAC1
; *** with
    jsr   LAB_27BA          ; round FAC1
LAB_1B66
; *** end   patch  2.22p5.1   TO expression may get sign bit flipped
    lda   FAC1_3            ; get FAC1 mantissa3
    pha                     ; push on stack
    lda   FAC1_2            ; get FAC1 mantissa2
    pha                     ; push on stack
    lda   FAC1_1            ; get FAC1 mantissa1
    pha                     ; push on stack
    lda   FAC1_e            ; get FAC1 exponent
    pha                     ; push on stack
    jmp   (ut1_pl)          ; return, sort of

; do functions

LAB_1B78
    ldy   #$FF              ; flag function
    pla                     ; pull precedence byte
LAB_1B7B
    beq   LAB_1B9D          ; exit if done

LAB_1B7D
    cmp   #$64              ; compare previous precedence with $64
    beq   LAB_1B84          ; branch if was $64 (< function)

    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
LAB_1B84
    sty   prstk             ; save precedence stacked flag

                              ; pop FAC2 and return
LAB_1B86
    pla                     ; pop byte
    lsr                     ; shift out comparison evaluation lowest bit
    sta   Cflag             ; save comparison evaluation flag
    pla                     ; pop exponent
    sta   FAC2_e            ; save FAC2 exponent
    pla                     ; pop mantissa1
    sta   FAC2_1            ; save FAC2 mantissa1
    pla                     ; pop mantissa2
    sta   FAC2_2            ; save FAC2 mantissa2
    pla                     ; pop mantissa3
    sta   FAC2_3            ; save FAC2 mantissa3
    pla                     ; pop sign
    sta   FAC2_s            ; save FAC2 sign (b7)
    eor   FAC1_s            ; EOR FAC1 sign (b7)
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
LAB_1B9D
    lda   FAC1_e            ; get FAC1 exponent
    rts

; print "..." string to string util area

LAB_1BC1
    lda   Bpntrl            ; get BASIC execute pointer low byte
    ldy   Bpntrh            ; get BASIC execute pointer high byte
    adc   #$00              ; add carry to low byte
    bcc   LAB_1BCA          ; branch if no overflow

    iny                     ; increment high byte
LAB_1BCA
    jsr   LAB_20AE          ; print " terminated string to Sutill/Sutilh
    jmp   LAB_23F3          ; restore BASIC execute pointer from temp and return

; get value from line

LAB_GVAL
    jsr   LAB_IGBY          ; increment and scan memory
    bcs   LAB_1BAC          ; branch if not numeric character

                              ; else numeric string found (e.g. 123)
LAB_1BA9
    jmp   LAB_2887          ; get FAC1 from string and return

; get value from line .. continued

                              ; wasn't a number so ..
LAB_1BAC
    tax                     ; set the flags
    bmi   LAB_1BD0          ; if -ve go test token values

                              ; else it is either a string, number, variable or (<expr>)
    cmp   #'$'              ; compare with "$"
    beq   LAB_1BA9          ; branch if "$", hex number

    cmp   #'%'              ; else compare with "%"
    beq   LAB_1BA9          ; branch if "%", binary number

    cmp   #'.'              ; compare with "."
    beq   LAB_1BA9          ; if so get FAC1 from string and return (e.g. was .123)

                              ; it wasn't any sort of number so ..
    cmp   #$22              ; compare with "
    beq   LAB_1BC1          ; branch if open quote

                              ; wasn't any sort of number so ..

; evaluate expression within parentheses

    cmp   #'('              ; compare with "("
    bne   LAB_1C18          ; if not "(" get (var), return value in FAC1 and $ flag

LAB_1BF7
    jsr   LAB_EVEZ          ; evaluate expression, no decrement

; all the 'scan for' routines return the character after the sought character

; scan for ")" , else do syntax error then warm start

LAB_1BFB
    lda   #$29              ; load A with ")"

; scan for CHR$(A) , else do syntax error then warm start

LAB_SCCA
    ldy   #$00              ; clear index
    cmp   (Bpntrl),Y        ; check next byte is = A
    bne   LAB_SNER          ; if not do syntax error then warm start

    jmp   LAB_IGBY          ; increment and scan memory then return

; scan for "(" , else do syntax error then warm start

LAB_1BFE
    lda   #$28              ; load A with "("
    bne   LAB_SCCA          ; scan for CHR$(A), else do syntax error then warm start
                              ; (branch always)

; scan for "," , else do syntax error then warm start

LAB_1C01
    lda   #$2C              ; load A with ","
    bne   LAB_SCCA          ; scan for CHR$(A), else do syntax error then warm start
                              ; (branch always)

; syntax error then warm start

LAB_SNER
    ldx   #$02              ; error code $02 ("Syntax" error)
    jmp   LAB_XERR          ; do error #X, then warm start

; get value from line .. continued
; do tokens

LAB_1BD0
    cmp   #token_MINUS         ; compare with token for -
    beq   LAB_1C11          ; branch if - token (do set-up for functions)

                              ; wasn't -n so ..
    cmp   #token_PLUS          ; compare with token for +
    beq   LAB_GVAL          ; branch if + token (+n = n so ignore leading +)

    cmp   #token_NOT           ; compare with token for NOT
    bne   LAB_1BE7          ; branch if not token for NOT

                              ; was NOT token
token_EQUAL_PLUS     = token_EQUAL-token_PLUS
    ldy   #token_EQUAL_PLUS*3  ; offset to NOT function
    bne   LAB_1C13          ; do set-up for function then execute (branch always)

; do = compare

LAB_EQUAL
    jsr   LAB_EVIR          ; evaluate integer expression (no sign check)
    lda   FAC1_3            ; get FAC1 mantissa3
    eor   #$FF              ; invert it
    tay                     ; copy it
    lda   FAC1_2            ; get FAC1 mantissa2
    eor   #$FF              ; invert it
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; get value from line .. continued

                              ; wasn't +, -, or NOT so ..
LAB_1BE7
    cmp   #token_FN            ; compare with token for FN
    bne   LAB_1BEE          ; branch if not token for FN

    jmp   LAB_201E          ; go evaluate FNx

; get value from line .. continued

                              ; wasn't +, -, NOT or FN so ..
LAB_1BEE
    sbc   #token_SGN           ; subtract with token for SGN
    bcs   LAB_1C27          ; if a function token go do it

    jmp   LAB_SNER          ; else do syntax error

; set-up for functions

LAB_1C11
token_GT_PLUS  = token_GT-token_PLUS
    ldy   #token_GT_PLUS*3     ; set offset from base to > operator
LAB_1C13
    pla                     ; dump return address low byte
; *** begin patch  2.22p5.4  concatenate MINUS or NOT() crashes EhBASIC  ***
; *** replace
;      PLA                     ; dump return address high byte
;      JMP   LAB_1B1D          ; execute function then continue evaluation
; *** with
    tax                     ; save to trap concatenate
    pla                     ; dump return address high byte
    cpx   #<(LAB_224Da+2)   ; from concatenate low return address?
    bne   LAB_1C13b         ; No - continue!
    cmp   #>(LAB_224Da+2)   ; from concatenate high return address?
    beq   LAB_1C13a         ; Yes - error!
LAB_1C13b
    jmp   LAB_1B1D          ; execute function then continue evaluation
LAB_1C13a
    jmp   LAB_1ABC          ; throw "type mismatch error" then warm start
; *** end   patch  2.22p5.4  concatenate MINUS or NOT() crashes EhBASIC  ***

; variable name set-up
; get (var), return value in FAC_1 and $ flag
LAB_1C18
    jsr   LAB_GVAR          ; get (var) address
    sta   FAC1_2            ; save address low byte in FAC1 mantissa2
    sty   FAC1_3            ; save address high byte in FAC1 mantissa3
    ldx   Dtypef            ; get data type flag, $FF=string, $00=numeric
    bmi   LAB_1C25          ; if string then return (does RTS)

LAB_1C24
    jmp   LAB_UFAC          ; unpack memory (AY) into FAC1

LAB_1C25
; *** begin patch  string pointer high byte trashed when moved to stack
; *** add
    lsr   FAC1_r            ; clear bit 7 (<$80) = do not round up
; *** end patch
    rts

; get value from line .. continued
; only functions left so ..

; set up function references

; new for V2.0+ this replaces a lot of IF .. THEN .. ELSEIF .. THEN .. that was needed
; to process function calls. now the function vector is computed and pushed on the stack
; and the preprocess offset is read. if the preprocess offset is non zero then the vector
; is calculated and the routine called, if not this routine just does RTS. whichever
; happens the RTS at the end of this routine, or the end of the preprocess routine, calls
; the function code

; this also removes some less than elegant code that was used to bypass type checking
; for functions that returned strings

LAB_1C27
    asl                     ; *2 (2 bytes per function address)
    tay                     ; copy to index

    lda   LAB_FTBM,Y        ; get function jump vector high byte
    pha                     ; push functions jump vector high byte
    lda   LAB_FTBL,Y        ; get function jump vector low byte
    pha                     ; push functions jump vector low byte

    lda   LAB_FTPM,Y        ; get function pre process vector high byte
    beq   LAB_1C56          ; skip pre process if null vector

    pha                     ; push functions pre process vector high byte
    lda   LAB_FTPL,Y        ; get function pre process vector low byte
    pha                     ; push functions pre process vector low byte

LAB_1C56
    rts                     ; do function, or pre process, call

; process string expression in parenthesis

LAB_PPFS
    jsr   LAB_1BF7          ; process expression in parenthesis
    jmp   LAB_CTST          ; check if source is string then do function,
                              ; else do type mismatch

; process numeric expression in parenthesis

LAB_PPFN
    jsr   LAB_1BF7          ; process expression in parenthesis
    jmp   LAB_CTNM          ; check if source is numeric then do function,
                              ; else do type mismatch

; set numeric data type and increment BASIC execute pointer
LAB_PPBI
    lsr   Dtypef            ; clear data type flag, $FF=string, $00=numeric
    jmp   LAB_IGBY          ; increment and scan memory then do function

; process string for LEFT$, RIGHT$ or MID$
LAB_LRMS
    jsr   LAB_EVEZ          ; evaluate (should be string) expression
    jsr   LAB_1C01          ; scan for ",", else do syntax error then warm start
    jsr   LAB_CTST          ; check if source is string, else do type mismatch

    pla                     ; get function jump vector low byte
    tax                     ; save functions jump vector low byte
    pla                     ; get function jump vector high byte
    tay                     ; save functions jump vector high byte
    lda   des_ph            ; get descriptor pointer high byte
    pha                     ; push string pointer high byte
    lda   des_pl            ; get descriptor pointer low byte
    pha                     ; push string pointer low byte
    tya                     ; get function jump vector high byte back
    pha                     ; save functions jump vector high byte
    txa                     ; get function jump vector low byte back
    pha                     ; save functions jump vector low byte
    jsr   LAB_GTBY          ; get byte parameter
    txa                     ; copy byte parameter to A
    rts                     ; go do function

; process numeric expression(s) for BIN$ or HEX$
LAB_BHSS
    jsr   LAB_EVEZ          ; process expression
    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$98              ; compare with exponent = 2^24
    bcs   LAB_BHER          ; branch if n>=2^24 (is too big)

    jsr   LAB_2831          ; convert FAC1 floating-to-fixed
    ldx   #$02              ; 3 bytes to do
LAB_CFAC
    lda   FAC1_1,X          ; get byte from FAC1
    sta   nums_1,X          ; save byte to temp
    dex                     ; decrement index
    bpl   LAB_CFAC          ; copy FAC1 mantissa to temp

    jsr   LAB_GBYT          ; get next BASIC byte
    ldx   #$00              ; set default to no leading "0"s
    cmp   #')'              ; compare with close bracket
    beq   LAB_1C54          ; if ")" go do rest of function

    jsr   LAB_SCGB          ; scan for "," and get byte
    jsr   LAB_GBYT          ; get last byte back
    cmp   #')'              ; is next character )
    bne   LAB_BHER          ; if not ")" go do error

LAB_1C54
    rts                     ; else do function

LAB_BHER
    jmp   LAB_FCER          ; do function call error then warm start

; perform EOR

; added operator format is the same as AND or OR, precedence is the same as OR

; this bit worked first time but it took a while to sort out the operator table
; pointers and offsets afterwards!

LAB_EOR
    jsr   GetFirst          ; get first integer expression (no sign check)
    eor   XOAw_l            ; EOR with expression 1 low byte
    tay                     ; save in Y
    lda   FAC1_2            ; get FAC1 mantissa2
    eor   XOAw_h            ; EOR with expression 1 high byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform OR

LAB_OR
    jsr   GetFirst          ; get first integer expression (no sign check)
    ora   XOAw_l            ; OR with expression 1 low byte
    tay                     ; save in Y
    lda   FAC1_2            ; get FAC1 mantissa2
    ora   XOAw_h            ; OR with expression 1 high byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform AND

LAB_AND
    jsr   GetFirst          ; get first integer expression (no sign check)
    and   XOAw_l            ; AND with expression 1 low byte
    tay                     ; save in Y
    lda   FAC1_2            ; get FAC1 mantissa2
    and   XOAw_h            ; AND with expression 1 high byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; get first value for OR, AND or EOR

GetFirst
    jsr   LAB_EVIR          ; evaluate integer expression (no sign check)
    lda   FAC1_2            ; get FAC1 mantissa2
    sta   XOAw_h            ; save it
    lda   FAC1_3            ; get FAC1 mantissa3
    sta   XOAw_l            ; save it
    jsr   LAB_279B          ; copy FAC2 to FAC1 (get 2nd value in expression)
    jsr   LAB_EVIR          ; evaluate integer expression (no sign check)
    lda   FAC1_3            ; get FAC1 mantissa3
LAB_1C95
    rts

; perform comparisons

; do < compare

LAB_LTHAN
    jsr   LAB_CKTM          ; type match check, set C for string
    bcs   LAB_1CAE          ; branch if string

                              ; do numeric < compare
    lda   FAC2_s            ; get FAC2 sign (b7)
    ora   #$7F              ; set all non sign bits
    and   FAC2_1            ; and FAC2 mantissa1 (AND in sign bit)
    sta   FAC2_1            ; save FAC2 mantissa1
    lda   #<FAC2_e          ; set pointer low byte to FAC2
    ldy   #>FAC2_e          ; set pointer high byte to FAC2
    jsr   LAB_27F8          ; compare FAC1 with FAC2 (AY)
    tax                     ; copy result
    jmp   LAB_1CE1          ; go evaluate result

                              ; do string < compare
LAB_1CAE
    lsr   Dtypef            ; clear data type flag, $FF=string, $00=numeric
    dec   comp_f            ; clear < bit in compare function flag
    jsr   LAB_22B6          ; pop string off descriptor stack, or from top of string
                              ; space returns with A = length, X=pointer low byte,
                              ; Y=pointer high byte
    sta   str_ln            ; save length
    stx   str_pl            ; save string pointer low byte
    sty   str_ph            ; save string pointer high byte
    lda   FAC2_2            ; get descriptor pointer low byte
    ldy   FAC2_3            ; get descriptor pointer high byte
    jsr   LAB_22BA          ; pop (YA) descriptor off stack or from top of string space
                              ; returns with A = length, X=pointer low byte,
                              ; Y=pointer high byte
    stx   FAC2_2            ; save string pointer low byte
    sty   FAC2_3            ; save string pointer high byte
    tax                     ; copy length
    sec                     ; set carry for subtract
    sbc   str_ln            ; subtract string 1 length
    beq   LAB_1CD6          ; branch if str 1 length = string 2 length

    lda   #$01              ; set str 1 length > string 2 length
    bcc   LAB_1CD6          ; branch if so

    ldx   str_ln            ; get string 1 length
    lda   #$FF              ; set str 1 length < string 2 length
LAB_1CD6
    sta   FAC1_s            ; save length compare
    ldy   #$FF              ; set index
    inx                     ; adjust for loop
LAB_1CDB
    iny                     ; increment index
    dex                     ; decrement count
    bne   LAB_1CE6          ; branch if still bytes to do

    ldx   FAC1_s            ; get length compare back
LAB_1CE1
    bmi   LAB_1CF2          ; branch if str 1 < str 2

    clc                     ; flag str 1 <= str 2
    bcc   LAB_1CF2          ; go evaluate result

LAB_1CE6
    lda   (FAC2_2),Y        ; get string 2 byte
    cmp   (FAC1_1),Y        ; compare with string 1 byte
    beq   LAB_1CDB          ; loop if bytes =

    ldx   #$FF              ; set str 1 < string 2
    bcs   LAB_1CF2          ; branch if so

    ldx   #$01              ;  set str 1 > string 2
LAB_1CF2
    inx                     ; x = 0, 1 or 2
    txa                     ; copy to A
    rol                     ; *2 (1, 2 or 4)
    and   Cflag             ; AND with comparison evaluation flag
    beq   LAB_1CFB          ; branch if 0 (compare is false)

    lda   #$FF              ; else set result true
LAB_1CFB
    jmp   LAB_27DB          ; save A as integer byte and return

LAB_1CFE
    jsr   LAB_1C01          ; scan for ",", else do syntax error then warm start

; perform DIM

basic_DIM
    tax                     ; copy "DIM" flag to X
    jsr   LAB_1D10          ; search for variable
    jsr   LAB_GBYT          ; scan memory
    bne   LAB_1CFE          ; scan for "," and loop if not null

    rts

; perform << (left shift)

LAB_LSHIFT
    jsr   GetPair           ; get integer expression and byte (no sign check)
    lda   FAC1_2            ; get expression high byte
    ldx   TempB             ; get shift count
    beq   NoShift           ; branch if zero

    cpx   #$10              ; compare bit count with 16d
    bcs   TooBig            ; branch if >=

Ls_loop
    asl   FAC1_3            ; shift low byte
    rol                     ; shift high byte
    dex                     ; decrement bit count
    bne   Ls_loop           ; loop if shift not complete

    ldy   FAC1_3            ; get expression low byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform >> (right shift)

LAB_RSHIFT
    jsr   GetPair           ; get integer expression and byte (no sign check)
    lda   FAC1_2            ; get expression high byte
    ldx   TempB             ; get shift count
    beq   NoShift           ; branch if zero

    cpx   #$10              ; compare bit count with 16d
    bcs   TooBig            ; branch if >=

Rs_loop
    lsr                     ; shift high byte
    ror   FAC1_3            ; shift low byte
    dex                     ; decrement bit count
    bne   Rs_loop           ; loop if shift not complete

NoShift
    ldy   FAC1_3            ; get expression low byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

TooBig
    lda   #$00              ; clear high byte
    tay                     ; copy to low byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

GetPair
    jsr   LAB_EVBY          ; evaluate byte expression, result in X
    stx   TempB             ; save it
    jsr   LAB_279B          ; copy FAC2 to FAC1 (get 2nd value in expression)
    jmp   LAB_EVIR          ; evaluate integer expression (no sign check)

; search for variable
; return pointer to variable in Cvaral/Cvarah
LAB_GVAR
    ldx   #$00              ; set DIM flag = $00
    jsr   LAB_GBYT          ; scan memory (1st character)
LAB_1D10
    stx   Defdim            ; save DIM flag
LAB_1D12
    sta   Varnm1            ; save 1st character
    and   #$7F              ; clear FN flag bit
    jsr   LAB_CASC          ; check byte, return C=0 if<"A" or >"Z"
    bcs   LAB_1D1F          ; branch if ok

    jmp   LAB_SNER          ; else syntax error then warm start

                              ; was variable name so ..
LAB_1D1F
    ldx   #$00              ; clear 2nd character temp
    stx   Dtypef            ; clear data type flag, $FF=string, $00=numeric
    jsr   LAB_IGBY          ; increment and scan memory (2nd character)
    bcc   LAB_1D2D          ; branch if character = "0"-"9" (ok)

                              ; 2nd character wasn't "0" to "9" so ..
    jsr   LAB_CASC          ; check byte, return C=0 if<"A" or >"Z"
    bcc   LAB_1D38          ; branch if <"A" or >"Z" (go check if string)

LAB_1D2D
    tax                     ; copy 2nd character

                              ; ignore further (valid) characters in the variable name
LAB_1D2E
    jsr   LAB_IGBY          ; increment and scan memory (3rd character)
    bcc   LAB_1D2E          ; loop if character = "0"-"9" (ignore)

    jsr   LAB_CASC          ; check byte, return C=0 if<"A" or >"Z"
    bcs   LAB_1D2E          ; loop if character = "A"-"Z" (ignore)

                              ; check if string variable
LAB_1D38
    cmp   #'$'              ; compare with "$"
    bne   LAB_1D47          ; branch if not string

; to introduce a new variable type (% suffix for integers say) then this branch
; will need to go to that check and then that branch, if it fails, go to LAB_1D47
                              ; type is string
    lda   #$FF              ; set data type = string
    sta   Dtypef            ; set data type flag, $FF=string, $00=numeric
    txa                     ; get 2nd character back
    ora   #$80              ; set top bit (indicate string var)
    tax                     ; copy back to 2nd character temp
    jsr   LAB_IGBY          ; increment and scan memory

; after we have determined the variable type we need to come back here to determine
; if it's an array of type. this would plug in a%(b[,c[,d]])) integer arrays nicely


LAB_1D47                      ; gets here with character after var name in A
    stx   Varnm2            ; save 2nd character
    ora   Sufnxf            ; or with subscript/FNX flag (or FN name)
    cmp   #'('              ; compare with "("
    bne   LAB_1D53          ; branch if not "("

    jmp   LAB_1E17          ; go find, or make, array

; either find or create var
; var name (1st two characters only!) is in Varnm1,Varnm2

                              ; variable name wasn't var(... so look for plain var
LAB_1D53
    lda   #$00              ; clear A
    sta   Sufnxf            ; clear subscript/FNX flag
    lda   Svarl             ; get start of vars low byte
    ldx   Svarh             ; get start of vars high byte
    ldy   #$00              ; clear index
LAB_1D5D
    stx   Vrschh            ; save search address high byte
LAB_1D5F
    sta   Vrschl            ; save search address low byte
    cpx   Sarryh            ; compare high address with var space end
    bne   LAB_1D69          ; skip next compare if <>

                              ; high addresses were = so compare low addresses
    cmp   Sarryl            ; compare low address with var space end
    beq   LAB_1D8B          ; if not found go make new var

LAB_1D69
    lda   Varnm1            ; get 1st character of var to find
    cmp   (Vrschl),Y        ; compare with variable name 1st character
    bne   LAB_1D77          ; branch if no match

                              ; 1st characters match so compare 2nd characters
    lda   Varnm2            ; get 2nd character of var to find
    iny                     ; index to point to variable name 2nd character
    cmp   (Vrschl),Y        ; compare with variable name 2nd character
    beq   LAB_1DD7          ; branch if match (found var)

    dey                     ; else decrement index (now = $00)
LAB_1D77
    clc                     ; clear carry for add
    lda   Vrschl            ; get search address low byte
    adc   #$06              ; +6 (offset to next var name)
    bcc   LAB_1D5F          ; loop if no overflow to high byte

    inx                     ; else increment high byte
    bne   LAB_1D5D          ; loop always (RAM doesn't extend to $FFFF !)

; check byte, return C=0 if<"A" or >"Z" or "a" to "z"

LAB_CASC
    cmp   #'a'              ; compare with "a"
    bcs   LAB_1D83          ; go check <"z"+1

; check byte, return C=0 if<"A" or >"Z"

LAB_1D82
    cmp   #'A'              ; compare with "A"
    bcc   LAB_1D8A          ; exit if less

                              ; carry is set
    sbc   #$5B              ; subtract "Z"+1
    sec                     ; set carry
    sbc   #$A5              ; subtract $A5 (restore byte)
                              ; carry clear if byte>$5A
LAB_1D8A
    rts

LAB_1D83
    sbc   #$7B              ; subtract "z"+1
    sec                     ; set carry
    sbc   #$85              ; subtract $85 (restore byte)
                              ; carry clear if byte>$7A
    rts

                              ; reached end of variable mem without match
                              ; .. so create new variable
LAB_1D8B
    pla                     ; pop return address low byte
    pha                     ; push return address low byte
LAB_1C18p2  = LAB_1C18+2
    cmp   #<LAB_1C18p2      ; compare with expected calling routine return low byte
    bne   LAB_1D98          ; if not get (var) go create new var

; This will only drop through if the call was from LAB_1C18 and is only called
; from there if it is searching for a variable from the RHS of a LET a=b statement
; it prevents the creation of variables not assigned a value.

; value returned by this is either numeric zero (exponent byte is $00) or null string
; (descriptor length byte is $00). in fact a pointer to any $00 byte would have done.

; doing this saves 6 bytes of variable memory and 168 machine cycles of time

; this is where you would put the undefined variable error call e.g.

;                             ; variable doesn't exist so flag error
;     LDX   #$24              ; error code $24 ("undefined variable" error)
;     JMP   LAB_XERR          ; do error #X then warm start

; the above code has been tested and works a treat! (it replaces the three code lines
; below)

                              ; else return dummy null value
    lda   #<LAB_1D96        ; low byte point to $00,$00
                              ; (uses part of misc constants table)
    ldy   #>LAB_1D96        ; high byte point to $00,$00
    rts

                              ; create new numeric variable
LAB_1D98
    lda   Sarryl            ; get var mem end low byte
    ldy   Sarryh            ; get var mem end high byte
    sta   Ostrtl            ; save old block start low byte
    sty   Ostrth            ; save old block start high byte
    lda   Earryl            ; get array mem end low byte
    ldy   Earryh            ; get array mem end high byte
    sta   Obendl            ; save old block end low byte
    sty   Obendh            ; save old block end high byte
    clc                     ; clear carry for add
    adc   #$06              ; +6 (space for one var)
    bcc   LAB_1DAE          ; branch if no overflow to high byte

    iny                     ; else increment high byte
LAB_1DAE
    sta   Nbendl            ; set new block end low byte
    sty   Nbendh            ; set new block end high byte
    jsr   LAB_11CF          ; open up space in memory
    lda   Nbendl            ; get new start low byte
    ldy   Nbendh            ; get new start high byte (-$100)
    iny                     ; correct high byte
    sta   Sarryl            ; save new var mem end low byte
    sty   Sarryh            ; save new var mem end high byte
    ldy   #$00              ; clear index
    lda   Varnm1            ; get var name 1st character
    sta   (Vrschl),Y        ; save var name 1st character
    iny                     ; increment index
    lda   Varnm2            ; get var name 2nd character
    sta   (Vrschl),Y        ; save var name 2nd character
    lda   #$00              ; clear A
    iny                     ; increment index
    sta   (Vrschl),Y        ; initialise var byte
    iny                     ; increment index
    sta   (Vrschl),Y        ; initialise var byte
    iny                     ; increment index
    sta   (Vrschl),Y        ; initialise var byte
    iny                     ; increment index
    sta   (Vrschl),Y        ; initialise var byte

                              ; found a match for var ((Vrschl) = ptr)
LAB_1DD7
    lda   Vrschl            ; get var address low byte
    clc                     ; clear carry for add
    adc   #$02              ; +2 (offset past var name bytes)
    ldy   Vrschh            ; get var address high byte
    bcc   LAB_1DE1          ; branch if no overflow from add

    iny                     ; else increment high byte
LAB_1DE1
    sta   Cvaral            ; save current var address low byte
    sty   Cvarah            ; save current var address high byte
    rts

; set-up array pointer (Adatal/h) to first element in array
; set Adatal,Adatah to Astrtl,Astrth+2*Dimcnt+#$05

LAB_1DE6
    lda   Dimcnt            ; get # of dimensions (1, 2 or 3)
    asl                     ; *2 (also clears the carry !)
    adc   #$05              ; +5 (result is 7, 9 or 11 here)
    adc   Astrtl            ; add array start pointer low byte
    ldy   Astrth            ; get array pointer high byte
    bcc   LAB_1DF2          ; branch if no overflow

    iny                     ; else increment high byte
LAB_1DF2
    sta   Adatal            ; save array data pointer low byte
    sty   Adatah            ; save array data pointer high byte
    rts

; evaluate integer expression

LAB_EVIN
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch

; evaluate integer expression (no check)

LAB_EVPI
    lda   FAC1_s            ; get FAC1 sign (b7)
    bmi   LAB_1E12          ; do function call error if -ve

; evaluate integer expression (no sign check)

LAB_EVIR
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$90              ; compare with exponent = 2^16 (n>2^15)
    bcc   LAB_1E14          ; branch if n<2^16 (is ok)

    lda   #<LAB_1DF7        ; set pointer low byte to -32768
    ldy   #>LAB_1DF7        ; set pointer high byte to -32768
    jsr   LAB_27F8          ; compare FAC1 with (AY)
LAB_1E12
    bne   LAB_FCER          ; if <> do function call error then warm start

LAB_1E14
    jmp   LAB_2831          ; convert FAC1 floating-to-fixed and return

; find or make array

LAB_1E17
    lda   Defdim            ; get DIM flag
    pha                     ; push it
    lda   Dtypef            ; get data type flag, $FF=string, $00=numeric
    pha                     ; push it
    ldy   #$00              ; clear dimensions count

; now get the array dimension(s) and stack it (them) before the data type and DIM flag

LAB_1E1F
    tya                     ; copy dimensions count
    pha                     ; save it
    lda   Varnm2            ; get array name 2nd byte
    pha                     ; save it
    lda   Varnm1            ; get array name 1st byte
    pha                     ; save it
    jsr   LAB_EVIN          ; evaluate integer expression
    pla                     ; pull array name 1st byte
    sta   Varnm1            ; restore array name 1st byte
    pla                     ; pull array name 2nd byte
    sta   Varnm2            ; restore array name 2nd byte
    pla                     ; pull dimensions count
    tay                     ; restore it
    tsx                     ; copy stack pointer
    lda   LAB_STAK+2,X      ; get DIM flag
    pha                     ; push it
    lda   LAB_STAK+1,X      ; get data type flag
    pha                     ; push it
    lda   FAC1_2            ; get this dimension size high byte
    sta   LAB_STAK+2,X      ; stack before flag bytes
    lda   FAC1_3            ; get this dimension size low byte
    sta   LAB_STAK+1,X      ; stack before flag bytes
    iny                     ; increment dimensions count
    jsr   LAB_GBYT          ; scan memory
    cmp   #','              ; compare with ","
    beq   LAB_1E1F          ; if found go do next dimension

    sty   Dimcnt            ; store dimensions count
    jsr   LAB_1BFB          ; scan for ")" , else do syntax error then warm start
    pla                     ; pull data type flag
    sta   Dtypef            ; restore data type flag, $FF=string, $00=numeric
    pla                     ; pull DIM flag
    sta   Defdim            ; restore DIM flag
    ldx   Sarryl            ; get array mem start low byte
    lda   Sarryh            ; get array mem start high byte

; now check to see if we are at the end of array memory (we would be if there were
; no arrays).

LAB_1E5C
    stx   Astrtl            ; save as array start pointer low byte
    sta   Astrth            ; save as array start pointer high byte
    cmp   Earryh            ; compare with array mem end high byte
    bne   LAB_1E68          ; branch if not reached array mem end

    cpx   Earryl            ; else compare with array mem end low byte
    beq   LAB_1EA1          ; go build array if not found

                              ; search for array
LAB_1E68
    ldy   #$00              ; clear index
    lda   (Astrtl),Y        ; get array name first byte
    iny                     ; increment index to second name byte
    cmp   Varnm1            ; compare with this array name first byte
    bne   LAB_1E77          ; branch if no match

    lda   Varnm2            ; else get this array name second byte
    cmp   (Astrtl),Y        ; compare with array name second byte
    beq   LAB_1E8D          ; array found so branch

                              ; no match
LAB_1E77
    iny                     ; increment index
    lda   (Astrtl),Y        ; get array size low byte
    clc                     ; clear carry for add
    adc   Astrtl            ; add array start pointer low byte
    tax                     ; copy low byte to X
    iny                     ; increment index
    lda   (Astrtl),Y        ; get array size high byte
    adc   Astrth            ; add array mem pointer high byte
    bcc   LAB_1E5C          ; if no overflow go check next array

; do array bounds error

LAB_1E85
    ldx   #$10              ; error code $10 ("Array bounds" error)
      .byte $2C               ; makes next bit BIT LAB_08A2

; do function call error

LAB_FCER
    ldx   #$08              ; error code $08 ("Function call" error)
LAB_1E8A
    jmp   LAB_XERR          ; do error #X, then warm start

                              ; found array, are we trying to dimension it?
LAB_1E8D
    ldx   #$12              ; set error $12 ("Double dimension" error)
    lda   Defdim            ; get DIM flag
    bne   LAB_1E8A          ; if we are trying to dimension it do error #X, then warm
                              ; start

; found the array and we're not dimensioning it so we must find an element in it

    jsr   LAB_1DE6          ; set-up array pointer (Adatal/h) to first element in array
                              ; (Astrtl,Astrth points to start of array)
    lda   Dimcnt            ; get dimensions count
    ldy   #$04              ; set index to array's # of dimensions
    cmp   (Astrtl),Y        ; compare with no of dimensions
    bne   LAB_1E85          ; if wrong do array bounds error, could do "Wrong
                              ; dimensions" error here .. if we want a different
                              ; error message

    jmp   LAB_1F28          ; found array so go get element
                              ; (could jump to LAB_1F28 as all LAB_1F24 does is take
                              ; Dimcnt and save it at (Astrtl),Y which is already the
                              ; same or we would have taken the BNE)

                              ; array not found, so build it
LAB_1EA1
    jsr   LAB_1DE6          ; set-up array pointer (Adatal/h) to first element in array
                              ; (Astrtl,Astrth points to start of array)
    jsr   check_avail_mem          ; check available memory, "Out of memory" error if no room
                              ; addr to check is in AY (low/high)
    ldy   #$00              ; clear Y (don't need to clear A)
    sty   Aspth             ; clear array data size high byte
    lda   Varnm1            ; get variable name 1st byte
    sta   (Astrtl),Y        ; save array name 1st byte
    iny                     ; increment index
    lda   Varnm2            ; get variable name 2nd byte
    sta   (Astrtl),Y        ; save array name 2nd byte
    lda   Dimcnt            ; get dimensions count
    ldy   #$04              ; index to dimension count
    sty   Asptl             ; set array data size low byte (four bytes per element)
    sta   (Astrtl),Y        ; set array's dimensions count

                              ; now calculate the size of the data space for the array
    clc                     ; clear carry for add (clear on subsequent loops)
LAB_1EC0
    ldx   #$0B              ; set default dimension value low byte
    lda   #$00              ; set default dimension value high byte
    bit   Defdim            ; test default DIM flag
    bvc   LAB_1ED0          ; branch if b6 of Defdim is clear

    pla                     ; else pull dimension value low byte
    adc   #$01              ; +1 (allow for zeroeth element)
    tax                     ; copy low byte to X
    pla                     ; pull dimension value high byte
    adc   #$00              ; add carry from low byte

LAB_1ED0
    iny                     ; index to dimension value high byte
    sta   (Astrtl),Y        ; save dimension value high byte
    iny                     ; index to dimension value high byte
    txa                     ; get dimension value low byte
    sta   (Astrtl),Y        ; save dimension value low byte
    jsr   LAB_1F7C          ; does XY = (Astrtl),Y * (Asptl)
    stx   Asptl             ; save array data size low byte
    sta   Aspth             ; save array data size high byte
    ldy   ut1_pl            ; restore index (saved by subroutine)
    dec   Dimcnt            ; decrement dimensions count
    bne   LAB_1EC0          ; loop while not = 0

    adc   Adatah            ; add size high byte to first element high byte
                              ; (carry is always clear here)
    bcs   LAB_1F45          ; if overflow go do "Out of memory" error

    sta   Adatah            ; save end of array high byte
    tay                     ; copy end high byte to Y
    txa                     ; get array size low byte
    adc   Adatal            ; add array start low byte
    bcc   LAB_1EF3          ; branch if no carry

    iny                     ; else increment end of array high byte
    beq   LAB_1F45          ; if overflow go do "Out of memory" error

                              ; set-up mostly complete, now zero the array
LAB_1EF3
    jsr   check_avail_mem          ; check available memory, "Out of memory" error if no room
                              ; addr to check is in AY (low/high)
    sta   Earryl            ; save array mem end low byte
    sty   Earryh            ; save array mem end high byte
    lda   #$00              ; clear byte for array clear
    inc   Aspth             ; increment array size high byte (now block count)
    ldy   Asptl             ; get array size low byte (now index to block)
    beq   LAB_1F07          ; branch if low byte = $00

LAB_1F02
    dey                     ; decrement index (do 0 to n-1)
    sta   (Adatal),Y        ; zero byte
    bne   LAB_1F02          ; loop until this block done

LAB_1F07
    dec   Adatah            ; decrement array pointer high byte
    dec   Aspth             ; decrement block count high byte
    bne   LAB_1F02          ; loop until all blocks done

    inc   Adatah            ; correct for last loop
    sec                     ; set carry for subtract
    ldy   #$02              ; index to array size low byte
    lda   Earryl            ; get array mem end low byte
    sbc   Astrtl            ; subtract array start low byte
    sta   (Astrtl),Y        ; save array size low byte
    iny                     ; index to array size high byte
    lda   Earryh            ; get array mem end high byte
    sbc   Astrth            ; subtract array start high byte
    sta   (Astrtl),Y        ; save array size high byte
    lda   Defdim            ; get default DIM flag
    bne   LAB_1F7B          ; exit (RET) if this was a DIM command

                              ; else, find element
    iny                     ; index to # of dimensions

LAB_1F24
    lda   (Astrtl),Y        ; get array's dimension count
    sta   Dimcnt            ; save it

; we have found, or built, the array. now we need to find the element

LAB_1F28
    lda   #$00              ; clear byte
    sta   Asptl             ; clear array data pointer low byte
LAB_1F2C
    sta   Aspth             ; save array data pointer high byte
    iny                     ; increment index (point to array bound high byte)
    pla                     ; pull array index low byte
    tax                     ; copy to X
    sta   FAC1_2            ; save index low byte to FAC1 mantissa2
    pla                     ; pull array index high byte
    sta   FAC1_3            ; save index high byte to FAC1 mantissa3
    cmp   (Astrtl),Y        ; compare with array bound high byte
    bcc   LAB_1F48          ; branch if within bounds

    bne   LAB_1F42          ; if outside bounds do array bounds error

                              ; else high byte was = so test low bytes
    iny                     ; index to array bound low byte
    txa                     ; get array index low byte
    cmp   (Astrtl),Y        ; compare with array bound low byte
    bcc   LAB_1F49          ; branch if within bounds

LAB_1F42
    jmp   LAB_1E85          ; else do array bounds error

LAB_1F45
    jmp   LAB_OMER          ; do "Out of memory" error then warm start

LAB_1F48
    iny                     ; index to array bound low byte
LAB_1F49
    lda   Aspth             ; get array data pointer high byte
    ora   Asptl             ; OR with array data pointer low byte
    beq   LAB_1F5A          ; branch if array data pointer = null (skip multiply)

    jsr   LAB_1F7C          ; does XY = (Astrtl),Y * (Asptl)
    txa                     ; get result low byte
    adc   FAC1_2            ; add index low byte from FAC1 mantissa2
    tax                     ; save result low byte
    tya                     ; get result high byte
    ldy   ut1_pl            ; restore index
LAB_1F5A
    adc   FAC1_3            ; add index high byte from FAC1 mantissa3
    stx   Asptl             ; save array data pointer low byte
    dec   Dimcnt            ; decrement dimensions count
    bne   LAB_1F2C          ; loop if dimensions still to do

    asl   Asptl             ; array data pointer low byte * 2
    rol                     ; array data pointer high byte * 2
    asl   Asptl             ; array data pointer low byte * 4
    rol                     ; array data pointer high byte * 4
    tay                     ; copy high byte
    lda   Asptl             ; get low byte
    adc   Adatal            ; add array data start pointer low byte
    sta   Cvaral            ; save as current var address low byte
    tya                     ; get high byte back
    adc   Adatah            ; add array data start pointer high byte
    sta   Cvarah            ; save as current var address high byte
    tay                     ; copy high byte to Y
    lda   Cvaral            ; get current var address low byte
LAB_1F7B
    rts

; does XY = (Astrtl),Y * (Asptl)

LAB_1F7C
    sty   ut1_pl            ; save index
    lda   (Astrtl),Y        ; get dimension size low byte
    sta   dims_l            ; save dimension size low byte
    dey                     ; decrement index
    lda   (Astrtl),Y        ; get dimension size high byte
    sta   dims_h            ; save dimension size high byte

    lda   #$10              ; count = $10 (16 bit multiply)
    sta   numbit            ; save bit count
    ldx   #$00              ; clear result low byte
    ldy   #$00              ; clear result high byte
LAB_1F8F
    txa                     ; get result low byte
    asl                     ; *2
    tax                     ; save result low byte
    tya                     ; get result high byte
    rol                     ; *2
    tay                     ; save result high byte
    bcs   LAB_1F45          ; if overflow go do "Out of memory" error

    asl   Asptl             ; shift multiplier low byte
    rol   Aspth             ; shift multiplier high byte
    bcc   LAB_1FA8          ; skip add if no carry

    clc                     ; else clear carry for add
    txa                     ; get result low byte
    adc   dims_l            ; add dimension size low byte
    tax                     ; save result low byte
    tya                     ; get result high byte
    adc   dims_h            ; add dimension size high byte
    tay                     ; save result high byte
    bcs   LAB_1F45          ; if overflow go do "Out of memory" error

LAB_1FA8
    dec   numbit            ; decrement bit count
    bne   LAB_1F8F          ; loop until all done

    rts

; perform FRE()

LAB_FRE
    lda   Dtypef            ; get data type flag, $FF=string, $00=numeric
    bpl   LAB_1FB4          ; branch if numeric

    jsr   LAB_22B6          ; pop string off descriptor stack, or from top of string
                              ; space returns with A = length, X=$71=pointer low byte,
                              ; Y=$72=pointer high byte

                              ; FRE(n) was numeric so do this
LAB_1FB4
    jsr   garbage_collection          ; go do garbage collection
    sec                     ; set carry for subtract
    lda   Sstorl            ; get bottom of string space low byte
    sbc   Earryl            ; subtract array mem end low byte
    tay                     ; copy result to Y
    lda   Sstorh            ; get bottom of string space high byte
    sbc   Earryh            ; subtract array mem end high byte

; save and convert integer AY to FAC1
LAB_AYFC
    lsr   Dtypef            ; clear data type flag, $FF=string, $00=numeric
    sta   FAC1_1            ; save FAC1 mantissa1
    sty   FAC1_2            ; save FAC1 mantissa2
    ldx   #$90              ; set exponent=2^16 (integer)
    jmp   LAB_27E3          ; set exp=X, clear FAC1_3, normalise and return

; perform POS()
basic_POS
    ldy   TPos              ; get terminal position

; convert Y to byte in FAC1
LAB_1FD0
    lda   #$00              ; clear high byte
    beq   LAB_AYFC          ; always save and convert integer AY to FAC1 and return

; check not Direct (used by DEF and INPUT)
LAB_CKRN
    ldx   Clineh            ; get current line high byte
    inx                     ; increment it
    bne   LAB_1F7B          ; return if can continue not direct mode

                              ; else do illegal direct error
LAB_1FD9
    ldx   #$16              ; error code $16 ("Illegal direct" error)
LAB_1FDB
    jmp   LAB_XERR          ; go do error #X, then warm start

; perform DEF
basic_DEF
    jsr   LAB_200B          ; check FNx syntax
    sta   func_l            ; save function pointer low byte
    sty   func_h            ; save function pointer high byte
    jsr   LAB_CKRN          ; check not Direct (back here if ok)
    jsr   LAB_1BFE          ; scan for "(" , else do syntax error then warm start
    lda   #$80              ; set flag for FNx
    sta   Sufnxf            ; save subscript/FNx flag
    jsr   LAB_GVAR          ; get (var) address
    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
    jsr   LAB_1BFB          ; scan for ")" , else do syntax error then warm start
    lda   #token_EQUAL         ; get = token
    jsr   LAB_SCCA          ; scan for CHR$(A), else do syntax error then warm start
    lda   Cvarah            ; get current var address high byte
    pha                     ; push it
    lda   Cvaral            ; get current var address low byte
    pha                     ; push it
    lda   Bpntrh            ; get BASIC execute pointer high byte
    pha                     ; push it
    lda   Bpntrl            ; get BASIC execute pointer low byte
    pha                     ; push it
    jsr   basic_DATA          ; go perform DATA
    jmp   LAB_207A          ; put execute pointer and variable pointer into function
                              ; and return

; check FNx syntax

LAB_200B
    lda   #token_FN            ; get FN" token
    jsr   LAB_SCCA          ; scan for CHR$(A) , else do syntax error then warm start
                              ; return character after A
    ora   #$80              ; set FN flag bit
    sta   Sufnxf            ; save FN flag so array variable test fails
    jsr   LAB_1D12          ; search for FN variable
    jmp   LAB_CTNM          ; check if source is numeric and return, else do type
                              ; mismatch

                              ; Evaluate FNx
LAB_201E
    jsr   LAB_200B          ; check FNx syntax
    pha                     ; push function pointer low byte
    tya                     ; copy function pointer high byte
    pha                     ; push function pointer high byte
    jsr   LAB_1BFE          ; scan for "(", else do syntax error then warm start
    jsr   LAB_EVEX          ; evaluate expression
    jsr   LAB_1BFB          ; scan for ")", else do syntax error then warm start
    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
    pla                     ; pop function pointer high byte
    sta   func_h            ; restore it
    pla                     ; pop function pointer low byte
    sta   func_l            ; restore it
    ldx   #$20              ; error code $20 ("Undefined function" error)
    ldy   #$03              ; index to variable pointer high byte
    lda   (func_l),Y        ; get variable pointer high byte
    beq   LAB_1FDB          ; if zero go do undefined function error

    sta   Cvarah            ; save variable address high byte
    dey                     ; index to variable address low byte
    lda   (func_l),Y        ; get variable address low byte
    sta   Cvaral            ; save variable address low byte
    tax                     ; copy address low byte

                              ; now stack the function variable value before use
    iny                     ; index to mantissa_3
LAB_2043
    lda   (Cvaral),Y        ; get byte from variable
    pha                     ; stack it
    dey                     ; decrement index
    bpl   LAB_2043          ; loop until variable stacked

    ldy   Cvarah            ; get variable address high byte
    jsr   LAB_2778          ; pack FAC1 (function expression value) into (XY)
                              ; (function variable), return Y=0, always
    lda   Bpntrh            ; get BASIC execute pointer high byte
    pha                     ; push it
    lda   Bpntrl            ; get BASIC execute pointer low byte
    pha                     ; push it
    lda   (func_l),Y        ; get function execute pointer low byte
    sta   Bpntrl            ; save as BASIC execute pointer low byte
    iny                     ; index to high byte
    lda   (func_l),Y        ; get function execute pointer high byte
    sta   Bpntrh            ; save as BASIC execute pointer high byte
    lda   Cvarah            ; get variable address high byte
    pha                     ; push it
    lda   Cvaral            ; get variable address low byte
    pha                     ; push it
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
    pla                     ; pull variable address low byte
    sta   func_l            ; save variable address low byte
    pla                     ; pull variable address high byte
    sta   func_h            ; save variable address high byte
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_2074          ; branch if null (should be [EOL] marker)

    jmp   LAB_SNER          ; else syntax error then warm start

; restore Bpntrl,Bpntrh and function variable from stack

LAB_2074
    pla                     ; pull BASIC execute pointer low byte
    sta   Bpntrl            ; restore BASIC execute pointer low byte
    pla                     ; pull BASIC execute pointer high byte
    sta   Bpntrh            ; restore BASIC execute pointer high byte

; put execute pointer and variable pointer into function

LAB_207A
    ldy   #$00              ; clear index
    pla                     ; pull BASIC execute pointer low byte
    sta   (func_l),Y        ; save to function
    iny                     ; increment index
    pla                     ; pull BASIC execute pointer high byte
    sta   (func_l),Y        ; save to function
    iny                     ; increment index
    pla                     ; pull current var address low byte
    sta   (func_l),Y        ; save to function
    iny                     ; increment index
    pla                     ; pull current var address high byte
    sta   (func_l),Y        ; save to function
    rts

; perform STR$()

LAB_STRS
    jsr   LAB_CTNM          ; check if source is numeric, else do type mismatch
    jsr   LAB_296E          ; convert FAC1 to string
    lda   #<Decssp1         ; set result string low pointer
    ldy   #>Decssp1         ; set result string high pointer
    beq   LAB_20AE          ; print null terminated string to Sutill/Sutilh

; Do string vector
; copy des_pl/h to des_2l/h and make string space A bytes long

LAB_209C
    ldx   des_pl            ; get descriptor pointer low byte
    ldy   des_ph            ; get descriptor pointer high byte
    stx   des_2l            ; save descriptor pointer low byte
    sty   des_2h            ; save descriptor pointer high byte

; make string space A bytes long
; A=length, X=Sutill=ptr low byte, Y=Sutilh=ptr high byte

LAB_MSSP
    jsr   LAB_2115          ; make space in string memory for string A long
                              ; return X=Sutill=ptr low byte, Y=Sutilh=ptr high byte
    stx   str_pl            ; save string pointer low byte
    sty   str_ph            ; save string pointer high byte
    sta   str_ln            ; save length
    rts

; Scan, set up string
; print " terminated string to Sutill/Sutilh

LAB_20AE
    ldx   #$22              ; set terminator to "
    stx   Srchc             ; set search character (terminator 1)
    stx   Asrch             ; set terminator 2

; print [Srchc] or [Asrch] terminated string to Sutill/Sutilh
; source is AY

LAB_20B4
    sta   ssptr_l           ; store string start low byte
    sty   ssptr_h           ; store string start high byte
    sta   str_pl            ; save string pointer low byte
    sty   str_ph            ; save string pointer high byte
    ldy   #$FF              ; set length to -1
LAB_20BE
    iny                     ; increment length
    lda   (ssptr_l),Y       ; get byte from string
    beq   LAB_20CF          ; exit loop if null byte [EOS]

    cmp   Srchc             ; compare with search character (terminator 1)
    beq   LAB_20CB          ; branch if terminator

    cmp   Asrch             ; compare with terminator 2
    bne   LAB_20BE          ; loop if not terminator 2

LAB_20CB
    cmp   #$22              ; compare with "
    beq   LAB_20D0          ; branch if " (carry set if = !)

LAB_20CF
    clc                     ; clear carry for add (only if [EOL] terminated string)
LAB_20D0
    sty   str_ln            ; save length in FAC1 exponent
    tya                     ; copy length to A
    adc   ssptr_l           ; add string start low byte
    sta   Sendl             ; save string end low byte
    ldx   ssptr_h           ; get string start high byte
    bcc   LAB_20DC          ; branch if no low byte overflow

    inx                     ; else increment high byte
LAB_20DC
    stx   Sendh             ; save string end high byte
    lda   ssptr_h           ; get string start high byte
; *** begin RAM above code / Ibuff above EhBASIC patch V2 ***
; *** replace
;      CMP   #>Ram_base        ; compare with start of program memory
;      BCS   LAB_RTST          ; branch if not in utility area
; *** with
    beq   LAB_MVST          ; fix STR$() using page zero via LAB_296E
    cmp   #>Ibuffs          ; compare with location of input buffer page
    bne   LAB_RTST          ; branch if not in utility area
LAB_MVST
; *** end   RAM above code / Ibuff above EhBASIC patch V2 ***

                              ; string in utility area, move to string memory
    tya                     ; copy length to A
    jsr   LAB_209C          ; copy des_pl/h to des_2l/h and make string space A bytes
                              ; long
    ldx   ssptr_l           ; get string start low byte
    ldy   ssptr_h           ; get string start high byte
    jsr   LAB_2298          ; store string A bytes long from XY to (Sutill)

; check for space on descriptor stack then ..
; put string address and length on descriptor stack and update stack pointers

LAB_RTST
    ldx   next_s            ; get string stack pointer
    cpx   #des_sk+$09       ; compare with max+1
    bne   LAB_20F8          ; branch if space on string stack

                              ; else do string too complex error
    ldx   #$1C              ; error code $1C ("String too complex" error)
LAB_20F5
    jmp   LAB_XERR          ; do error #X, then warm start

; put string address and length on descriptor stack and update stack pointers

LAB_20F8
    lda   str_ln            ; get string length
    sta   PLUS_0,X          ; put on string stack
    lda   str_pl            ; get string pointer low byte
    sta   PLUS_1,X          ; put on string stack
    lda   str_ph            ; get string pointer high byte
    sta   PLUS_2,X          ; put on string stack
    ldy   #$00              ; clear Y
    stx   des_pl            ; save string descriptor pointer low byte
    sty   des_ph            ; save string descriptor pointer high byte (always $00)
    dey                     ; Y = $FF
    sty   Dtypef            ; save data type flag, $FF=string
    stx   last_sl           ; save old stack pointer (current top item)
    inx                     ; update stack pointer
    inx                     ; update stack pointer
    inx                     ; update stack pointer
    stx   next_s            ; save new top item value
    rts

; Build descriptor
; make space in string memory for string A long
; return X=Sutill=ptr low byte, Y=Sutill=ptr high byte

LAB_2115
    lsr   clear_gc_flag            ; clear garbage collected flag (b7)

                              ; make space for string A long
LAB_2117
    pha                     ; save string length
    eor   #$FF              ; complement it
    sec                     ; set carry for subtract (twos comp add)
    adc   Sstorl            ; add bottom of string space low byte (subtract length)
    ldy   Sstorh            ; get bottom of string space high byte
    bcs   LAB_2122          ; skip decrement if no underflow

    dey                     ; decrement bottom of string space high byte
LAB_2122
    cpy   Earryh            ; compare with array mem end high byte
    bcc   LAB_2137          ; do out of memory error if less

    bne   LAB_212C          ; if not = skip next test

    cmp   Earryl            ; compare with array mem end low byte
    bcc   LAB_2137          ; do out of memory error if less

LAB_212C
    sta   Sstorl            ; save bottom of string space low byte
    sty   Sstorh            ; save bottom of string space high byte
    sta   Sutill            ; save string utility ptr low byte
    sty   Sutilh            ; save string utility ptr high byte
    tax                     ; copy low byte to X
    pla                     ; get string length back
    rts

LAB_2137
    ldx   #$0C              ; error code $0C ("Out of memory" error)
    lda   clear_gc_flag            ; get garbage collected flag
    bmi   LAB_20F5          ; if set then do error code X

    jsr   garbage_collection          ; else go do garbage collection
    lda   #$80              ; flag for garbage collected
    sta   clear_gc_flag            ; set garbage collected flag
    pla                     ; pull length
    bne   LAB_2117          ; go try again (loop always, length should never be = $00)

; garbage collection routine

garbage_collection
    ldx   Ememl             ; get end of mem low byte
    lda   Ememh             ; get end of mem high byte

; re-run routine from last ending

LAB_214B
    stx   Sstorl            ; set string storage low byte
    sta   Sstorh            ; set string storage high byte
    ldy   #$00              ; clear index
    sty   garb_h            ; clear working pointer high byte (flag no strings to move)
; *** begin patch  2.22p5.5  garbage collection may overlap temporary strings
; *** add
    sty   garb_l            ; clear working pointer low byte (flag no strings to move)
; *** begin patch  2.22p5.5  garbage collection may overlap temporary strings
    lda   Earryl            ; get array mem end low byte
    ldx   Earryh            ; get array mem end high byte
    sta   Histrl            ; save as highest string low byte
    stx   Histrh            ; save as highest string high byte
    lda   #des_sk           ; set descriptor stack pointer
    sta   ut1_pl            ; save descriptor stack pointer low byte
    sty   ut1_ph            ; save descriptor stack pointer high byte ($00)
LAB_2161
    cmp   next_s            ; compare with descriptor stack pointer
    beq   LAB_216A          ; branch if =

    jsr   LAB_21D7          ; go garbage collect descriptor stack
    beq   LAB_2161          ; loop always

                              ; done stacked strings, now do string vars
LAB_216A
    asl   g_step            ; set step size = $06
    lda   Svarl             ; get start of vars low byte
    ldx   Svarh             ; get start of vars high byte
    sta   ut1_pl            ; save as pointer low byte
    stx   ut1_ph            ; save as pointer high byte
LAB_2176
    cpx   Sarryh            ; compare start of arrays high byte
    bne   LAB_217E          ; branch if no high byte match

    cmp   Sarryl            ; else compare start of arrays low byte
    beq   LAB_2183          ; branch if = var mem end

LAB_217E
    jsr   gc_strings          ; go garbage collect strings
    beq   LAB_2176          ; loop always

                              ; done string vars, now do string arrays
LAB_2183
    sta   Nbendl            ; save start of arrays low byte as working pointer
    stx   Nbendh            ; save start of arrays high byte as working pointer
    lda   #$04              ; set step size
    sta   g_step            ; save step size
LAB_218B
    lda   Nbendl            ; get pointer low byte
    ldx   Nbendh            ; get pointer high byte
LAB_218F
    cpx   Earryh            ; compare with array mem end high byte
    bne   LAB_219A          ; branch if not at end

    cmp   Earryl            ; else compare with array mem end low byte
    beq   LAB_2216          ; tidy up and exit if at end

LAB_219A
    sta   ut1_pl            ; save pointer low byte
    stx   ut1_ph            ; save pointer high byte
    ldy   #$02              ; set index
    lda   (ut1_pl),Y        ; get array size low byte
    adc   Nbendl            ; add start of this array low byte
    sta   Nbendl            ; save start of next array low byte
    iny                     ; increment index
    lda   (ut1_pl),Y        ; get array size high byte
    adc   Nbendh            ; add start of this array high byte
    sta   Nbendh            ; save start of next array high byte
    ldy   #$01              ; set index
    lda   (ut1_pl),Y        ; get name second byte
    bpl   LAB_218B          ; skip if not string array

; was string array so ..

    ldy   #$04              ; set index
    lda   (ut1_pl),Y        ; get # of dimensions
    asl                     ; *2
    adc   #$05              ; +5 (array header size)
    jsr   LAB_2208          ; go set up for first element
LAB_21C4
    cpx   Nbendh            ; compare with start of next array high byte
    bne   LAB_21CC          ; branch if <> (go do this array)

    cmp   Nbendl            ; else compare element pointer low byte with next array
                              ; low byte
    beq   LAB_218F          ; if equal then go do next array

LAB_21CC
    jsr   LAB_21D7          ; go defrag array strings
    beq   LAB_21C4          ; go do next array string (loop always)

; defrag string variables
; enter with XA = variable pointer
; return with XA = next variable pointer

gc_strings:
    iny                     ; increment index (Y was $00)
    lda   (ut1_pl),Y        ; get var name byte 2
    bpl   LAB_2206          ; if not string, step pointer to next var and return

    iny                     ; else increment index
LAB_21D7
    lda   (ut1_pl),Y        ; get string length
    beq   LAB_2206          ; if null, step pointer to next string and return

    iny                     ; else increment index
    lda   (ut1_pl),Y        ; get string pointer low byte
    tax                     ; copy to X
    iny                     ; increment index
    lda   (ut1_pl),Y        ; get string pointer high byte
    cmp   Sstorh            ; compare bottom of string space high byte
    bcc   LAB_21EC          ; branch if less

    bne   LAB_2206          ; if greater, step pointer to next string and return

                              ; high bytes were = so compare low bytes
    cpx   Sstorl            ; compare bottom of string space low byte
    bcs   LAB_2206          ; if >=, step pointer to next string and return

                              ; string pointer is < string storage pointer (pos in mem)
LAB_21EC
    cmp   Histrh            ; compare to highest string high byte
    bcc   LAB_2207          ; if <, step pointer to next string and return

    bne   LAB_21F6          ; if > update pointers, step to next and return

                              ; high bytes were = so compare low bytes
    cpx   Histrl            ; compare to highest string low byte
    bcc   LAB_2207          ; if <, step pointer to next string and return

                              ; string is in string memory space
LAB_21F6
    stx   Histrl            ; save as new highest string low byte
    sta   Histrh            ; save as new highest string high byte
    lda   ut1_pl            ; get start of vars(descriptors) low byte
    ldx   ut1_ph            ; get start of vars(descriptors) high byte
    sta   garb_l            ; save as working pointer low byte
    stx   garb_h            ; save as working pointer high byte
    dey                     ; decrement index DIFFERS
    dey                     ; decrement index (should point to descriptor start)
    sty   g_indx            ; save index pointer

                              ; step pointer to next string
LAB_2206
    clc                     ; clear carry for add
LAB_2207
    lda   g_step            ; get step size
LAB_2208
    adc   ut1_pl            ; add pointer low byte
    sta   ut1_pl            ; save pointer low byte
    bcc   LAB_2211          ; branch if no overflow

    inc   ut1_ph            ; else increment high byte
LAB_2211
    ldx   ut1_ph            ; get pointer high byte
    ldy   #$00              ; clear Y
    rts

; search complete, now either exit or set-up and move string

LAB_2216
    dec   g_step            ; decrement step size (now $03 for descriptor stack)
; *** begin patch  2.22p5.5  garbage collection may overlap temporary strings
; *** replace
;      LDX   garb_h            ; get string to move high byte
; *** with
    lda   garb_h            ; any string to move?
    ora   garb_l
; *** end   patch  2.22p5.5  garbage collection may overlap temporary strings
    beq   LAB_2211          ; exit if nothing to move

    ldy   g_indx            ; get index byte back (points to descriptor)
    clc                     ; clear carry for add
    lda   (garb_l),Y        ; get string length
    adc   Histrl            ; add highest string low byte
    sta   Obendl            ; save old block end low pointer
    lda   Histrh            ; get highest string high byte
    adc   #$00              ; add any carry
    sta   Obendh            ; save old block end high byte
    lda   Sstorl            ; get bottom of string space low byte
    ldx   Sstorh            ; get bottom of string space high byte
    sta   Nbendl            ; save new block end low byte
    stx   Nbendh            ; save new block end high byte
    jsr   LAB_11D6          ; open up space in memory, don't set array end
    ldy   g_indx            ; get index byte
    iny                     ; point to descriptor low byte
    lda   Nbendl            ; get string pointer low byte
    sta   (garb_l),Y        ; save new string pointer low byte
    tax                     ; copy string pointer low byte
    inc   Nbendh            ; correct high byte (move sets high byte -1)
    lda   Nbendh            ; get new string pointer high byte
    iny                     ; point to descriptor high byte
    sta   (garb_l),Y        ; save new string pointer high byte
    jmp   LAB_214B          ; re-run routine from last ending
                              ; (but don't collect this string)

; concatenate
; add strings, string 1 is in descriptor des_pl, string 2 is in line

LAB_224D
    lda   des_ph            ; get descriptor pointer high byte
    pha                     ; put on stack
    lda   des_pl            ; get descriptor pointer low byte
    pha                     ; put on stack
; *** begin patch  2.22p5.4  concatenate MINUS or NOT() crashes EhBASIC  ***
; *** add extra label to verify originating function
LAB_224Da
; *** end patch    2.22p5.4  concatenate MINUS or NOT() crashes EhBASIC  ***
    jsr   LAB_GVAL          ; get value from line
    jsr   LAB_CTST          ; check if source is string, else do type mismatch
    pla                     ; get descriptor pointer low byte back
    sta   ssptr_l           ; set pointer low byte
    pla                     ; get descriptor pointer high byte back
    sta   ssptr_h           ; set pointer high byte
    ldy   #$00              ; clear index
    lda   (ssptr_l),Y       ; get length_1 from descriptor
    clc                     ; clear carry for add
    adc   (des_pl),Y        ; add length_2
    bcc   LAB_226D          ; branch if no overflow

    ldx   #$1A              ; else set error code $1A ("String too long" error)
    jmp   LAB_XERR          ; do error #X, then warm start

LAB_226D
    jsr   LAB_209C          ; copy des_pl/h to des_2l/h and make string space A bytes
                              ; long
    jsr   LAB_228A          ; copy string from descriptor (sdescr) to (Sutill)
    lda   des_2l            ; get descriptor pointer low byte
    ldy   des_2h            ; get descriptor pointer high byte
    jsr   LAB_22BA          ; pop (YA) descriptor off stack or from top of string space
                              ; returns with A = length, ut1_pl = pointer low byte,
                              ; ut1_ph = pointer high byte
    jsr   LAB_229C          ; store string A bytes long from (ut1_pl) to (Sutill)
    lda   ssptr_l           ;.set descriptor pointer low byte
    ldy   ssptr_h           ;.set descriptor pointer high byte
    jsr   LAB_22BA          ; pop (YA) descriptor off stack or from top of string space
                              ; returns with A = length, X=ut1_pl=pointer low byte,
                              ; Y=ut1_ph=pointer high byte
    jsr   LAB_RTST          ; check for space on descriptor stack then put string
                              ; address and length on descriptor stack and update stack
                              ; pointers
    jmp   LAB_1ADB          ;.continue evaluation

; copy string from descriptor (sdescr) to (Sutill)

LAB_228A
    ldy   #$00              ; clear index
    lda   (sdescr),Y        ; get string length
    pha                     ; save on stack
    iny                     ; increment index
    lda   (sdescr),Y        ; get source string pointer low byte
    tax                     ; copy to X
    iny                     ; increment index
    lda   (sdescr),Y        ; get source string pointer high byte
    tay                     ; copy to Y
    pla                     ; get length back

; store string A bytes long from YX to (Sutill)

LAB_2298
    stx   ut1_pl            ; save source string pointer low byte
    sty   ut1_ph            ; save source string pointer high byte

; store string A bytes long from (ut1_pl) to (Sutill)

LAB_229C
    tax                     ; copy length to index (don't count with Y)
    beq   LAB_22B2          ; branch if = $0 (null string) no need to add zero length

    ldy   #$00              ; zero pointer (copy forward)
LAB_22A0
    lda   (ut1_pl),Y        ; get source byte
    sta   (Sutill),Y        ; save destination byte

    iny                     ; increment index
    dex                     ; decrement counter
    bne   LAB_22A0          ; loop while <> 0

    tya                     ; restore length from Y
LAB_22A9
    clc                     ; clear carry for add
    adc   Sutill            ; add string utility ptr low byte
    sta   Sutill            ; save string utility ptr low byte
    bcc   LAB_22B2          ; branch if no carry

    inc   Sutilh            ; else increment string utility ptr high byte
LAB_22B2
    rts

; evaluate string

LAB_EVST
    jsr   LAB_CTST          ; check if source is string, else do type mismatch

; pop string off descriptor stack, or from top of string space
; returns with A = length, X=pointer low byte, Y=pointer high byte

LAB_22B6
    lda   des_pl            ; get descriptor pointer low byte
    ldy   des_ph            ; get descriptor pointer high byte

; pop (YA) descriptor off stack or from top of string space
; returns with A = length, X=ut1_pl=pointer low byte, Y=ut1_ph=pointer high byte

LAB_22BA
    sta   ut1_pl            ; save descriptor pointer low byte
    sty   ut1_ph            ; save descriptor pointer high byte
    jsr   LAB_22EB          ; clean descriptor stack, YA = pointer
    php                     ; save status flags
    ldy   #$00              ; clear index
    lda   (ut1_pl),Y        ; get length from string descriptor
    pha                     ; put on stack
    iny                     ; increment index
    lda   (ut1_pl),Y        ; get string pointer low byte from descriptor
    tax                     ; copy to X
    iny                     ; increment index
    lda   (ut1_pl),Y        ; get string pointer high byte from descriptor
    tay                     ; copy to Y
    pla                     ; get string length back
    plp                     ; restore status
    bne   LAB_22E6          ; branch if pointer <> last_sl,last_sh

    cpy   Sstorh            ; compare bottom of string space high byte
    bne   LAB_22E6          ; branch if <>

    cpx   Sstorl            ; else compare bottom of string space low byte
    bne   LAB_22E6          ; branch if <>

    pha                     ; save string length
    clc                     ; clear carry for add
    adc   Sstorl            ; add bottom of string space low byte
    sta   Sstorl            ; save bottom of string space low byte
    bcc   LAB_22E5          ; skip increment if no overflow

    inc   Sstorh            ; increment bottom of string space high byte
LAB_22E5
    pla                     ; restore string length
LAB_22E6
    stx   ut1_pl            ; save string pointer low byte
    sty   ut1_ph            ; save string pointer high byte
    rts

; clean descriptor stack, YA = pointer
; checks if AY is on the descriptor stack, if so does a stack discard

LAB_22EB
    cpy   last_sh           ; compare pointer high byte
    bne   LAB_22FB          ; exit if <>

    cmp   last_sl           ; compare pointer low byte
    bne   LAB_22FB          ; exit if <>

    sta   next_s            ; save descriptor stack pointer
    sbc   #$03              ; -3
    sta   last_sl           ; save low byte -3
    ldy   #$00              ; clear high byte
LAB_22FB
    rts

; perform CHR$()

LAB_CHRS
    jsr   LAB_EVBY          ; evaluate byte expression, result in X
    txa                     ; copy to A
    pha                     ; save character
    lda   #$01              ; string is single byte
    jsr   LAB_MSSP          ; make string space A bytes long A=$AC=length,
                              ; X=$AD=Sutill=ptr low byte, Y=$AE=Sutilh=ptr high byte
    pla                     ; get character back
    ldy   #$00              ; clear index
    sta   (str_pl),Y        ; save byte in string (byte IS string!)
    jmp   LAB_RTST          ; check for space on descriptor stack then put string
                              ; address and length on descriptor stack and update stack
                              ; pointers

; perform LEFT$()

LAB_LEFT
    pha                     ; push byte parameter
    jsr   LAB_236F          ; pull string data and byte parameter from stack
                              ; return pointer in des_2l/h, byte in A (and X), Y=0
    cmp   (des_2l),Y        ; compare byte parameter with string length
    tya                     ; clear A
    beq   LAB_2316          ; go do string copy (branch always)

; perform RIGHT$()

LAB_RIGHT
    pha                     ; push byte parameter
    jsr   LAB_236F          ; pull string data and byte parameter from stack
                              ; return pointer in des_2l/h, byte in A (and X), Y=0
    clc                     ; clear carry for add-1
    sbc   (des_2l),Y        ; subtract string length
    eor   #$FF              ; invert it (A=LEN(expression$)-l)

LAB_2316
    bcc   LAB_231C          ; branch if string length > byte parameter

    lda   (des_2l),Y        ; else make parameter = length
    tax                     ; copy to byte parameter copy
    tya                     ; clear string start offset
LAB_231C
    pha                     ; save string start offset
LAB_231D
    txa                     ; copy byte parameter (or string length if <)
LAB_231E
    pha                     ; save string length
    jsr   LAB_MSSP          ; make string space A bytes long A=$AC=length,
                              ; X=$AD=Sutill=ptr low byte, Y=$AE=Sutilh=ptr high byte
    lda   des_2l            ; get descriptor pointer low byte
    ldy   des_2h            ; get descriptor pointer high byte
    jsr   LAB_22BA          ; pop (YA) descriptor off stack or from top of string space
                              ; returns with A = length, X=ut1_pl=pointer low byte,
                              ; Y=ut1_ph=pointer high byte
    pla                     ; get string length back
    tay                     ; copy length to Y
    pla                     ; get string start offset back
    clc                     ; clear carry for add
    adc   ut1_pl            ; add start offset to string start pointer low byte
    sta   ut1_pl            ; save string start pointer low byte
    bcc   LAB_2335          ; branch if no overflow

    inc   ut1_ph            ; else increment string start pointer high byte
LAB_2335
    tya                     ; copy length to A
    jsr   LAB_229C          ; store string A bytes long from (ut1_pl) to (Sutill)
    jmp   LAB_RTST          ; check for space on descriptor stack then put string
                              ; address and length on descriptor stack and update stack
                              ; pointers

; perform MID$()

LAB_MIDS
    pha                     ; push byte parameter
    lda   #$FF              ; set default length = 255
    sta   mids_l            ; save default length
    jsr   LAB_GBYT          ; scan memory
    cmp   #')'              ; compare with ")"
    beq   LAB_2358          ; branch if = ")" (skip second byte get)

    jsr   LAB_1C01          ; scan for "," , else do syntax error then warm start
    jsr   LAB_GTBY          ; get byte parameter (use copy in mids_l)
LAB_2358
    jsr   LAB_236F          ; pull string data and byte parameter from stack
                              ; return pointer in des_2l/h, byte in A (and X), Y=0
    dex                     ; decrement start index
    txa                     ; copy to A
    pha                     ; save string start offset
    clc                     ; clear carry for sub-1
    ldx   #$00              ; clear output string length
    sbc   (des_2l),Y        ; subtract string length
    bcs   LAB_231D          ; if start>string length go do null string

    eor   #$FF              ; complement -length
    cmp   mids_l            ; compare byte parameter
    bcc   LAB_231E          ; if length>remaining string go do RIGHT$

    lda   mids_l            ; get length byte
    bcs   LAB_231E          ; go do string copy (branch always)

; pull string data and byte parameter from stack
; return pointer in des_2l/h, byte in A (and X), Y=0

LAB_236F
    jsr   LAB_1BFB          ; scan for ")" , else do syntax error then warm start
    pla                     ; pull return address low byte (return address)
    sta   Fnxjpl            ; save functions jump vector low byte
    pla                     ; pull return address high byte (return address)
    sta   Fnxjph            ; save functions jump vector high byte
    pla                     ; pull byte parameter
    tax                     ; copy byte parameter to X
    pla                     ; pull string pointer low byte
    sta   des_2l            ; save it
    pla                     ; pull string pointer high byte
    sta   des_2h            ; save it
    ldy   #$00              ; clear index
    txa                     ; copy byte parameter
    beq   LAB_23A8          ; if null do function call error then warm start

    inc   Fnxjpl            ; increment function jump vector low byte
                              ; (JSR pushes return addr-1. this is all very nice
                              ; but will go tits up if either call is on a page
                              ; boundary!)
    jmp   (Fnxjpl)          ; in effect, RTS

; perform LCASE$()

LAB_LCASE
    jsr   LAB_EVST          ; evaluate string
    sta   str_ln            ; set string length
    tay                     ; copy length to Y
    beq   NoString          ; branch if null string

    jsr   LAB_MSSP          ; make string space A bytes long A=length,
                              ; X=Sutill=ptr low byte, Y=Sutilh=ptr high byte
    stx   str_pl            ; save string pointer low byte
    sty   str_ph            ; save string pointer high byte
    tay                     ; get string length back

LC_loop
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get byte from string
    jsr   LAB_1D82          ; is character "A" to "Z"
    bcc   NoUcase           ; branch if not upper case alpha

    ora   #$20              ; convert upper to lower case
NoUcase
    sta   (Sutill),Y        ; save byte back to string
    tya                     ; test index
    bne   LC_loop           ; loop if not all done

    beq   NoString          ; tidy up and exit, branch always

; perform UCASE$()

LAB_UCASE
    jsr   LAB_EVST          ; evaluate string
    sta   str_ln            ; set string length
    tay                     ; copy length to Y
    beq   NoString          ; branch if null string

    jsr   LAB_MSSP          ; make string space A bytes long A=length,
                              ; X=Sutill=ptr low byte, Y=Sutilh=ptr high byte
    stx   str_pl            ; save string pointer low byte
    sty   str_ph            ; save string pointer high byte
    tay                     ; get string length back

UC_loop
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get byte from string
    jsr   LAB_CASC          ; is character "a" to "z" (or "A" to "Z")
    bcc   NoLcase           ; branch if not alpha

    and   #$DF              ; convert lower to upper case
NoLcase
    sta   (Sutill),Y        ; save byte back to string
    tya                     ; test index
    bne   UC_loop           ; loop if not all done

NoString
    jmp   LAB_RTST          ; check for space on descriptor stack then put string
                              ; address and length on descriptor stack and update stack
                              ; pointers

; perform SADD()

LAB_SADD
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_GVAR          ; get var address

    jsr   LAB_1BFB          ; scan for ")", else do syntax error then warm start
    jsr   LAB_CTST          ; check if source is string, else do type mismatch

    ldy   #$02              ; index to string pointer high byte
    lda   (Cvaral),Y        ; get string pointer high byte
    tax                     ; copy string pointer high byte to X
    dey                     ; index to string pointer low byte
    lda   (Cvaral),Y        ; get string pointer low byte
    tay                     ; copy string pointer low byte to Y
    txa                     ; copy string pointer high byte to A
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform LEN()

LAB_LENS
    jsr   LAB_ESGL          ; evaluate string, get length in A (and Y)
    jmp   LAB_1FD0          ; convert Y to byte in FAC1 and return

; evaluate string, get length in Y

LAB_ESGL
    jsr   LAB_EVST          ; evaluate string
    tay                     ; copy length to Y
    rts

; perform ASC()

LAB_ASC
    jsr   LAB_ESGL          ; evaluate string, get length in A (and Y)
    beq   LAB_23A8          ; if null do function call error then warm start

    ldy   #$00              ; set index to first character
    lda   (ut1_pl),Y        ; get byte
    tay                     ; copy to Y
    jmp   LAB_1FD0          ; convert Y to byte in FAC1 and return

; do function call error then warm start

LAB_23A8
    jmp   LAB_FCER          ; do function call error then warm start

; scan and get byte parameter

LAB_SGBY
    jsr   LAB_IGBY          ; increment and scan memory

; get byte parameter

LAB_GTBY
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch

; evaluate byte expression, result in X

LAB_EVBY
    jsr   LAB_EVPI          ; evaluate integer expression (no check)

    ldy   FAC1_2            ; get FAC1 mantissa2
    bne   LAB_23A8          ; if top byte <> 0 do function call error then warm start

    ldx   FAC1_3            ; get FAC1 mantissa3
    jmp   LAB_GBYT          ; scan memory and return

; perform VAL()

LAB_VAL
    jsr   LAB_ESGL          ; evaluate string, get length in A (and Y)
    bne   LAB_23C5          ; branch if not null string

                              ; string was null so set result = $00
    jmp   LAB_24F1          ; clear FAC1 exponent and sign and return

LAB_23C5
; *** begin patch  2.22p5.7  VAL() may cause string variables to be trashed
; *** replace
;      LDX   Bpntrl            ; get BASIC execute pointer low byte
;      LDY   Bpntrh            ; get BASIC execute pointer high byte
;      STX   Btmpl             ; save BASIC execute pointer low byte
;      STY   Btmph             ; save BASIC execute pointer high byte
;      LDX   ut1_pl            ; get string pointer low byte
;      STX   Bpntrl            ; save as BASIC execute pointer low byte
;      CLC                     ; clear carry
;      ADC   ut1_pl            ; add string length
;      STA   ut2_pl            ; save string end low byte
;      LDA   ut1_ph            ; get string pointer high byte
;      STA   Bpntrh            ; save as BASIC execute pointer high byte
;      ADC   #$00              ; add carry to high byte
;      STA   ut2_ph            ; save string end high byte
;      LDY   #$00              ; set index to $00
;      LDA   (ut2_pl),Y        ; get string end +1 byte
;      PHA                     ; push it
;      TYA                     ; clear A
;      STA   (ut2_pl),Y        ; terminate string with $00
;      JSR   LAB_GBYT          ; scan memory
;      JSR   LAB_2887          ; get FAC1 from string
;      PLA                     ; restore string end +1 byte
;      LDY   #$00              ; set index to zero
;      STA   (ut2_pl),Y        ; put string end byte back
; *** with
    pha                     ; save length
    iny                     ; string length +1
      TYA
    jsr   LAB_MSSP          ; allocate temp string +1 bytes long
    pla                     ; get length back
    jsr   LAB_229C          ; copy string (ut1_pl) -> (Sutill) for A bytes
    lda   #0                ; add delimiter to end of string
      TAY
    sta   (Sutill),Y
    ldx   Bpntrl            ; save BASIC execute pointer low byte
    ldy   Bpntrh
    stx   Btmpl
    sty   Btmph
    ldx   str_pl            ; point to temporary string
    ldy   str_ph
    stx   Bpntrl
    sty   Bpntrh
    jsr   LAB_GBYT          ; scan memory
    jsr   LAB_2887          ; get FAC1 from string
; *** end patch    2.22p5.7  VAL() may cause string variables to be trashed

; restore BASIC execute pointer from temp (Btmpl/Btmph)

LAB_23F3
    ldx   Btmpl             ; get BASIC execute pointer low byte back
    ldy   Btmph             ; get BASIC execute pointer high byte back
    stx   Bpntrl            ; save BASIC execute pointer low byte
    sty   Bpntrh            ; save BASIC execute pointer high byte
    rts

; get two parameters for POKE or WAIT

LAB_GADB
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
    jsr   LAB_F2FX          ; save integer part of FAC1 in temporary integer

; scan for "," and get byte, else do Syntax error then warm start

LAB_SCGB
    jsr   LAB_1C01          ; scan for "," , else do syntax error then warm start
    lda   Itemph            ; save temporary integer high byte
    pha                     ; on stack
    lda   Itempl            ; save temporary integer low byte
    pha                     ; on stack
    jsr   LAB_GTBY          ; get byte parameter
    pla                     ; pull low byte
    sta   Itempl            ; restore temporary integer low byte
    pla                     ; pull high byte
    sta   Itemph            ; restore temporary integer high byte
    rts

; convert float to fixed routine. accepts any value that fits in 24 bits, +ve or
; -ve and converts it into a right truncated integer in Itempl and Itemph

; save unsigned 16 bit integer part of FAC1 in temporary integer

LAB_F2FX
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$98              ; compare with exponent = 2^24
    bcs   LAB_23A8          ; if >= do function call error then warm start

LAB_F2FU
    jsr   LAB_2831          ; convert FAC1 floating-to-fixed
    lda   FAC1_2            ; get FAC1 mantissa2
    ldy   FAC1_3            ; get FAC1 mantissa3
    sty   Itempl            ; save temporary integer low byte
    sta   Itemph            ; save temporary integer high byte
    rts

; perform PEEK()

LAB_PEEK
    jsr   LAB_F2FX          ; save integer part of FAC1 in temporary integer
    ldx   #$00              ; clear index
    lda   (Itempl,X)        ; get byte via temporary integer (addr)
    tay                     ; copy byte to Y
    jmp   LAB_1FD0          ; convert Y to byte in FAC1 and return

; perform POKE

basic_POKE
    jsr   LAB_GADB          ; get two parameters for POKE or WAIT
    txa                     ; copy byte argument to A
    ldx   #$00              ; clear index
    sta   (Itempl,X)        ; save byte via temporary integer (addr)
    rts

; perform DEEK()

LAB_DEEK
    jsr   LAB_F2FX          ; save integer part of FAC1 in temporary integer
    ldx   #$00              ; clear index
    lda   (Itempl,X)        ; PEEK low byte
    tay                     ; copy to Y
    inc   Itempl            ; increment pointer low byte
    bne   Deekh             ; skip high increment if no rollover

    inc   Itemph            ; increment pointer high byte
Deekh
    lda   (Itempl,X)        ; PEEK high byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform DOKE

basic_DOKE
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
    jsr   LAB_F2FX          ; convert floating-to-fixed

    sty   Frnxtl            ; save pointer low byte (float to fixed returns word in AY)
    sta   Frnxth            ; save pointer high byte

    jsr   LAB_1C01          ; scan for "," , else do syntax error then warm start
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
    jsr   LAB_F2FX          ; convert floating-to-fixed

    tya                     ; copy value low byte (float to fixed returns word in AY)
    ldx   #$00              ; clear index
    sta   (Frnxtl,X)        ; POKE low byte
    inc   Frnxtl            ; increment pointer low byte
    bne   Dokeh             ; skip high increment if no rollover

    inc   Frnxth            ; increment pointer high byte
Dokeh
    lda   Itemph            ; get value high byte
    sta   (Frnxtl,X)        ; POKE high byte
    jmp   LAB_GBYT          ; scan memory and return

; perform SWAP

basic_SWAP
    jsr   LAB_GVAR          ; get var1 address
    sta   Lvarpl            ; save var1 address low byte
    sty   Lvarph            ; save var1 address high byte
    lda   Dtypef            ; get data type flag, $FF=string, $00=numeric
    pha                     ; save data type flag

    jsr   LAB_1C01          ; scan for "," , else do syntax error then warm start
    jsr   LAB_GVAR          ; get var2 address (pointer in Cvaral/h)
    pla                     ; pull var1 data type flag
    eor   Dtypef            ; compare with var2 data type
    bpl   SwapErr           ; exit if not both the same type

    ldy   #$03              ; four bytes to swap (either value or descriptor+1)
SwapLp
    lda   (Lvarpl),Y        ; get byte from var1
    tax                     ; save var1 byte
    lda   (Cvaral),Y        ; get byte from var2
    sta   (Lvarpl),Y        ; save byte to var1
    txa                     ; restore var1 byte
    sta   (Cvaral),Y        ; save byte to var2
    dey                     ; decrement index
    bpl   SwapLp            ; loop until done

    rts

SwapErr
    jmp   LAB_1ABC          ; do "Type mismatch" error then warm start

; perform CALL

basic_CALL
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch
    jsr   LAB_F2FX          ; convert floating-to-fixed
    lda   #>CallExit        ; set return address high byte
    pha                     ; put on stack
    lda   #<CallExit-1      ; set return address low byte
    pha                     ; put on stack
    jmp   (Itempl)          ; do indirect jump to user routine

; if the called routine exits correctly then it will return to here. this will then get
; the next byte for the interpreter and return

CallExit
    jmp   LAB_GBYT          ; scan memory and return

; perform WAIT

basic_WAIT
    jsr   LAB_GADB          ; get two parameters for POKE or WAIT
    stx   Frnxtl            ; save byte
    ldx   #$00              ; clear mask
    jsr   LAB_GBYT          ; scan memory
    beq   LAB_2441          ; skip if no third argument

    jsr   LAB_SCGB          ; scan for "," and get byte, else SN error then warm start
LAB_2441
    stx   Frnxth            ; save EOR argument
LAB_2445
    lda   (Itempl),Y        ; get byte via temporary integer (addr)
    eor   Frnxth            ; EOR with second argument (mask)
    and   Frnxtl            ; AND with first argument (byte)
    beq   LAB_2445          ; loop if result is zero

LAB_244D
    rts

; perform subtraction, FAC1 from (AY)

LAB_2455
    jsr   LAB_264D          ; unpack memory (AY) into FAC2

; perform subtraction, FAC1 from FAC2

LAB_SUBTRACT
    lda   FAC1_s            ; get FAC1 sign (b7)
    eor   #$FF              ; complement it
    sta   FAC1_s            ; save FAC1 sign (b7)
    eor   FAC2_s            ; EOR with FAC2 sign (b7)
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    lda   FAC1_e            ; get FAC1 exponent
    jmp   LAB_ADD           ; go add FAC2 to FAC1

; perform addition

LAB_2467
    jsr   LAB_257B          ; shift FACX A times right (>8 shifts)
    bcc   LAB_24A8          ;.go subtract mantissas

; add 0.5 to FAC1

LAB_244E
    lda   #<LAB_2A96        ; set 0.5 pointer low byte
    ldy   #>LAB_2A96        ; set 0.5 pointer high byte

; add (AY) to FAC1

LAB_246C
    jsr   LAB_264D          ; unpack memory (AY) into FAC2

; add FAC2 to FAC1

LAB_ADD
    bne   LAB_2474          ; branch if FAC1 was not zero

; copy FAC2 to FAC1

LAB_279B
    lda   FAC2_s            ; get FAC2 sign (b7)

; save FAC1 sign and copy ABS(FAC2) to FAC1

LAB_279D
    sta   FAC1_s            ; save FAC1 sign (b7)
    ldx   #$04              ; 4 bytes to copy
LAB_27A1
    lda   FAC1_o,X          ; get byte from FAC2,X
    sta   FAC1_e-1,X        ; save byte at FAC1,X
    dex                     ; decrement count
    bne   LAB_27A1          ; loop if not all done

    stx   FAC1_r            ; clear FAC1 rounding byte
    rts

                              ; FAC1 is non zero
LAB_2474
    ldx   FAC1_r            ; get FAC1 rounding byte
    stx   FAC2_r            ; save as FAC2 rounding byte
    ldx   #FAC2_e           ; set index to FAC2 exponent addr
    lda   FAC2_e            ; get FAC2 exponent
LAB_247C
    tay                     ; copy exponent
    beq   LAB_244D          ; exit if zero

    sec                     ; set carry for subtract
    sbc   FAC1_e            ; subtract FAC1 exponent
    beq   LAB_24A8          ; branch if = (go add mantissa)

    bcc   LAB_2498          ; branch if <

                              ; FAC2>FAC1
    sty   FAC1_e            ; save FAC1 exponent
    ldy   FAC2_s            ; get FAC2 sign (b7)
    sty   FAC1_s            ; save FAC1 sign (b7)
    eor   #$FF              ; complement A
    adc   #$00              ; +1 (twos complement, carry is set)
    ldy   #$00              ; clear Y
    sty   FAC2_r            ; clear FAC2 rounding byte
    ldx   #FAC1_e           ; set index to FAC1 exponent addr
    bne   LAB_249C          ; branch always

LAB_2498
    ldy   #$00              ; clear Y
    sty   FAC1_r            ; clear FAC1 rounding byte
LAB_249C
    cmp   #$F9              ; compare exponent diff with $F9
    bmi   LAB_2467          ; branch if range $79-$F8

    tay                     ; copy exponent difference to Y
    lda   FAC1_r            ; get FAC1 rounding byte
    lsr   PLUS_1,X          ; shift FAC? mantissa1
    jsr   LAB_2592          ; shift FACX Y times right

                              ; exponents are equal now do mantissa subtract
LAB_24A8
    bit   FAC_sc            ; test sign compare (FAC1 EOR FAC2)
    bpl   LAB_24F8          ; if = add FAC2 mantissa to FAC1 mantissa and return

    ldy   #FAC1_e           ; set index to FAC1 exponent addr
    cpx   #FAC2_e           ; compare X to FAC2 exponent addr
    beq   LAB_24B4          ; branch if =

    ldy   #FAC2_e           ; else set index to FAC2 exponent addr

                              ; subtract smaller from bigger (take sign of bigger)
LAB_24B4
    sec                     ; set carry for subtract
    eor   #$FF              ; ones complement A
    adc   FAC2_r            ; add FAC2 rounding byte
    sta   FAC1_r            ; save FAC1 rounding byte
    lda   PLUS_3,Y          ; get FACY mantissa3
    sbc   PLUS_3,X          ; subtract FACX mantissa3
    sta   FAC1_3            ; save FAC1 mantissa3
    lda   PLUS_2,Y          ; get FACY mantissa2
    sbc   PLUS_2,X          ; subtract FACX mantissa2
    sta   FAC1_2            ; save FAC1 mantissa2
    lda   PLUS_1,Y          ; get FACY mantissa1
    sbc   PLUS_1,X          ; subtract FACX mantissa1
    sta   FAC1_1            ; save FAC1 mantissa1

; do ABS and normalise FAC1

LAB_24D0
    bcs   LAB_24D5          ; branch if number is +ve

    jsr   LAB_2537          ; negate FAC1

; normalise FAC1

LAB_24D5
    ldy   #$00              ; clear Y
    tya                     ; clear A
    clc                     ; clear carry for add
LAB_24D9
    ldx   FAC1_1            ; get FAC1 mantissa1
    bne   LAB_251B          ; if not zero normalise FAC1

    ldx   FAC1_2            ; get FAC1 mantissa2
    stx   FAC1_1            ; save FAC1 mantissa1
    ldx   FAC1_3            ; get FAC1 mantissa3
    stx   FAC1_2            ; save FAC1 mantissa2
    ldx   FAC1_r            ; get FAC1 rounding byte
    stx   FAC1_3            ; save FAC1 mantissa3
    sty   FAC1_r            ; clear FAC1 rounding byte
    adc   #$08              ; add x to exponent offset
    cmp   #$18              ; compare with $18 (max offset, all bits would be =0)
    bne   LAB_24D9          ; loop if not max

; clear FAC1 exponent and sign

LAB_24F1
    lda   #$00              ; clear A
LAB_24F3
    sta   FAC1_e            ; set FAC1 exponent

; save FAC1 sign
LAB_24F5
    sta   FAC1_s            ; save FAC1 sign (b7)
    rts

; add FAC2 mantissa to FAC1 mantissa
LAB_24F8
    adc   FAC2_r            ; add FAC2 rounding byte
    sta   FAC1_r            ; save FAC1 rounding byte
    lda   FAC1_3            ; get FAC1 mantissa3
    adc   FAC2_3            ; add FAC2 mantissa3
    sta   FAC1_3            ; save FAC1 mantissa3
    lda   FAC1_2            ; get FAC1 mantissa2
    adc   FAC2_2            ; add FAC2 mantissa2
    sta   FAC1_2            ; save FAC1 mantissa2
    lda   FAC1_1            ; get FAC1 mantissa1
    adc   FAC2_1            ; add FAC2 mantissa1
    sta   FAC1_1            ; save FAC1 mantissa1
    bcs   LAB_252A          ; if carry then normalise FAC1 for C=1
    rts                     ; else just exit

LAB_2511
    adc   #$01              ; add 1 to exponent offset
    asl   FAC1_r            ; shift FAC1 rounding byte
    rol   FAC1_3            ; shift FAC1 mantissa3
    rol   FAC1_2            ; shift FAC1 mantissa2
    rol   FAC1_1            ; shift FAC1 mantissa1

; normalise FAC1
LAB_251B
    bpl   LAB_2511          ; loop if not normalised

    sec                     ; set carry for subtract
    sbc   FAC1_e            ; subtract FAC1 exponent
    bcs   LAB_24F1          ; branch if underflow (set result = $0)

    eor   #$FF              ; complement exponent
    adc   #$01              ; +1 (twos complement)
    sta   FAC1_e            ; save FAC1 exponent

; test and normalise FAC1 for C=0/1
LAB_2528
    bcc   LAB_2536          ; exit if no overflow

; normalise FAC1 for C=1
LAB_252A
    inc   FAC1_e            ; increment FAC1 exponent
    beq   LAB_2564          ; if zero do overflow error and warm start

    ror   FAC1_1            ; shift FAC1 mantissa1
    ror   FAC1_2            ; shift FAC1 mantissa2
    ror   FAC1_3            ; shift FAC1 mantissa3
    ror   FAC1_r            ; shift FAC1 rounding byte
LAB_2536
    rts

; negate FAC1
LAB_2537
    lda   FAC1_s            ; get FAC1 sign (b7)
    eor   #$FF              ; complement it
    sta   FAC1_s            ; save FAC1 sign (b7)

; twos complement FAC1 mantissa
LAB_253D
    lda   FAC1_1            ; get FAC1 mantissa1
    eor   #$FF              ; complement it
    sta   FAC1_1            ; save FAC1 mantissa1
    lda   FAC1_2            ; get FAC1 mantissa2
    eor   #$FF              ; complement it
    sta   FAC1_2            ; save FAC1 mantissa2
    lda   FAC1_3            ; get FAC1 mantissa3
    eor   #$FF              ; complement it
    sta   FAC1_3            ; save FAC1 mantissa3
    lda   FAC1_r            ; get FAC1 rounding byte
    eor   #$FF              ; complement it
    sta   FAC1_r            ; save FAC1 rounding byte
    inc   FAC1_r            ; increment FAC1 rounding byte
    bne   LAB_2563          ; exit if no overflow

; increment FAC1 mantissa
LAB_2559
    inc   FAC1_3            ; increment FAC1 mantissa3
    bne   LAB_2563          ; finished if no rollover

    inc   FAC1_2            ; increment FAC1 mantissa2
    bne   LAB_2563          ; finished if no rollover

    inc   FAC1_1            ; increment FAC1 mantissa1
LAB_2563
    rts

; do overflow error (overflow exit)
LAB_2564
    ldx   #$0A              ; error code $0A ("Overflow" error)
    jmp   LAB_XERR          ; do error #X, then warm start

; shift FCAtemp << A+8 times
LAB_2569
    ldx   #FACt_1-1         ; set offset to FACtemp
LAB_256B
    ldy   PLUS_3,X          ; get FACX mantissa3
    sty   FAC1_r            ; save as FAC1 rounding byte
    ldy   PLUS_2,X          ; get FACX mantissa2
    sty   PLUS_3,X          ; save FACX mantissa3
    ldy   PLUS_1,X          ; get FACX mantissa1
    sty   PLUS_2,X          ; save FACX mantissa2
    ldy   FAC1_o            ; get FAC1 overflow byte
    sty   PLUS_1,X          ; save FACX mantissa1

; shift FACX -A times right (> 8 shifts)

LAB_257B
    adc   #$08              ; add 8 to shift count
    bmi   LAB_256B          ; go do 8 shift if still -ve

    beq   LAB_256B          ; go do 8 shift if zero

    sbc   #$08              ; else subtract 8 again
    tay                     ; save count to Y
    lda   FAC1_r            ; get FAC1 rounding byte
    bcs   LAB_259A          ;.

LAB_2588
    asl   PLUS_1,X          ; shift FACX mantissa1
    bcc   LAB_258E          ; branch if +ve

    inc   PLUS_1,X          ; this sets b7 eventually
LAB_258E
    ror   PLUS_1,X          ; shift FACX mantissa1 (correct for ASL)
    ror   PLUS_1,X          ; shift FACX mantissa1 (put carry in b7)

; shift FACX Y times right

LAB_2592
    ror   PLUS_2,X          ; shift FACX mantissa2
    ror   PLUS_3,X          ; shift FACX mantissa3
    ror                     ; shift FACX rounding byte
    iny                     ; increment exponent diff
    bne   LAB_2588          ; branch if range adjust not complete

LAB_259A
    clc                     ; just clear it
    rts

; perform LOG()

LAB_LOG
    jsr   LAB_27CA          ; test sign and zero
    beq   LAB_25C4          ; if zero do function call error then warm start

    bpl   LAB_25C7          ; skip error if +ve

LAB_25C4
    jmp   LAB_FCER          ; do function call error then warm start (-ve)

LAB_25C7
    lda   FAC1_e            ; get FAC1 exponent
    sbc   #$7F              ; normalise it
    pha                     ; save it
    lda   #$80              ; set exponent to zero
    sta   FAC1_e            ; save FAC1 exponent
    lda   #<LAB_25AD        ; set 1/root2 pointer low byte
    ldy   #>LAB_25AD        ; set 1/root2 pointer high byte
    jsr   LAB_246C          ; add (AY) to FAC1 (1/root2)
    lda   #<LAB_25B1        ; set root2 pointer low byte
    ldy   #>LAB_25B1        ; set root2 pointer high byte
    jsr   LAB_26CA          ; convert AY and do (AY)/FAC1 (root2/(x+(1/root2)))
    lda   #<LAB_259C        ; set 1 pointer low byte
    ldy   #>LAB_259C        ; set 1 pointer high byte
    jsr   LAB_2455          ; subtract (AY) from FAC1 ((root2/(x+(1/root2)))-1)
    lda   #<LAB_25A0        ; set pointer low byte to counter
    ldy   #>LAB_25A0        ; set pointer high byte to counter
    jsr   LAB_2B6E          ; ^2 then series evaluation
    lda   #<LAB_25B5        ; set -0.5 pointer low byte
    ldy   #>LAB_25B5        ; set -0.5 pointer high byte
    jsr   LAB_246C          ; add (AY) to FAC1
    pla                     ; restore FAC1 exponent
    jsr   LAB_2912          ; evaluate new ASCII digit
    lda   #<LAB_25B9        ; set LOG(2) pointer low byte
    ldy   #>LAB_25B9        ; set LOG(2) pointer high byte

; do convert AY, FCA1*(AY)

LAB_25FB
    jsr   LAB_264D          ; unpack memory (AY) into FAC2
LAB_MULTIPLY
    beq   LAB_264C          ; exit if zero

    jsr   LAB_2673          ; test and adjust accumulators
    lda   #$00              ; clear A
    sta   FACt_1            ; clear temp mantissa1
    sta   FACt_2            ; clear temp mantissa2
    sta   FACt_3            ; clear temp mantissa3
    lda   FAC1_r            ; get FAC1 rounding byte
    jsr   LAB_2622          ; go do shift/add FAC2
    lda   FAC1_3            ; get FAC1 mantissa3
    jsr   LAB_2622          ; go do shift/add FAC2
    lda   FAC1_2            ; get FAC1 mantissa2
    jsr   LAB_2622          ; go do shift/add FAC2
    lda   FAC1_1            ; get FAC1 mantissa1
    jsr   LAB_2627          ; go do shift/add FAC2
    jmp   LAB_273C          ; copy temp to FAC1, normalise and return

LAB_2622
    bne   LAB_2627          ; branch if byte <> zero
; *** begin patch  2.22p5.6  floating point multiply rounding bug
; *** replace
;      JMP   LAB_2569          ; shift FCAtemp << A+8 times
;
;                              ; else do shift and add
;LAB_2627
;      LSR                     ; shift byte
;      ORA   #$80              ; set top bit (mark for 8 times)
; *** with
      SEC
    jmp   LAB_2569          ; shift FACtemp << A+8 times

                              ; else do shift and add
LAB_2627
    sec                     ; set top bit (mark for 8 times)
      ROR
; *** end patch    2.22p5.6  floating point multiply rounding bug
LAB_262A
    tay                     ; copy result
    bcc   LAB_2640          ; skip next if bit was zero

    clc                     ; clear carry for add
    lda   FACt_3            ; get temp mantissa3
    adc   FAC2_3            ; add FAC2 mantissa3
    sta   FACt_3            ; save temp mantissa3
    lda   FACt_2            ; get temp mantissa2
    adc   FAC2_2            ; add FAC2 mantissa2
    sta   FACt_2            ; save temp mantissa2
    lda   FACt_1            ; get temp mantissa1
    adc   FAC2_1            ; add FAC2 mantissa1
    sta   FACt_1            ; save temp mantissa1
LAB_2640
    ror   FACt_1            ; shift temp mantissa1
    ror   FACt_2            ; shift temp mantissa2
    ror   FACt_3            ; shift temp mantissa3
    ror   FAC1_r            ; shift temp rounding byte
    tya                     ; get byte back
    lsr                     ; shift byte
    bne   LAB_262A          ; loop if all bits not done

LAB_264C
    rts

; unpack memory (AY) into FAC2

LAB_264D
    sta   ut1_pl            ; save pointer low byte
    sty   ut1_ph            ; save pointer high byte
    ldy   #$03              ; 4 bytes to get (0-3)
    lda   (ut1_pl),Y        ; get mantissa3
    sta   FAC2_3            ; save FAC2 mantissa3
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get mantissa2
    sta   FAC2_2            ; save FAC2 mantissa2
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get mantissa1+sign
    sta   FAC2_s            ; save FAC2 sign (b7)
    eor   FAC1_s            ; EOR with FAC1 sign (b7)
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    lda   FAC2_s            ; recover FAC2 sign (b7)
    ora   #$80              ; set 1xxx xxx (set normal bit)
    sta   FAC2_1            ; save FAC2 mantissa1
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get exponent byte
    sta   FAC2_e            ; save FAC2 exponent
    lda   FAC1_e            ; get FAC1 exponent
    rts

; test and adjust accumulators

LAB_2673
    lda   FAC2_e            ; get FAC2 exponent
LAB_2675
    beq   LAB_2696          ; branch if FAC2 = $00 (handle underflow)

    clc                     ; clear carry for add
    adc   FAC1_e            ; add FAC1 exponent
    bcc   LAB_2680          ; branch if sum of exponents <$0100

    bmi   LAB_269B          ; do overflow error

    clc                     ; clear carry for the add
      .byte $2C               ; makes next line BIT $1410
LAB_2680
    bpl   LAB_2696          ; if +ve go handle underflow

    adc   #$80              ; adjust exponent
    sta   FAC1_e            ; save FAC1 exponent
    bne   LAB_268B          ; branch if not zero

    jmp   LAB_24F5          ; save FAC1 sign and return

LAB_268B
    lda   FAC_sc            ; get sign compare (FAC1 EOR FAC2)
    sta   FAC1_s            ; save FAC1 sign (b7)
LAB_268F
    rts

; handle overflow and underflow

LAB_2690
    lda   FAC1_s            ; get FAC1 sign (b7)
    bpl   LAB_269B          ; do overflow error

                              ; handle underflow
LAB_2696
    pla                     ; pop return address low byte
    pla                     ; pop return address high byte
    jmp   LAB_24F1          ; clear FAC1 exponent and sign and return

; multiply by 10

LAB_269E
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    tax                     ; copy exponent (set the flags)
    beq   LAB_268F          ; exit if zero

    clc                     ; clear carry for add
    adc   #$02              ; add two to exponent (*4)
    bcs   LAB_269B          ; do overflow error if > $FF

    ldx   #$00              ; clear byte
    stx   FAC_sc            ; clear sign compare (FAC1 EOR FAC2)
    jsr   LAB_247C          ; add FAC2 to FAC1 (*5)
    inc   FAC1_e            ; increment FAC1 exponent (*10)
    bne   LAB_268F          ; if non zero just do RTS

LAB_269B
    jmp   LAB_2564          ; do overflow error and warm start

; divide by 10

LAB_26B9
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    lda   #<LAB_26B5        ; set pointer to 10d low addr
    ldy   #>LAB_26B5        ; set pointer to 10d high addr
    ldx   #$00              ; clear sign

; divide by (AY) (X=sign)

LAB_26C2
    stx   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    jsr   LAB_UFAC          ; unpack memory (AY) into FAC1
    jmp   LAB_DIVIDE        ; do FAC2/FAC1

                              ; Perform divide-by
; convert AY and do (AY)/FAC1

LAB_26CA
    jsr   LAB_264D          ; unpack memory (AY) into FAC2

                              ; Perform divide-into
LAB_DIVIDE
    beq   LAB_2737          ; if zero go do /0 error

    jsr   LAB_27BA          ; round FAC1
    lda   #$00              ; clear A
    sec                     ; set carry for subtract
    sbc   FAC1_e            ; subtract FAC1 exponent (2s complement)
    sta   FAC1_e            ; save FAC1 exponent
    jsr   LAB_2673          ; test and adjust accumulators
    inc   FAC1_e            ; increment FAC1 exponent
    beq   LAB_269B          ; if zero do overflow error

    ldx   #$FF              ; set index for pre increment
    lda   #$01              ; set bit to flag byte save
LAB_26E4
    ldy   FAC2_1            ; get FAC2 mantissa1
    cpy   FAC1_1            ; compare FAC1 mantissa1
    bne   LAB_26F4          ; branch if <>

    ldy   FAC2_2            ; get FAC2 mantissa2
    cpy   FAC1_2            ; compare FAC1 mantissa2
    bne   LAB_26F4          ; branch if <>

    ldy   FAC2_3            ; get FAC2 mantissa3
    cpy   FAC1_3            ; compare FAC1 mantissa3
LAB_26F4
    php                     ; save FAC2-FAC1 compare status
    rol                     ; shift the result byte
    bcc   LAB_2702          ; if no carry skip the byte save

    ldy   #$01              ; set bit to flag byte save
    inx                     ; else increment the index to FACt
    cpx   #$02              ; compare with the index to FACt_3
    bmi   LAB_2701          ; if not last byte just go save it

    bne   LAB_272B          ; if all done go save FAC1 rounding byte, normalise and
                              ; return

    ldy   #$40              ; set bit to flag byte save for the rounding byte
LAB_2701
    sta   FACt_1,X          ; write result byte to FACt_1 + index
    tya                     ; copy the next save byte flag
LAB_2702
    plp                     ; restore FAC2-FAC1 compare status
    bcc   LAB_2704          ; if FAC2 < FAC1 then skip the subtract

    tay                     ; save FAC2-FAC1 compare status
    lda   FAC2_3            ; get FAC2 mantissa3
    sbc   FAC1_3            ; subtract FAC1 mantissa3
    sta   FAC2_3            ; save FAC2 mantissa3
    lda   FAC2_2            ; get FAC2 mantissa2
    sbc   FAC1_2            ; subtract FAC1 mantissa2
    sta   FAC2_2            ; save FAC2 mantissa2
    lda   FAC2_1            ; get FAC2 mantissa1
    sbc   FAC1_1            ; subtract FAC1 mantissa1
    sta   FAC2_1            ; save FAC2 mantissa1
    tya                     ; restore FAC2-FAC1 compare status

                              ; FAC2 = FAC2*2
LAB_2704
    asl   FAC2_3            ; shift FAC2 mantissa3
    rol   FAC2_2            ; shift FAC2 mantissa2
    rol   FAC2_1            ; shift FAC2 mantissa1
    bcs   LAB_26F4          ; loop with no compare

    bmi   LAB_26E4          ; loop with compare

    bpl   LAB_26F4          ; loop always with no compare

; do A<<6, save as FAC1 rounding byte, normalise and return

LAB_272B
    lsr                     ; shift b1 - b0 ..
    ror                     ; ..
    ror                     ; .. to b7 - b6
    sta   FAC1_r            ; save FAC1 rounding byte
    plp                     ; dump FAC2-FAC1 compare status
    jmp   LAB_273C          ; copy temp to FAC1, normalise and return

; do "Divide by zero" error

LAB_2737
    ldx   #$14              ; error code $14 ("Divide by zero" error)
    jmp   LAB_XERR          ; do error #X, then warm start

; copy temp to FAC1 and normalise

LAB_273C
    lda   FACt_1            ; get temp mantissa1
    sta   FAC1_1            ; save FAC1 mantissa1
    lda   FACt_2            ; get temp mantissa2
    sta   FAC1_2            ; save FAC1 mantissa2
    lda   FACt_3            ; get temp mantissa3
    sta   FAC1_3            ; save FAC1 mantissa3
    jmp   LAB_24D5          ; normalise FAC1 and return

; unpack memory (AY) into FAC1

LAB_UFAC
    sta   ut1_pl            ; save pointer low byte
    sty   ut1_ph            ; save pointer high byte
    ldy   #$03              ; 4 bytes to do
    lda   (ut1_pl),Y        ; get last byte
    sta   FAC1_3            ; save FAC1 mantissa3
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get last-1 byte
    sta   FAC1_2            ; save FAC1 mantissa2
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get second byte
    sta   FAC1_s            ; save FAC1 sign (b7)
    ora   #$80              ; set 1xxx xxxx (add normal bit)
    sta   FAC1_1            ; save FAC1 mantissa1
    dey                     ; decrement index
    lda   (ut1_pl),Y        ; get first byte (exponent)
    sta   FAC1_e            ; save FAC1 exponent
    sty   FAC1_r            ; clear FAC1 rounding byte
    rts

; pack FAC1 into Adatal

LAB_276E
    ldx   #<Adatal          ; set pointer low byte
LAB_2770
    ldy   #>Adatal          ; set pointer high byte
    beq   LAB_2778          ; pack FAC1 into (XY) and return

; pack FAC1 into (Lvarpl)

LAB_PFAC
    ldx   Lvarpl            ; get destination pointer low byte
    ldy   Lvarph            ; get destination pointer high byte

; pack FAC1 into (XY)

LAB_2778
    jsr   LAB_27BA          ; round FAC1
    stx   ut1_pl            ; save pointer low byte
    sty   ut1_ph            ; save pointer high byte
    ldy   #$03              ; set index
    lda   FAC1_3            ; get FAC1 mantissa3
    sta   (ut1_pl),Y        ; store in destination
    dey                     ; decrement index
    lda   FAC1_2            ; get FAC1 mantissa2
    sta   (ut1_pl),Y        ; store in destination
    dey                     ; decrement index
    lda   FAC1_s            ; get FAC1 sign (b7)
    ora   #$7F              ; set bits x111 1111
    and   FAC1_1            ; AND in FAC1 mantissa1
    sta   (ut1_pl),Y        ; store in destination
    dey                     ; decrement index
    lda   FAC1_e            ; get FAC1 exponent
    sta   (ut1_pl),Y        ; store in destination
    sty   FAC1_r            ; clear FAC1 rounding byte
    rts

; round and copy FAC1 to FAC2

LAB_27AB
    jsr   LAB_27BA          ; round FAC1

; copy FAC1 to FAC2

LAB_27AE
    ldx   #$05              ; 5 bytes to copy
LAB_27B0
    lda   FAC1_e-1,X        ; get byte from FAC1,X
    sta   FAC1_o,X          ; save byte at FAC2,X
    dex                     ; decrement count
    bne   LAB_27B0          ; loop if not all done

    stx   FAC1_r            ; clear FAC1 rounding byte
LAB_27B9
    rts

; round FAC1

LAB_27BA
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_27B9          ; exit if zero

    asl   FAC1_r            ; shift FAC1 rounding byte
    bcc   LAB_27B9          ; exit if no overflow

; round FAC1 (no check)

LAB_27C2
    jsr   LAB_2559          ; increment FAC1 mantissa
    bne   LAB_27B9          ; branch if no overflow

    jmp   LAB_252A          ; normalise FAC1 for C=1 and return

; get FAC1 sign
; return A=FF,C=1/-ve A=01,C=0/+ve

LAB_27CA:
    lda FAC1_e            ; get FAC1 exponent
    beq LAB_27D7          ; exit if zero (already correct SGN(0)=0)

; return A=FF,C=1/-ve A=01,C=0/+ve
; no = 0 check

LAB_27CE:
    lda FAC1_s            ; else get FAC1 sign (b7)

; return A=FF,C=1/-ve A=01,C=0/+ve
; no = 0 check, sign in A

LAB_27D0:
    rol                     ; move sign bit to carry
    lda #$FF              ; set byte for -ve result
    bcs LAB_27D7          ; return if sign was set (-ve)

    lda #$01              ; else set byte for +ve result
LAB_27D7:
    rts

; perform SGN()

basic_SGN:
    jsr LAB_27CA          ; get FAC1 sign
                              ; return A=$FF/-ve A=$01/+ve
; save A as integer byte

LAB_27DB:
    sta FAC1_1            ; save FAC1 mantissa1
    lda #$00              ; clear A
    sta FAC1_2            ; clear FAC1 mantissa2
    ldx #$88              ; set exponent

; set exp=X, clearFAC1 mantissa3 and normalise

LAB_27E3:
    lda FAC1_1            ; get FAC1 mantissa1
    eor #$FF              ; complement it
    rol                     ; sign bit into carry

; set exp=X, clearFAC1 mantissa3 and normalise

LAB_STFA:
    lda #$00              ; clear A
    sta FAC1_3            ; clear FAC1 mantissa3
    stx FAC1_e            ; set FAC1 exponent
    sta FAC1_r            ; clear FAC1 rounding byte
    sta FAC1_s            ; clear FAC1 sign (b7)
    jmp LAB_24D0          ; do ABS and normalise FAC1

; perform ABS()
func_ABS:
    lsr FAC1_s            ; clear FAC1 sign (put zero in b7)
    rts

; compare FAC1 with (AY)
; returns A=$00 if FAC1 = (AY)
; returns A=$01 if FAC1 > (AY)
; returns A=$FF if FAC1 < (AY)
LAB_27F8
    sta   ut2_pl            ; save pointer low byte
LAB_27FA
    sty   ut2_ph            ; save pointer high byte
    ldy   #$00              ; clear index
    lda   (ut2_pl),Y        ; get exponent
    iny                     ; increment index
    tax                     ; copy (AY) exponent to X
    beq   LAB_27CA          ; branch if (AY) exponent=0 and get FAC1 sign
                              ; A=FF,C=1/-ve A=01,C=0/+ve

    lda   (ut2_pl),Y        ; get (AY) mantissa1 (with sign)
    eor   FAC1_s            ; EOR FAC1 sign (b7)
    bmi   LAB_27CE          ; if signs <> do return A=FF,C=1/-ve
                              ; A=01,C=0/+ve and return

    cpx   FAC1_e            ; compare (AY) exponent with FAC1 exponent
    bne   LAB_2828          ; branch if different

    lda   (ut2_pl),Y        ; get (AY) mantissa1 (with sign)
    ora   #$80              ; normalise top bit
    cmp   FAC1_1            ; compare with FAC1 mantissa1
    bne   LAB_2828          ; branch if different

    iny                     ; increment index
    lda   (ut2_pl),Y        ; get mantissa2
    cmp   FAC1_2            ; compare with FAC1 mantissa2
    bne   LAB_2828          ; branch if different

    iny                     ; increment index
    lda   #$7F              ; set for 1/2 value rounding byte
    cmp   FAC1_r            ; compare with FAC1 rounding byte (set carry)
    lda   (ut2_pl),Y        ; get mantissa3
    sbc   FAC1_3            ; subtract FAC1 mantissa3
    beq   LAB_2850          ; exit if mantissa3 equal

; gets here if number <> FAC1

LAB_2828
    lda   FAC1_s            ; get FAC1 sign (b7)
    bcc   LAB_282E          ; branch if FAC1 > (AY)

    eor   #$FF              ; else toggle FAC1 sign
LAB_282E
    jmp   LAB_27D0          ; return A=FF,C=1/-ve A=01,C=0/+ve

; convert FAC1 floating-to-fixed

LAB_2831
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_287F          ; if zero go clear FAC1 and return

    sec                     ; set carry for subtract
    sbc   #$98              ; subtract maximum integer range exponent
    bit   FAC1_s            ; test FAC1 sign (b7)
    bpl   LAB_2845          ; branch if FAC1 +ve

                              ; FAC1 was -ve
    tax                     ; copy subtracted exponent
    lda   #$FF              ; overflow for -ve number
    sta   FAC1_o            ; set FAC1 overflow byte
    jsr   LAB_253D          ; twos complement FAC1 mantissa
    txa                     ; restore subtracted exponent
LAB_2845
    ldx   #FAC1_e           ; set index to FAC1
    cmp   #$F9              ; compare exponent result
    bpl   LAB_2851          ; if < 8 shifts shift FAC1 A times right and return

    jsr   LAB_257B          ; shift FAC1 A times right (> 8 shifts)
    sty   FAC1_o            ; clear FAC1 overflow byte
LAB_2850
    rts

; shift FAC1 A times right

LAB_2851
    tay                     ; copy shift count
    lda   FAC1_s            ; get FAC1 sign (b7)
    and   #$80              ; mask sign bit only (x000 0000)
    lsr   FAC1_1            ; shift FAC1 mantissa1
    ora   FAC1_1            ; OR sign in b7 FAC1 mantissa1
    sta   FAC1_1            ; save FAC1 mantissa1
    jsr   LAB_2592          ; shift FAC1 Y times right
    sty   FAC1_o            ; clear FAC1 overflow byte
    rts

; perform INT()

LAB_INT
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$98              ; compare with max int
    bcs   LAB_2886          ; exit if >= (already int, too big for fractional part!)

    jsr   LAB_2831          ; convert FAC1 floating-to-fixed
    sty   FAC1_r            ; save FAC1 rounding byte
    lda   FAC1_s            ; get FAC1 sign (b7)
    sty   FAC1_s            ; save FAC1 sign (b7)
    eor   #$80              ; toggle FAC1 sign
    rol                     ; shift into carry
    lda   #$98              ; set new exponent
    sta   FAC1_e            ; save FAC1 exponent
    lda   FAC1_3            ; get FAC1 mantissa3
    sta   Temp3             ; save for EXP() function
    jmp   LAB_24D0          ; do ABS and normalise FAC1

; clear FAC1 and return

LAB_287F
    sta   FAC1_1            ; clear FAC1 mantissa1
    sta   FAC1_2            ; clear FAC1 mantissa2
    sta   FAC1_3            ; clear FAC1 mantissa3
    tay                     ; clear Y
LAB_2886
    rts

; get FAC1 from string
; this routine now handles hex and binary values from strings
; starting with "$" and "%" respectively

LAB_2887
    ldy   #$00              ; clear Y
    sty   Dtypef            ; clear data type flag, $FF=string, $00=numeric
    ldx   #$09              ; set index
LAB_288B
    sty   numexp,X          ; clear byte
    dex                     ; decrement index
    bpl   LAB_288B          ; loop until numexp to negnum (and FAC1) = $00

    bcc   LAB_28FE          ; branch if 1st character numeric

; get FAC1 from string .. first character wasn't numeric

    cmp   #'-'              ; else compare with "-"
    bne   LAB_289A          ; branch if not "-"

    stx   negnum            ; set flag for -ve number (X = $FF)
    beq   LAB_289C          ; branch always (go scan and check for hex/bin)

; get FAC1 from string .. first character wasn't numeric or -

LAB_289A
    cmp   #'+'              ; else compare with "+"
    bne   LAB_289D          ; branch if not "+" (go check for hex/bin)

; was "+" or "-" to start, so get next character

LAB_289C
    jsr   LAB_IGBY          ; increment and scan memory
    bcc   LAB_28FE          ; branch if numeric character

; code here for hex and binary numbers

LAB_289D
    cmp   #'$'              ; else compare with "$"
    bne   LAB_NHEX          ; branch if not "$"

    jmp   LAB_CHEX          ; branch if "$"

LAB_NHEX
    cmp   #'%'              ; else compare with "%"
    bne   LAB_28A3          ; branch if not "%" (continue original code)

    jmp   LAB_CBIN          ; branch if "%"

LAB_289E
    jsr   LAB_IGBY          ; increment and scan memory (ignore + or get next number)
LAB_28A1
    bcc   LAB_28FE          ; branch if numeric character

; get FAC1 from string .. character wasn't numeric, -, +, hex or binary

LAB_28A3
    cmp   #'.'              ; else compare with "."
    beq   LAB_28D5          ; branch if "."

; get FAC1 from string .. character wasn't numeric, -, + or .

    cmp   #'E'              ; else compare with "E"
    bne   LAB_28DB          ; branch if not "E"

                              ; was "E" so evaluate exponential part
    jsr   LAB_IGBY          ; increment and scan memory
    bcc   LAB_28C7          ; branch if numeric character

    cmp   #token_MINUS         ; else compare with token for -
    beq   LAB_28C2          ; branch if token for -

    cmp   #'-'              ; else compare with "-"
    beq   LAB_28C2          ; branch if "-"

    cmp   #token_PLUS          ; else compare with token for +
    beq   LAB_28C4          ; branch if token for +

    cmp   #'+'              ; else compare with "+"
    beq   LAB_28C4          ; branch if "+"

    bne   LAB_28C9          ; branch always

LAB_28C2
    ror   expneg            ; set exponent -ve flag (C, which=1, into b7)
LAB_28C4
    jsr   LAB_IGBY          ; increment and scan memory
LAB_28C7
    bcc   LAB_2925          ; branch if numeric character

LAB_28C9
    bit   expneg            ; test exponent -ve flag
    bpl   LAB_28DB          ; if +ve go evaluate exponent

                              ; else do exponent = -exponent
    lda   #$00              ; clear result
    sec                     ; set carry for subtract
    sbc   expcnt            ; subtract exponent byte
    jmp   LAB_28DD          ; go evaluate exponent

LAB_28D5
    ror   numdpf            ; set decimal point flag
    bit   numdpf            ; test decimal point flag
    bvc   LAB_289E          ; branch if only one decimal point so far

                              ; evaluate exponent
LAB_28DB
    lda   expcnt            ; get exponent count byte
LAB_28DD
    sec                     ; set carry for subtract
    sbc   numexp            ; subtract numerator exponent
    sta   expcnt            ; save exponent count byte
    beq   LAB_28F6          ; branch if no adjustment

    bpl   LAB_28EF          ; else if +ve go do FAC1*10^expcnt

                              ; else go do FAC1/10^(0-expcnt)
LAB_28E6
    jsr   LAB_26B9          ; divide by 10
    inc   expcnt            ; increment exponent count byte
    bne   LAB_28E6          ; loop until all done

    beq   LAB_28F6          ; branch always

LAB_28EF
    jsr   LAB_269E          ; multiply by 10
    dec   expcnt            ; decrement exponent count byte
    bne   LAB_28EF          ; loop until all done

LAB_28F6
    lda   negnum            ; get -ve flag
    bmi   LAB_28FB          ; if -ve do - FAC1 and return

    rts

; do - FAC1 and return

LAB_28FB
    jmp   LAB_GTHAN         ; do - FAC1 and return

; do unsigned FAC1*10+number

LAB_28FE
    pha                     ; save character
    bit   numdpf            ; test decimal point flag
    bpl   LAB_2905          ; skip exponent increment if not set

    inc   numexp            ; else increment number exponent
LAB_2905
    jsr   LAB_269E          ; multiply FAC1 by 10
    pla                     ; restore character
    and   #$0F              ; convert to binary
    jsr   LAB_2912          ; evaluate new ASCII digit
    jmp   LAB_289E          ; go do next character

; evaluate new ASCII digit

LAB_2912
    pha                     ; save digit
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    pla                     ; restore digit
    jsr   LAB_27DB          ; save A as integer byte
    lda   FAC2_s            ; get FAC2 sign (b7)
    eor   FAC1_s            ; toggle with FAC1 sign (b7)
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    ldx   FAC1_e            ; get FAC1 exponent
    jmp   LAB_ADD           ; add FAC2 to FAC1 and return

; evaluate next character of exponential part of number

LAB_2925
    lda   expcnt            ; get exponent count byte
    cmp   #$0A              ; compare with 10 decimal
    bcc   LAB_2934          ; branch if less

    lda   #$64              ; make all -ve exponents = -100 decimal (causes underflow)
    bit   expneg            ; test exponent -ve flag
    bmi   LAB_2942          ; branch if -ve

    jmp   LAB_2564          ; else do overflow error

LAB_2934
    asl                     ; * 2
    asl                     ; * 4
    adc   expcnt            ; * 5
    asl                     ; * 10
    ldy   #$00              ; set index
    adc   (Bpntrl),Y        ; add character (will be $30 too much!)
    sbc   #'0'-1            ; convert character to binary
LAB_2942
    sta   expcnt            ; save exponent count byte
    jmp   LAB_28C4          ; go get next character

; print " in line [LINE #]"

LAB_2953
    lda   #<LAB_LMSG        ; point to " in line " message low byte
    ldy   #>LAB_LMSG        ; point to " in line " message high byte
    jsr   print_string          ; print null terminated string from memory

                              ; print Basic line #
    lda   Clineh            ; get current line high byte
    ldx   Clinel            ; get current line low byte

; print XA as unsigned integer

LAB_295E
    sta   FAC1_1            ; save low byte as FAC1 mantissa1
    stx   FAC1_2            ; save high byte as FAC1 mantissa2
    ldx   #$90              ; set exponent to 16d bits
    sec                     ; set integer is +ve flag
    jsr   LAB_STFA          ; set exp=X, clearFAC1 mantissa3 and normalise
    ldy   #$00              ; clear index
    tya                     ; clear A
    jsr   LAB_297B          ; convert FAC1 to string, skip sign character save
    jmp   print_string          ; print null terminated string from memory and return

; convert FAC1 to ASCII string result in (AY)
; not any more, moved scratchpad to page 0

LAB_296E
    ldy   #$01              ; set index = 1
    lda   #$20              ; character = " " (assume +ve)
    bit   FAC1_s            ; test FAC1 sign (b7)
    bpl   LAB_2978          ; branch if +ve

    lda   #$2D              ; else character = "-"
LAB_2978
    sta   Decss,Y           ; save leading character (" " or "-")
LAB_297B
    sta   FAC1_s            ; clear FAC1 sign (b7)
    sty   Sendl             ; save index
    iny                     ; increment index
    ldx   FAC1_e            ; get FAC1 exponent
    bne   LAB_2989          ; branch if FAC1<>0

                              ; exponent was $00 so FAC1 is 0
    lda   #'0'              ; set character = "0"
    jmp   LAB_2A89          ; save last character, [EOT] and exit

                              ; FAC1 is some non zero value
LAB_2989
    lda   #$00              ; clear (number exponent count)
    cpx   #$81              ; compare FAC1 exponent with $81 (>1.00000)

    bcs   LAB_299A          ; branch if FAC1=>1

                              ; FAC1<1
    lda   #<LAB_294F        ; set pointer low byte to 1,000,000
    ldy   #>LAB_294F        ; set pointer high byte to 1,000,000
    jsr   LAB_25FB          ; do convert AY, FCA1*(AY)
    lda   #$FA              ; set number exponent count (-6)
LAB_299A
    sta   numexp            ; save number exponent count
LAB_299C
    lda   #<LAB_294B        ; set pointer low byte to 999999.4375 (max before sci note)
    ldy   #>LAB_294B        ; set pointer high byte to 999999.4375
    jsr   LAB_27F8          ; compare FAC1 with (AY)
    beq   LAB_29C3          ; exit if FAC1 = (AY)

    bpl   LAB_29B9          ; go do /10 if FAC1 > (AY)

                              ; FAC1 < (AY)
LAB_29A7
    lda   #<LAB_2947        ; set pointer low byte to 99999.9375
    ldy   #>LAB_2947        ; set pointer high byte to 99999.9375
    jsr   LAB_27F8          ; compare FAC1 with (AY)
    beq   LAB_29B2          ; branch if FAC1 = (AY) (allow decimal places)

    bpl   LAB_29C0          ; branch if FAC1 > (AY) (no decimal places)

                              ; FAC1 <= (AY)
LAB_29B2
    jsr   LAB_269E          ; multiply by 10
    dec   numexp            ; decrement number exponent count
    bne   LAB_29A7          ; go test again (branch always)

LAB_29B9
    jsr   LAB_26B9          ; divide by 10
    inc   numexp            ; increment number exponent count
    bne   LAB_299C          ; go test again (branch always)

; now we have just the digits to do

LAB_29C0
    jsr   LAB_244E          ; add 0.5 to FAC1 (round FAC1)
LAB_29C3
    jsr   LAB_2831          ; convert FAC1 floating-to-fixed
    ldx   #$01              ; set default digits before dp = 1
    lda   numexp            ; get number exponent count
    clc                     ; clear carry for add
    adc   #$07              ; up to 6 digits before point
    bmi   LAB_29D8          ; if -ve then 1 digit before dp

    cmp   #$08              ; A>=8 if n>=1E6
    bcs   LAB_29D9          ; branch if >= $08

                              ; carry is clear
    adc   #$FF              ; take 1 from digit count
    tax                     ; copy to A
    lda   #$02              ;.set exponent adjust
LAB_29D8
    sec                     ; set carry for subtract
LAB_29D9
    sbc   #$02              ; -2
    sta   expcnt            ;.save exponent adjust
    stx   numexp            ; save digits before dp count
    txa                     ; copy to A
    beq   LAB_29E4          ; branch if no digits before dp

    bpl   LAB_29F7          ; branch if digits before dp

LAB_29E4
    ldy   Sendl             ; get output string index
    lda   #$2E              ; character "."
    iny                     ; increment index
    sta   Decss,Y           ; save to output string
    txa                     ;.
    beq   LAB_29F5          ;.

    lda   #'0'              ; character "0"
    iny                     ; increment index
    sta   Decss,Y           ; save to output string
LAB_29F5
    sty   Sendl             ; save output string index
LAB_29F7
    ldy   #$00              ; clear index (point to 100,000)
    ldx   #$80              ;
LAB_29FB
    lda   FAC1_3            ; get FAC1 mantissa3
    clc                     ; clear carry for add
    adc   LAB_2A9C,Y        ; add -ve LSB
    sta   FAC1_3            ; save FAC1 mantissa3
    lda   FAC1_2            ; get FAC1 mantissa2
    adc   LAB_2A9B,Y        ; add -ve NMSB
    sta   FAC1_2            ; save FAC1 mantissa2
    lda   FAC1_1            ; get FAC1 mantissa1
    adc   LAB_2A9A,Y        ; add -ve MSB
    sta   FAC1_1            ; save FAC1 mantissa1
    inx                     ;
    bcs   LAB_2A18          ;

    bpl   LAB_29FB          ; not -ve so try again

    bmi   LAB_2A1A          ;

LAB_2A18
    bmi   LAB_29FB          ;

LAB_2A1A
    txa                     ;
    bcc   LAB_2A21          ;

    eor   #$FF              ;
    adc   #$0A              ;
LAB_2A21
    adc   #'0'-1            ; add "0"-1 to result
    iny                     ; increment index ..
    iny                     ; .. to next less ..
    iny                     ; .. power of ten
    sty   Cvaral            ; save as current var address low byte
    ldy   Sendl             ; get output string index
    iny                     ; increment output string index
    tax                     ; copy character to X
    and   #$7F              ; mask out top bit
    sta   Decss,Y           ; save to output string
    dec   numexp            ; decrement # of characters before the dp
    bne   LAB_2A3B          ; branch if still characters to do

                              ; else output the point
    lda   #$2E              ; character "."
    iny                     ; increment output string index
    sta   Decss,Y           ; save to output string
LAB_2A3B
    sty   Sendl             ; save output string index
    ldy   Cvaral            ; get current var address low byte
    txa                     ; get character back
    eor   #$FF              ;
    and   #$80              ;
    tax                     ;
    cpy   #$12              ; compare index with max
    bne   LAB_29FB          ; loop if not max

                              ; now remove trailing zeroes
    ldy   Sendl             ; get output string index
LAB_2A4B
    lda   Decss,Y           ; get character from output string
    dey                     ; decrement output string index
    cmp   #'0'              ; compare with "0"
    beq   LAB_2A4B          ; loop until non "0" character found

    cmp   #'.'              ; compare with "."
    beq   LAB_2A58          ; branch if was dp

                              ; restore last character
    iny                     ; increment output string index
LAB_2A58
    lda   #$2B              ; character "+"
    ldx   expcnt            ; get exponent count
    beq   LAB_2A8C          ; if zero go set null terminator and exit

                              ; exponent isn't zero so write exponent
    bpl   LAB_2A68          ; branch if exponent count +ve

    lda   #$00              ; clear A
    sec                     ; set carry for subtract
    sbc   expcnt            ; subtract exponent count adjust (convert -ve to +ve)
    tax                     ; copy exponent count to X
    lda   #'-'              ; character "-"
LAB_2A68
    sta   Decss+2,Y         ; save to output string
    lda   #$45              ; character "E"
    sta   Decss+1,Y         ; save exponent sign to output string
    txa                     ; get exponent count back
    ldx   #'0'-1            ; one less than "0" character
    sec                     ; set carry for subtract
LAB_2A74
    inx                     ; increment 10's character
    sbc   #$0A              ;.subtract 10 from exponent count
    bcs   LAB_2A74          ; loop while still >= 0

    adc   #':'              ; add character ":" ($30+$0A, result is 10 less that value)
    sta   Decss+4,Y         ; save to output string
    txa                     ; copy 10's character
    sta   Decss+3,Y         ; save to output string
    lda   #$00              ; set null terminator
    sta   Decss+5,Y         ; save to output string
    beq   LAB_2A91          ; go set string pointer (AY) and exit (branch always)

                              ; save last character, [EOT] and exit
LAB_2A89
    sta   Decss,Y           ; save last character to output string

                              ; set null terminator and exit
LAB_2A8C
    lda   #$00              ; set null terminator
    sta   Decss+1,Y         ; save after last character

                              ; set string pointer (AY) and exit
LAB_2A91
    lda   #<Decssp1         ; set result string low pointer
    ldy   #>Decssp1         ; set result string high pointer
    rts

; perform power function

LAB_POWER
    beq   LAB_EXP           ; go do  EXP()

    lda   FAC2_e            ; get FAC2 exponent
    bne   LAB_2ABF          ; branch if FAC2<>0

    jmp   LAB_24F3          ; clear FAC1 exponent and sign and return

LAB_2ABF
    ldx   #<func_l          ; set destination pointer low byte
    ldy   #>func_l          ; set destination pointer high byte
    jsr   LAB_2778          ; pack FAC1 into (XY)
    lda   FAC2_s            ; get FAC2 sign (b7)
    bpl   LAB_2AD9          ; branch if FAC2>0

                              ; else FAC2 is -ve and can only be raised to an
                              ; integer power which gives an x +j0 result
    jsr   LAB_INT           ; perform INT
    lda   #<func_l          ; set source pointer low byte
    ldy   #>func_l          ; set source pointer high byte
    jsr   LAB_27F8          ; compare FAC1 with (AY)
    bne   LAB_2AD9          ; branch if FAC1 <> (AY) to allow Function Call error
                              ; this will leave FAC1 -ve and cause a Function Call
                              ; error when LOG() is called

    tya                     ; clear sign b7
    ldy   Temp3             ; save mantissa 3 from INT() function as sign in Y
                              ; for possible later negation, b0
LAB_2AD9
    jsr   LAB_279D          ; save FAC1 sign and copy ABS(FAC2) to FAC1
    tya                     ; copy sign back ..
    pha                     ; .. and save it
    jsr   LAB_LOG           ; do LOG(n)
    lda   #<garb_l          ; set pointer low byte
    ldy   #>garb_l          ; set pointer high byte
    jsr   LAB_25FB          ; do convert AY, FCA1*(AY) (square the value)
    jsr   LAB_EXP           ; go do EXP(n)
    pla                     ; pull sign from stack
    lsr                     ; b0 is to be tested, shift to Cb
    bcc   LAB_2AF9          ; if no bit then exit

                              ; Perform negation
; do - FAC1

LAB_GTHAN
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_2AF9          ; exit if FAC1_e = $00

    lda   FAC1_s            ; get FAC1 sign (b7)
    eor   #$FF              ; complement it
    sta   FAC1_s            ; save FAC1 sign (b7)
LAB_2AF9
    rts

; perform EXP()   (x^e)

LAB_EXP
    lda   #<LAB_2AFA        ; set 1.443 pointer low byte
    ldy   #>LAB_2AFA        ; set 1.443 pointer high byte
    jsr   LAB_25FB          ; do convert AY, FCA1*(AY)
    lda   FAC1_r            ; get FAC1 rounding byte
    adc   #$50              ; +$50/$100
    bcc   LAB_2B2B          ; skip rounding if no carry

    jsr   LAB_27C2          ; round FAC1 (no check)
LAB_2B2B
    sta   FAC2_r            ; save FAC2 rounding byte
    jsr   LAB_27AE          ; copy FAC1 to FAC2
    lda   FAC1_e            ; get FAC1 exponent
    cmp   #$88              ; compare with EXP limit (256d)
    bcc   LAB_2B39          ; branch if less

LAB_2B36
    jsr   LAB_2690          ; handle overflow and underflow
LAB_2B39
    jsr   LAB_INT           ; perform INT
    lda   Temp3             ; get mantissa 3 from INT() function
    clc                     ; clear carry for add
    adc   #$81              ; normalise +1
    beq   LAB_2B36          ; if $00 go handle overflow

    sec                     ; set carry for subtract
    sbc   #$01              ; now correct for exponent
    pha                     ; save FAC2 exponent

                              ; swap FAC1 and FAC2
    ldx   #$04              ; 4 bytes to do
LAB_2B49
    lda   FAC2_e,X          ; get FAC2,X
    ldy   FAC1_e,X          ; get FAC1,X
    sta   FAC1_e,X          ; save FAC1,X
    sty   FAC2_e,X          ; save FAC2,X
    dex                     ; decrement count/index
    bpl   LAB_2B49          ; loop if not all done

    lda   FAC2_r            ; get FAC2 rounding byte
    sta   FAC1_r            ; save as FAC1 rounding byte
    jsr   LAB_SUBTRACT      ; perform subtraction, FAC2 from FAC1
    jsr   LAB_GTHAN         ; do - FAC1
    lda   #<LAB_2AFE        ; set counter pointer low byte
    ldy   #>LAB_2AFE        ; set counter pointer high byte
    jsr   LAB_2B84          ; go do series evaluation
    lda   #$00              ; clear A
    sta   FAC_sc            ; clear sign compare (FAC1 EOR FAC2)
    pla                     ;.get saved FAC2 exponent
    jmp   LAB_2675          ; test and adjust accumulators and return

; ^2 then series evaluation

LAB_2B6E
    sta   Cptrl             ; save count pointer low byte
    sty   Cptrh             ; save count pointer high byte
    jsr   LAB_276E          ; pack FAC1 into Adatal
    lda   #<Adatal          ; set pointer low byte (Y already $00)
    jsr   LAB_25FB          ; do convert AY, FCA1*(AY)
    jsr   LAB_2B88          ; go do series evaluation
    lda   #<Adatal          ; pointer to original # low byte
    ldy   #>Adatal          ; pointer to original # high byte
    jmp   LAB_25FB          ; do convert AY, FCA1*(AY) and return

; series evaluation

LAB_2B84
    sta   Cptrl             ; save count pointer low byte
    sty   Cptrh             ; save count pointer high byte
LAB_2B88
    ldx   #<numexp          ; set pointer low byte
    jsr   LAB_2770          ; set pointer high byte and pack FAC1 into numexp
    lda   (Cptrl),Y         ; get constants count
    sta   numcon            ; save constants count
    ldy   Cptrl             ; get count pointer low byte
    iny                     ; increment it (now constants pointer)
    tya                     ; copy it
    bne   LAB_2B97          ; skip next if no overflow

    inc   Cptrh             ; else increment high byte
LAB_2B97
    sta   Cptrl             ; save low byte
    ldy   Cptrh             ; get high byte
LAB_2B9B
    jsr   LAB_25FB          ; do convert AY, FCA1*(AY)
    lda   Cptrl             ; get constants pointer low byte
    ldy   Cptrh             ; get constants pointer high byte
    clc                     ; clear carry for add
    adc   #$04              ; +4 to  low pointer (4 bytes per constant)
    bcc   LAB_2BA8          ; skip next if no overflow

    iny                     ; increment high byte
LAB_2BA8
    sta   Cptrl             ; save pointer low byte
    sty   Cptrh             ; save pointer high byte
    jsr   LAB_246C          ; add (AY) to FAC1
    lda   #<numexp          ; set pointer low byte to partial @ numexp
    ldy   #>numexp          ; set pointer high byte to partial @ numexp
    dec   numcon            ; decrement constants count
    bne   LAB_2B9B          ; loop until all done

    rts

; RND(n), 32 bit Galoise version. make n=0 for 19th next number in sequence or n<>0
; to get 19th next number in sequence after seed n. This version of the PRNG uses
; the Galois method and a sample of 65536 bytes produced gives the following values.

; Entropy = 7.997442 bits per byte
; Optimum compression would reduce these 65536 bytes by 0 percent

; Chi square distribution for 65536 samples is 232.01, and
; randomly would exceed this value 75.00 percent of the time

; Arithmetic mean value of data bytes is 127.6724, 127.5 would be random
; Monte Carlo value for Pi is 3.122871269, error 0.60 percent
; Serial correlation coefficient is -0.000370, totally uncorrelated would be 0.0

LAB_RND
    lda   FAC1_e            ; get FAC1 exponent
    beq   NextPRN           ; do next random # if zero

                              ; else get seed into random number store
    ldx   #Rbyte4           ; set PRNG pointer low byte
    ldy   #$00              ; set PRNG pointer high byte
    jsr   LAB_2778          ; pack FAC1 into (XY)
NextPRN
    ldx   #$AF              ; set EOR byte
    ldy   #$13              ; do this nineteen times
LoopPRN
    asl   Rbyte1            ; shift PRNG most significant byte
    rol   Rbyte2            ; shift PRNG middle byte
    rol   Rbyte3            ; shift PRNG least significant byte
    rol   Rbyte4            ; shift PRNG extra byte
    bcc   Ninc1             ; branch if bit 32 clear

    txa                     ; set EOR byte
    eor   Rbyte1            ; EOR PRNG extra byte
    sta   Rbyte1            ; save new PRNG extra byte
Ninc1
    dey                     ; decrement loop count
    bne   LoopPRN           ; loop if not all done

    ldx   #$02              ; three bytes to copy
CopyPRNG
    lda   Rbyte1,X          ; get PRNG byte
    sta   FAC1_1,X          ; save FAC1 byte
      DEX
    bpl   CopyPRNG          ; loop if not complete

    lda   #$80              ; set the exponent
    sta   FAC1_e            ; save FAC1 exponent

    asl                     ; clear A
    sta   FAC1_s            ; save FAC1 sign

    jmp   LAB_24D5          ; normalise FAC1 and return

; perform COS()
func_COS:
    lda   #<LAB_2C78        ; set (pi/2) pointer low byte
    ldy   #>LAB_2C78        ; set (pi/2) pointer high byte
    jsr   LAB_246C          ; add (AY) to FAC1

; perform SIN()
func_SIN:
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    lda   #<LAB_2C7C        ; set (2*pi) pointer low byte
    ldy   #>LAB_2C7C        ; set (2*pi) pointer high byte
    ldx   FAC2_s            ; get FAC2 sign (b7)
    jsr   LAB_26C2          ; divide by (AY) (X=sign)
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    jsr   LAB_INT           ; perform INT
    lda   #$00              ; clear byte
    sta   FAC_sc            ; clear sign compare (FAC1 EOR FAC2)
    jsr   LAB_SUBTRACT      ; perform subtraction, FAC2 from FAC1
    lda   #<LAB_2C80        ; set 0.25 pointer low byte
    ldy   #>LAB_2C80        ; set 0.25 pointer high byte
    jsr   LAB_2455          ; perform subtraction, (AY) from FAC1
    lda   FAC1_s            ; get FAC1 sign (b7)
    pha                     ; save FAC1 sign
    bpl   LAB_2C35          ; branch if +ve

                              ; FAC1 sign was -ve
    jsr   LAB_244E          ; add 0.5 to FAC1
    lda   FAC1_s            ; get FAC1 sign (b7)
    bmi   LAB_2C38          ; branch if -ve

    lda   Cflag             ; get comparison evaluation flag
    eor   #$FF              ; toggle flag
    sta   Cflag             ; save comparison evaluation flag
LAB_2C35
    jsr   LAB_GTHAN         ; do - FAC1
LAB_2C38
    lda   #<LAB_2C80        ; set 0.25 pointer low byte
    ldy   #>LAB_2C80        ; set 0.25 pointer high byte
    jsr   LAB_246C          ; add (AY) to FAC1
    pla                     ; restore FAC1 sign
    bpl   LAB_2C45          ; branch if was +ve

                              ; else correct FAC1
    jsr   LAB_GTHAN         ; do - FAC1
LAB_2C45
    lda   #<LAB_2C84        ; set pointer low byte to counter
    ldy   #>LAB_2C84        ; set pointer high byte to counter
    jmp   LAB_2B6E          ; ^2 then series evaluation and return

; perform TAN()
func_TAN:
    jsr   LAB_276E          ; pack FAC1 into Adatal
    lda   #$00              ; clear byte
    sta   Cflag             ; clear comparison evaluation flag
    jsr   func_SIN           ; go do SIN(n)
    ldx   #<func_l          ; set sin(n) pointer low byte
    ldy   #>func_l          ; set sin(n) pointer high byte
    jsr   LAB_2778          ; pack FAC1 into (XY)
    lda   #<Adatal          ; set n pointer low addr
    ldy   #>Adatal          ; set n pointer high addr
    jsr   LAB_UFAC          ; unpack memory (AY) into FAC1
    lda   #$00              ; clear byte
    sta   FAC1_s            ; clear FAC1 sign (b7)
    lda   Cflag             ; get comparison evaluation flag
    jsr   LAB_2C74          ; save flag and go do series evaluation

    lda   #<func_l          ; set sin(n) pointer low byte
    ldy   #>func_l          ; set sin(n) pointer high byte
    jmp   LAB_26CA          ; convert AY and do (AY)/FAC1

LAB_2C74
    pha                     ; save comparison evaluation flag
    jmp   LAB_2C35          ; go do series evaluation

; perform USR()
func_USR
    jsr   Usrjmp            ; call user code
    jmp   LAB_1BFB          ; scan for ")", else do syntax error then warm start

; perform ATN()
func_ATN
    lda   FAC1_s            ; get FAC1 sign (b7)
    pha                     ; save sign
    bpl   LAB_2CA1          ; branch if +ve

    jsr   LAB_GTHAN         ; else do - FAC1
LAB_2CA1
    lda   FAC1_e            ; get FAC1 exponent
    pha                     ; push exponent
    cmp   #$81              ; compare with 1
    bcc   LAB_2CAF          ; branch if FAC1<1

    lda   #<LAB_259C        ; set 1 pointer low byte
    ldy   #>LAB_259C        ; set 1 pointer high byte
    jsr   LAB_26CA          ; convert AY and do (AY)/FAC1
LAB_2CAF
    lda   #<LAB_2CC9        ; set pointer low byte to counter
    ldy   #>LAB_2CC9        ; set pointer high byte to counter
    jsr   LAB_2B6E          ; ^2 then series evaluation
    pla                     ; restore old FAC1 exponent
    cmp   #$81              ; compare with 1
    bcc   LAB_2CC2          ; branch if FAC1<1

    lda   #<LAB_2C78        ; set (pi/2) pointer low byte
    ldy   #>LAB_2C78        ; set (pi/2) pointer high byte
    jsr   LAB_2455          ; perform subtraction, (AY) from FAC1
LAB_2CC2
    pla                     ; restore FAC1 sign
    bpl   LAB_2D04          ; exit if was +ve

    jmp   LAB_GTHAN         ; else do - FAC1 and return

; perform BITSET
basic_BITSET:
    jsr   LAB_GADB          ; get two parameters for POKE or WAIT
    cpx   #$08              ; only 0 to 7 are allowed
    bcs   FCError           ; branch if > 7

    lda   #$00              ; clear A
    sec                     ; set the carry
S_Bits:
    rol                     ; shift bit
    dex                     ; decrement bit number
    bpl   S_Bits            ; loop if still +ve

    inx                     ; make X = $00
    ora   (Itempl,X)        ; or with byte via temporary integer (addr)
    sta   (Itempl,X)        ; save byte via temporary integer (addr)
LAB_2D04
    rts

; perform BITCLR
basic_BITCLR:
    jsr   LAB_GADB          ; get two parameters for POKE or WAIT
    cpx   #$08              ; only 0 to 7 are allowed
    bcs   FCError           ; branch if > 7

    lda   #$FF              ; set A
S_Bitc:
    rol                     ; shift bit
    dex                     ; decrement bit number
    bpl   S_Bitc            ; loop if still +ve

    inx                     ; make X = $00
    and   (Itempl,X)        ; and with byte via temporary integer (addr)
    sta   (Itempl,X)        ; save byte via temporary integer (addr)
    rts

FCError:
    jmp   LAB_FCER          ; do function call error then warm start

; perform BITTST()
func_BTST:
    jsr   LAB_IGBY          ; increment BASIC pointer
    jsr   LAB_GADB          ; get two parameters for POKE or WAIT
    cpx   #$08              ; only 0 to 7 are allowed
    bcs   FCError           ; branch if > 7

    jsr   LAB_GBYT          ; get next BASIC byte
    cmp   #')'              ; is next character ")"
    beq   TST_OK            ; if ")" go do rest of function

    jmp   LAB_SNER          ; do syntax error then warm start

TST_OK:
    jsr   LAB_IGBY          ; update BASIC execute pointer (to character past ")")
    lda   #$00              ; clear A
    sec                     ; set the carry
T_Bits:
    rol                     ; shift bit
    dex                     ; decrement bit number
    bpl   T_Bits            ; loop if still +ve

    inx                     ; make X = $00
    and   (Itempl,X)        ; AND with byte via temporary integer (addr)
    beq   LAB_NOTT          ; branch if zero (already correct)

    lda   #$FF              ; set for -1 result
LAB_NOTT:
    jmp   LAB_27DB          ; go do SGN tail

; perform BIN$()
LAB_BINS
    cpx   #$19              ; max + 1
    bcs   BinFErr           ; exit if too big ( > or = )

    stx   TempB             ; save # of characters ($00 = leading zero remove)
    lda   #$18              ; need A byte long space
    jsr   LAB_MSSP          ; make string space A bytes long
    ldy   #$17              ; set index
    ldx   #$18              ; character count
NextB1
    lsr   nums_1            ; shift highest byte
    ror   nums_2            ; shift middle byte
    ror   nums_3            ; shift lowest byte bit 0 to carry
    txa                     ; load with "0"/2
    rol                     ; shift in carry
    sta   (str_pl),Y        ; save to temp string + index
    dey                     ; decrement index
    bpl   NextB1            ; loop if not done

    lda   TempB             ; get # of characters
    beq   EndBHS            ; branch if truncate

    tax                     ; copy length to X
    sec                     ; set carry for add !
    eor   #$FF              ; 1's complement
    adc   #$18              ; add 24d
    beq   GoPr2             ; if zero print whole string

    bne   GoPr1             ; else go make output string

; this is the exit code and is also used by HEX$()
; truncate string to remove leading "0"s
EndBHS:
    tay                     ; clear index (A=0, X=length here)
NextB2:
    lda   (str_pl),Y        ; get character from string
    cmp   #'0'              ; compare with "0"
    bne   GoPr              ; if not "0" then go print string from here

    dex                     ; decrement character count
    beq   GoPr3             ; if zero then end of string so go print it

    iny                     ; else increment index
    bpl   NextB2            ; loop always

; make fixed length output string - ignore overflows!
GoPr3
    inx                     ; need at least 1 character
GoPr
    tya                     ; copy result
GoPr1
    clc                     ; clear carry for add
    adc   str_pl            ; add low address
    sta   str_pl            ; save low address
    lda   #$00              ; do high byte
    adc   str_ph            ; add high address
    sta   str_ph            ; save high address
GoPr2
    stx   str_ln            ; X holds string length
    jsr   LAB_IGBY          ; update BASIC execute pointer (to character past ")")
    jmp   LAB_RTST          ; check for space on descriptor stack then put address
                              ; and length on descriptor stack and update stack pointers

BinFErr
    jmp   LAB_FCER          ; do function call error then warm start

; perform HEX$()
func_HEXS:
    cpx   #$07              ; max + 1
    bcs   BinFErr           ; exit if too big ( > or = )

    stx   TempB             ; save # of characters

    lda   #$06              ; need 6 bytes for string
    jsr   LAB_MSSP          ; make string space A bytes long
    ldy   #$05              ; set string index

; *** disable decimal mode patch - comment next line ***
;      SED                     ; need decimal mode for nibble convert
    lda   nums_3            ; get lowest byte
    jsr   LAB_A2HX          ; convert A to ASCII hex byte and output
    lda   nums_2            ; get middle byte
    jsr   LAB_A2HX          ; convert A to ASCII hex byte and output
    lda   nums_1            ; get highest byte
    jsr   LAB_A2HX          ; convert A to ASCII hex byte and output
; *** disable decimal mode patch - comment next line ***
;      CLD                     ; back to binary

    ldx   #$06              ; character count
    lda   TempB             ; get # of characters
    beq   EndBHS            ; branch if truncate

    tax                     ; copy length to X
    sec                     ; set carry for add !
    eor   #$FF              ; 1's complement
    adc   #$06              ; add 6d
    beq   GoPr2             ; if zero print whole string

    bne   GoPr1             ; else go make output string (branch always)

; convert A to ASCII hex byte and output .. note set decimal mode before calling
LAB_A2HX
    tax                     ; save byte
    and   #$0F              ; mask off top bits
    jsr   LAB_AL2X          ; convert low nibble to ASCII and output
    txa                     ; get byte back
    lsr                     ; /2  shift high nibble to low nibble
    lsr                     ; /4
    lsr                     ; /8
    lsr                     ; /16
LAB_AL2X
    cmp   #$0A              ; set carry for +1 if >9
; *** begin disable decimal mode patch ***
; *** insert
    bcc   LAB_AL20          ; skip adjust if <= 9
    adc   #$06              ; adjust for A to F
LAB_AL20
; *** end   disable decimal mode patch ***
    adc   #'0'              ; add ASCII "0"
    sta   (str_pl),Y        ; save to temp string
    dey                     ; decrement counter
    rts

LAB_NLTO
    sta   FAC1_e            ; save FAC1 exponent
    lda   #$00              ; clear sign compare
LAB_MLTE
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    txa                     ; restore character
    jsr   LAB_2912          ; evaluate new ASCII digit

; gets here if the first character was "$" for hex
; get hex number

LAB_CHEX
    jsr   LAB_IGBY          ; increment and scan memory
    bcc   LAB_ISHN          ; branch if numeric character

    ora   #$20              ; case convert, allow "A" to "F" and "a" to "f"
    sbc   #'a'              ; subtract "a" (carry set here)
    cmp   #$06              ; compare normalised with $06 (max+1)
    bcs   LAB_EXCH          ; exit if >"f" or <"0"

    adc   #$0A              ; convert to nibble
LAB_ISHN
    and   #$0F              ; convert to binary
    tax                     ; save nibble
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_MLTE          ; skip multiply if zero

    adc   #$04              ; add four to exponent (*16 - carry clear here)
    bcc   LAB_NLTO          ; if no overflow do evaluate digit

LAB_MLTO
    jmp   LAB_2564          ; do overflow error and warm start

LAB_NXCH
    tax                     ; save bit
    lda   FAC1_e            ; get FAC1 exponent
    beq   LAB_MLBT          ; skip multiply if zero

    inc   FAC1_e            ; increment FAC1 exponent (*2)
    beq   LAB_MLTO          ; do overflow error if = $00

    lda   #$00              ; clear sign compare
LAB_MLBT
    sta   FAC_sc            ; save sign compare (FAC1 EOR FAC2)
    txa                     ; restore bit
    jsr   LAB_2912          ; evaluate new ASCII digit

; gets here if the first character was  "%" for binary
; get binary number

LAB_CBIN
    jsr   LAB_IGBY          ; increment and scan memory
    eor   #'0'              ; convert "0" to 0 etc.
    cmp   #$02              ; compare with max+1
    bcc   LAB_NXCH          ; branch exit if < 2

LAB_EXCH
    jmp   LAB_28F6          ; evaluate -ve flag and return

; ctrl-c check routine. includes limited "life" byte save for INGET routine
; now also the code that checks to see if an interrupt has occurred
CTRLC:
    lda   ctrl_c_flag           ; get [CTRL-C] check flag
    bne   LAB_FBA2              ; exit if inhibited

    jsr   V_INPT                ; scan input device
    bcc   LAB_FBA0              ; exit if buffer empty

    sta   ctrl_c_byte           ; save received byte
    ldx   #$20                  ; "life" timer for bytes
    stx   ctrl_c_timeout        ; set countdown
    jmp   LAB_1636              ; return to BASIC

LAB_FBA0:
    ldx   ctrl_c_timeout        ; get countdown byte
    beq   LAB_FBA2              ; exit if finished

    dec   ctrl_c_timeout        ; else decrement countdown
LAB_FBA2:
    ldx   #NmiBase              ; set pointer to NMI values
    jsr   LAB_CKIN              ; go check interrupt
    ldx   #IrqBase              ; set pointer to IRQ values
    jsr   LAB_CKIN              ; go check interrupt
LAB_CRTS:
    rts

; check whichever interrupt is indexed by X
LAB_CKIN
    lda   PLUS_0,X          ; get interrupt flag byte
    bpl   LAB_CRTS          ; branch if interrupt not enabled

; we disable the interrupt here and make two new commands RETIRQ and RETNMI to
; automatically enable the interrupt when we exit
    asl                     ; move happened bit to setup bit
    and   #$40              ; mask happened bits
    beq   LAB_CRTS          ; if no interrupt then exit

    sta   PLUS_0,X          ; save interrupt flag byte

    txa                     ; copy index ..
    tay                     ; .. to Y

    pla                     ; dump return address low byte, call from CTRL-C
    pla                     ; dump return address high byte

    lda   #$05              ; need 5 bytes for GOSUB
    jsr   LAB_1212          ; check room on stack for A bytes
    lda   Bpntrh            ; get BASIC execute pointer high byte
    pha                     ; push on stack
    lda   Bpntrl            ; get BASIC execute pointer low byte
    pha                     ; push on stack
    lda   Clineh            ; get current line high byte
    pha                     ; push on stack
    lda   Clinel            ; get current line low byte
    pha                     ; push on stack
    lda   #token_GOSUB         ; token for GOSUB
    pha                     ; push on stack

    lda   PLUS_1,Y          ; get interrupt code pointer low byte
    sta   Bpntrl            ; save as BASIC execute pointer low byte
    lda   PLUS_2,Y          ; get interrupt code pointer high byte
    sta   Bpntrh            ; save as BASIC execute pointer high byte

    jmp   LAB_15C2          ; go do interpreter inner loop
                              ; can't RTS, we used the stack! the RTS from the ctrl-c
                              ; check will be taken when the RETIRQ/RETNMI/RETURN is
                              ; executed at the end of the subroutine

; get byte from input device, no waiting
; returns with carry set if byte in A
INGET
    jsr   V_INPT            ; call scan input device
    bcs   LAB_FB95          ; if byte go reset timer

    lda   ctrl_c_timeout            ; get countdown
    beq   LAB_FB96          ; exit if empty

    lda   ctrl_c_byte            ; get last received byte
    sec                     ; flag we got a byte
LAB_FB95
    ldx   #$00              ; clear X
    stx   ctrl_c_timeout            ; clear timer because we got a byte
LAB_FB96
    rts

; these routines only enable the interrupts if the set-up flag is set
; if not they have no effect

; perform IRQ {ON|OFF|CLEAR}
LAB_IRQ
    ldx   #IrqBase          ; set pointer to IRQ values
      .byte $2C               ; make next line BIT abs.

; perform NMI {ON|OFF|CLEAR}
LAB_NMI
    ldx   #NmiBase          ; set pointer to NMI values
    cmp   #token_ON            ; compare with token for ON
    beq   LAB_INON          ; go turn on interrupt

    cmp   #token_OFF           ; compare with token for OFF
    beq   LAB_IOFF          ; go turn off interrupt

    eor   #token_CLEAR         ; compare with token for CLEAR, A = $00 if = token_CLEAR
    beq   LAB_INEX          ; go clear interrupt flags and return

    jmp   LAB_SNER          ; do syntax error then warm start

LAB_IOFF
    lda   #$7F              ; clear A
    and   PLUS_0,X          ; AND with interrupt setup flag
    bpl   LAB_INEX          ; go clear interrupt enabled flag and return

LAB_INON
    lda   PLUS_0,X          ; get interrupt setup flag
    asl                     ; Shift bit to enabled flag
    ora   PLUS_0,X          ; OR with flag byte
LAB_INEX
    sta   PLUS_0,X          ; save interrupt flag byte
    jmp   LAB_IGBY          ; update BASIC execute pointer and return

; these routines set up the pointers and flags for the interrupt routines
; note that the interrupts are also enabled by these commands

; perform ON IRQ
LAB_SIRQ
    cli                     ; enable interrupts
    ldx   #IrqBase          ; set pointer to IRQ values
      .byte $2C               ; make next line BIT abs.

; perform ON NMI
LAB_SNMI
    ldx   #NmiBase          ; set pointer to NMI values

    stx   TempB             ; save interrupt pointer
    jsr   LAB_IGBY          ; increment and scan memory (past token)
    jsr   LAB_GFPN          ; get fixed-point number into temp integer
    lda   Smeml             ; get start of mem low byte
    ldx   Smemh             ; get start of mem high byte
    jsr   LAB_SHLN          ; search Basic for temp integer line number from AX
    bcs   LAB_LFND          ; if carry set go set-up interrupt

    jmp   LAB_16F7          ; else go do "Undefined statement" error and warm start

LAB_LFND
    ldx   TempB             ; get interrupt pointer
    lda   Baslnl            ; get pointer low byte
    sbc   #$01              ; -1 (carry already set for subtract)
    sta   PLUS_1,X          ; save as interrupt pointer low byte
    lda   Baslnh            ; get pointer high byte
    sbc   #$00              ; subtract carry
    sta   PLUS_2,X          ; save as interrupt pointer high byte

    lda   #$C0              ; set interrupt enabled/setup bits
    sta   PLUS_0,X          ; set interrupt flags
LAB_IRTS
    rts

; return from IRQ service, restores the enabled flag.

; perform RETIRQ

LAB_RETIRQ
    bne   LAB_IRTS          ; exit if following token (to allow syntax error)

    lda   IrqBase           ; get interrupt flags
    asl                     ; copy setup to enabled (b7)
    ora   IrqBase           ; OR in setup flag
    sta   IrqBase           ; save enabled flag
    jmp   LAB_16E8          ; go do rest of RETURN

; return from NMI service, restores the enabled flag.

; perform RETNMI
LAB_RETNMI
    bne   LAB_IRTS          ; exit if following token (to allow syntax error)

    lda   NmiBase           ; get set-up flag
    asl                     ; copy setup to enabled (b7)
    ora   NmiBase           ; OR in setup flag
    sta   NmiBase           ; save enabled flag
    jmp   LAB_16E8          ; go do rest of RETURN

; MAX() MIN() pre process
LAB_MMPP
    jsr   LAB_EVEZ          ; process expression
    jmp   LAB_CTNM          ; check if source is numeric, else do type mismatch

; perform MAX()
LAB_MAX
    jsr   LAB_PHFA          ; push FAC1, evaluate expression,
                              ; pull FAC2 and compare with FAC1
    bpl   LAB_MAX           ; branch if no swap to do

    lda   FAC2_1            ; get FAC2 mantissa1
    ora   #$80              ; set top bit (clear sign from compare)
    sta   FAC2_1            ; save FAC2 mantissa1
    jsr   LAB_279B          ; copy FAC2 to FAC1
    beq   LAB_MAX           ; go do next (branch always)

; perform MIN()
LAB_MIN
    jsr   LAB_PHFA          ; push FAC1, evaluate expression,
                              ; pull FAC2 and compare with FAC1
    bmi   LAB_MIN           ; branch if no swap to do

    beq   LAB_MIN           ; branch if no swap to do

    lda   FAC2_1            ; get FAC2 mantissa1
    ora   #$80              ; set top bit (clear sign from compare)
    sta   FAC2_1            ; save FAC2 mantissa1
    jsr   LAB_279B          ; copy FAC2 to FAC1
    beq   LAB_MIN           ; go do next (branch always)

; exit routine. don't bother returning to the loop code
; check for correct exit, else so syntax error
LAB_MMEC
    cmp   #')'              ; is it end of function?
    bne   LAB_MMSE          ; if not do MAX MIN syntax error

    pla                     ; dump return address low byte
    pla                     ; dump return address high byte
    jmp   LAB_IGBY          ; update BASIC execute pointer (to chr past ")")

LAB_MMSE
    jmp   LAB_SNER          ; do syntax error then warm start

; check for next, evaluate and return or exit
; this is the routine that does most of the work
LAB_PHFA
    jsr   LAB_GBYT          ; get next BASIC byte
    cmp   #','              ; is there more ?
    bne   LAB_MMEC          ; if not go do end check

                              ; push FAC1
    jsr   LAB_27BA          ; round FAC1
    lda   FAC1_s            ; get FAC1 sign
    ora   #$7F              ; set all non sign bits
    and   FAC1_1            ; AND FAC1 mantissa1 (AND in sign bit)
    pha                     ; push on stack
    lda   FAC1_2            ; get FAC1 mantissa2
    pha                     ; push on stack
    lda   FAC1_3            ; get FAC1 mantissa3
    pha                     ; push on stack
    lda   FAC1_e            ; get FAC1 exponent
    pha                     ; push on stack

    jsr   LAB_IGBY          ; scan and get next BASIC byte (after ",")
    jsr   LAB_EVNM          ; evaluate expression and check is numeric,
                              ; else do type mismatch

                              ; pop FAC2 (MAX/MIN expression so far)
    pla                     ; pop exponent
    sta   FAC2_e            ; save FAC2 exponent
    pla                     ; pop mantissa3
    sta   FAC2_3            ; save FAC2 mantissa3
    pla                     ; pop mantissa1
    sta   FAC2_2            ; save FAC2 mantissa2
    pla                     ; pop sign/mantissa1
    sta   FAC2_1            ; save FAC2 sign/mantissa1
    sta   FAC2_s            ; save FAC2 sign

                              ; compare FAC1 with (packed) FAC2
    lda   #<FAC2_e          ; set pointer low byte to FAC2
    ldy   #>FAC2_e          ; set pointer high byte to FAC2
    jmp   LAB_27F8          ; compare FAC1 with FAC2 (AY) and return
                              ; returns A=$00 if FAC1 = (AY)
                              ; returns A=$01 if FAC1 > (AY)
                              ; returns A=$FF if FAC1 < (AY)

; perform WIDTH
basic_WDTH
    cmp   #','              ; is next byte ","
    beq   LAB_TBSZ          ; if so do tab size

    jsr   LAB_GTBY          ; get byte parameter
    txa                     ; copy width to A
    beq   LAB_NSTT          ; branch if set for infinite line

    cpx   #$10              ; else make min width = 16d
    bcc   TabErr            ; if less do function call error and exit

; this next compare ensures that we can't exit WIDTH via an error leaving the
; tab size greater than the line length.

    cpx   TabSiz            ; compare with tab size
    bcs   LAB_NSTT          ; branch if >= tab size

    stx   TabSiz            ; else make tab size = terminal width
LAB_NSTT
    stx   TWidth            ; set the terminal width
    jsr   LAB_GBYT          ; get BASIC byte back
    beq   WExit             ; exit if no following

    cmp   #','              ; else is it ","
    bne   LAB_MMSE          ; if not do syntax error

LAB_TBSZ
    jsr   LAB_SGBY          ; scan and get byte parameter
    txa                     ; copy TAB size
    bmi   TabErr            ; if >127 do function call error and exit

    cpx   #$01              ; compare with min-1
    bcc   TabErr            ; if <=1 do function call error and exit

    lda   TWidth            ; set flags for width
    beq   LAB_SVTB          ; skip check if infinite line

    cpx   TWidth            ; compare TAB with width
    beq   LAB_SVTB          ; ok if =

    bcs   TabErr            ; branch if too big

LAB_SVTB
    stx   TabSiz            ; save TAB size

; calculate tab column limit from TAB size. The Iclim is set to the last tab
; position on a line that still has at least one whole tab width between it
; and the end of the line.
WExit:
    lda   TWidth            ; get width
    beq   LAB_SULP          ; branch if infinite line

    cmp   TabSiz            ; compare with tab size
    bcs   LAB_WDLP          ; branch if >= tab size

    sta   TabSiz            ; else make tab size = terminal width
LAB_SULP:
    sec                     ; set carry for subtract
LAB_WDLP:
    sbc   TabSiz            ; subtract tab size
    bcs   LAB_WDLP          ; loop while no borrow

    adc   TabSiz            ; add tab size back
    clc                     ; clear carry for add
    adc   TabSiz            ; add tab size back again
    sta   Iclim             ; save for now
    lda   TWidth            ; get width back
    sec                     ; set carry for subtract
    sbc   Iclim             ; subtract remainder
    sta   Iclim             ; save tab column limit
LAB_NOSQ:
    rts

TabErr:
    jmp   LAB_FCER          ; do function call error then warm start

; perform SQR()
LAB_SQR:
    lda   FAC1_s            ; get FAC1 sign
    bmi   TabErr            ; if -ve do function call error

    lda   FAC1_e            ; get exponent
    beq   LAB_NOSQ          ; if zero just return

                              ; else do root
    jsr   LAB_27AB          ; round and copy FAC1 to FAC2
    lda   #$00              ; clear A

    sta   FACt_3            ; clear remainder
    sta   FACt_2            ; ..
    sta   FACt_1            ; ..
    sta   TempB             ; ..

    sta   FAC1_3            ; clear root
    sta   FAC1_2            ; ..
    sta   FAC1_1            ; ..

    ldx   #$18              ; 24 pairs of bits to do
    lda   FAC2_e            ; get exponent
    lsr                     ; check odd/even
    bcs   LAB_SQE2          ; if odd only 1 shift first time

LAB_SQE1
    asl   FAC2_3            ; shift highest bit of number ..
    rol   FAC2_2            ; ..
    rol   FAC2_1            ; ..
    rol   FACt_3            ; .. into remainder
    rol   FACt_2            ; ..
    rol   FACt_1            ; ..
    rol   TempB             ; .. never overflows
LAB_SQE2
    asl   FAC2_3            ; shift highest bit of number ..
    rol   FAC2_2            ; ..
    rol   FAC2_1            ; ..
    rol   FACt_3            ; .. into remainder
    rol   FACt_2            ; ..
    rol   FACt_1            ; ..
    rol   TempB             ; .. never overflows

    asl   FAC1_3            ; root = root * 2
    rol   FAC1_2            ; ..
    rol   FAC1_1            ; .. never overflows

    lda   FAC1_3            ; get root low byte
    rol                     ; *2
    sta   Temp3             ; save partial low byte
    lda   FAC1_2            ; get root low mid byte
    rol                     ; *2
    sta   Temp3+1           ; save partial low mid byte
    lda   FAC1_1            ; get root high mid byte
    rol                     ; *2
    sta   Temp3+2           ; save partial high mid byte
    lda   #$00              ; get root high byte (always $00)
    rol                     ; *2
    sta   Temp3+3           ; save partial high byte

                              ; carry clear for subtract +1
    lda   FACt_3            ; get remainder low byte
    sbc   Temp3             ; subtract partial low byte
    sta   Temp3             ; save partial low byte

    lda   FACt_2            ; get remainder low mid byte
    sbc   Temp3+1           ; subtract partial low mid byte
    sta   Temp3+1           ; save partial low mid byte

    lda   FACt_1            ; get remainder high mid byte
    sbc   Temp3+2           ; subtract partial high mid byte
    tay                     ; copy partial high mid byte

    lda   TempB             ; get remainder high byte
    sbc   Temp3+3           ; subtract partial high byte
    bcc   LAB_SQNS          ; skip sub if remainder smaller

    sta   TempB             ; save remainder high byte

    sty   FACt_1            ; save remainder high mid byte

    lda   Temp3+1           ; get remainder low mid byte
    sta   FACt_2            ; save remainder low mid byte

    lda   Temp3             ; get partial low byte
    sta   FACt_3            ; save remainder low byte

    inc   FAC1_3            ; increment root low byte (never any rollover)
LAB_SQNS:
    dex                     ; decrement bit pair count
    bne   LAB_SQE1          ; loop if not all done

    sec                     ; set carry for subtract
    lda   FAC2_e            ; get exponent
    sbc   #$80              ; normalise
    ror                     ; /2 and re-bias to $80
    adc   #$00              ; add bit zero back in (allow for half shift)
    sta   FAC1_e            ; save it
    jmp   LAB_24D5          ; normalise FAC1 and return

; perform VARPTR()
LAB_VARPTR:
    jsr   LAB_IGBY          ; increment and scan memory
    jsr   LAB_GVAR          ; get var address
    jsr   LAB_1BFB          ; scan for ")" , else do syntax error then warm start
    ldy   Cvaral            ; get var address low byte
    lda   Cvarah            ; get var address high byte
    jmp   LAB_AYFC          ; save and convert integer AY to FAC1 and return

; perform PI
LAB_PI:
    lda   #<LAB_2C7C        ; set (2*pi) pointer low byte
    ldy   #>LAB_2C7C        ; set (2*pi) pointer high byte
    jsr   LAB_UFAC          ; unpack memory (AY) into FAC1
    dec   FAC1_e            ; make result = PI
    rts

; perform TWOPI
LAB_TWOPI:
    lda   #<LAB_2C7C        ; set (2*pi) pointer low byte
    ldy   #>LAB_2C7C        ; set (2*pi) pointer high byte
    jmp   LAB_UFAC          ; unpack memory (AY) into FAC1 and return

; system dependant i/o vectors
; these are in RAM and are set by the monitor at start-up

V_INPT
    jmp   (VEC_IN)          ; non halting scan input device
V_OUTP
    jmp   (VEC_OUT)         ; send byte to output device
V_LOAD
    jmp   (VEC_LD)          ; load BASIC program
V_SAVE
    jmp   (VEC_SV)          ; save BASIC program

; The rest are tables messages and code for RAM

; the rest of the code is tables and BASIC start-up code

PG2_TABS
      .byte $00               ; ctrl-c flag           -     $00 = enabled
      .byte $00               ; ctrl-c byte           -     GET needs this
      .byte $00               ; ctrl-c byte timeout   -     GET needs this
      .word CTRLC             ; ctrl c check vector
;     .word xxxx              ; non halting key input -     monitor to set this
;     .word xxxx              ; output vector         -     monitor to set this
;     .word xxxx              ; load vector           -     monitor to set this
;     .word xxxx              ; save vector           -     monitor to set this
PG2_TABE

; character get subroutine for zero page

; For a 1.8432MHz 6502 including the JSR and RTS
; fastest (>=":") =  29 cycles =  15.7uS
; slowest (<":")  =  40 cycles =  21.7uS
; space skip      = +21 cycles = +11.4uS
; inc across page =  +4 cycles =  +2.2uS

; the target address for the LDA at LAB_2CF4 becomes the BASIC execute pointer once the
; block is copied to it's destination, any non zero page address will do at assembly
; time, to assemble a three byte instruction.

; page 0 initialisation table from $BC
; increment and scan memory

LAB_2CEE
    inc   Bpntrl            ; increment BASIC execute pointer low byte
    bne   LAB_2CF4          ; branch if no carry
                              ; else
    inc   Bpntrh            ; increment BASIC execute pointer high byte

; page 0 initialisation table from $C2
; scan memory

LAB_2CF4
    lda   $FFFF             ; get byte to scan (addr set by call routine)
    cmp   #token_ELSE          ; compare with the token for ELSE
    beq   LAB_2D05          ; exit if ELSE, not numeric, carry set

    cmp   #':'              ; compare with ":"
    bcs   LAB_2D05          ; exit if >= ":", not numeric, carry set

    cmp   #' '              ; compare with " "
    beq   LAB_2CEE          ; if " " go do next

    sec                     ; set carry for SBC
    sbc   #'0'              ; subtract "0"
    sec                     ; set carry for SBC
    sbc   #$D0              ; subtract -"0"
                              ; clear carry if byte = "0"-"9"
LAB_2D05
    rts

; page zero initialisation table $00-$12 inclusive

StrTab
      .byte $4C               ; JMP opcode
      .word cold_start          ; initial warm start vector (cold start)

      .byte $00               ; these bytes are not used by BASIC
      .word $0000             ;
      .word $0000             ;
      .word $0000             ;

      .byte $4C               ; JMP opcode
      .word LAB_FCER          ; initial user function vector ("Function call" error)
      .byte $00               ; default NULL count
      .byte $00               ; clear terminal position
      .byte $00               ; default terminal width byte
      .byte $F2               ; default limit for TAB = 14
      .word Ram_base          ; start of user RAM
EndTab

LAB_MSZM
      .byte $0D,$0A,"Memory size ",$00

LAB_SMSG
      .byte " Bytes free",$0D,$0A,$0A
      .byte "Enhanced BASIC 2.22p5",$0A,$00

; numeric constants and series

                              ; constants and series for LOG(n)
LAB_25A0
      .byte $02               ; counter
      .byte $80,$19,$56,$62   ; 0.59898
      .byte $80,$76,$22,$F3   ; 0.96147
;##   .byte $80,$76,$22,$F1   ; 0.96147
      .byte $82,$38,$AA,$40   ; 2.88539
;##   .byte $82,$38,$AA,$45   ; 2.88539

LAB_25AD
      .byte $80,$35,$04,$F3   ; 0.70711   1/root 2
LAB_25B1
      .byte $81,$35,$04,$F3   ; 1.41421   root 2
LAB_25B5
      .byte $80,$80,$00,$00   ; -0.5
LAB_25B9
      .byte $80,$31,$72,$18   ; 0.69315   LOG(2)

                              ; numeric PRINT constants
LAB_2947
      .byte $91,$43,$4F,$F8   ; 99999.9375 (max value with at least one decimal)
LAB_294B
      .byte $94,$74,$23,$F7   ; 999999.4375 (max value before scientific notation)
LAB_294F
      .byte $94,$74,$24,$00   ; 1000000

                              ; EXP(n) constants and series
LAB_2AFA
      .byte $81,$38,$AA,$3B   ; 1.4427    (1/LOG base 2 e)
LAB_2AFE
      .byte $06               ; counter
      .byte $74,$63,$90,$8C   ; 2.17023e-4
      .byte $77,$23,$0C,$AB   ; 0.00124
      .byte $7A,$1E,$94,$00   ; 0.00968
      .byte $7C,$63,$42,$80   ; 0.05548
      .byte $7E,$75,$FE,$D0   ; 0.24023
      .byte $80,$31,$72,$15   ; 0.69315
      .byte $81,$00,$00,$00   ; 1.00000

;##   .byte $07               ; counter
;##   .byte $74,$94,$2E,$40   ; -1/7! (-1/5040)
;##   .byte $77,$2E,$4F,$70   ;  1/6! ( 1/720)
;##   .byte $7A,$88,$02,$6E   ; -1/5! (-1/120)
;##   .byte $7C,$2A,$A0,$E6   ;  1/4! ( 1/24)
;##   .byte $7E,$AA,$AA,$50   ; -1/3! (-1/6)
;##   .byte $7F,$7F,$FF,$FF   ;  1/2! ( 1/2)
;##   .byte $81,$80,$00,$00   ; -1/1! (-1/1)
;##   .byte $81,$00,$00,$00   ;  1/0! ( 1/1)

; trigonometric constants and series
LAB_2C78:
      .byte $81,$49,$0F,$DB   ; 1.570796371 (pi/2) as floating #
LAB_2C84:
    .byte $04               ; counter
    .byte $86,$1E,$D7,$FB   ; 39.7109
;## .byte $86,$1E,$D7,$BA   ; 39.7109
    .byte $87,$99,$26,$65   ;-76.575
;## .byte $87,$99,$26,$64   ;-76.575
    .byte $87,$23,$34,$58   ; 81.6022
    .byte $86,$A5,$5D,$E1   ;-41.3417
;## .byte $86,$A5,$5D,$E0   ;-41.3417
LAB_2C7C:
    .byte $83,$49,$0F,$DB   ; 6.28319 (2*pi) as floating #
;## .byte $83,$49,$0F,$DA   ; 6.28319 (2*pi) as floating #

LAB_2CC9:
    .byte $08               ; counter
    .byte $78,$3A,$C5,$37   ; 0.00285
    .byte $7B,$83,$A2,$5C   ;-0.0160686
    .byte $7C,$2E,$DD,$4D   ; 0.0426915
    .byte $7D,$99,$B0,$1E   ;-0.0750429
    .byte $7D,$59,$ED,$24   ; 0.106409
    .byte $7E,$91,$72,$00   ;-0.142036
    .byte $7E,$4C,$B9,$73   ; 0.199926
    .byte $7F,$AA,$AA,$53   ;-0.333331

;##   .byte $08               ; counter
;##   .byte $78,$3B,$D7,$4A   ; 1/17
;##   .byte $7B,$84,$6E,$02   ;-1/15
;##   .byte $7C,$2F,$C1,$FE   ; 1/13
;##   .byte $7D,$9A,$31,$74   ;-1/11
;##   .byte $7D,$5A,$3D,$84   ; 1/9
;##   .byte $7E,$91,$7F,$C8   ;-1/7
;##   .byte $7E,$4C,$BB,$E4   ; 1/5
;##   .byte $7F,$AA,$AA,$6C   ;-1/3

LAB_1D96    = *+1             ; $00,$00 used for undefined variables
LAB_259C
      .byte $81,$00,$00,$00   ; 1.000000, used for INC
LAB_2AFD
      .byte $81,$80,$00,$00   ; -1.00000, used for DEC. must be on the same page as +1.00

                              ; misc constants
LAB_1DF7
      .byte $90               ;-32768 (uses first three bytes from 0.5)
LAB_2A96
      .byte $80,$00,$00,$00   ; 0.5
LAB_2C80
      .byte $7F,$00,$00,$00   ; 0.25
LAB_26B5
      .byte $84,$20,$00,$00   ; 10.0000 divide by 10 constant

; This table is used in converting numbers to ASCII.
LAB_2A9A:
LAB_2A9B = LAB_2A9A+1
LAB_2A9C = LAB_2A9B+1
    .byte $FE,$79,$60       ; -100000
    .byte $00,$27,$10       ; 10000
    .byte $FF,$FC,$18       ; -1000
    .byte $00,$00,$64       ; 100
    .byte $FF,$FF,$F6       ; -10
    .byte $00,$00,$01       ; 1

LAB_CTBL:
    .word basic_END-1         ; END
    .word basic_FOR-1         ; FOR
    .word basic_NEXT-1        ; NEXT
    .word basic_DATA-1        ; DATA
    .word basic_INPUT-1       ; INPUT
    .word basic_DIM-1         ; DIM
    .word basic_READ-1        ; READ
    .word basic_LET-1         ; LET
    .word basic_DEC-1         ; DEC             new command
    .word basic_GOTO-1        ; GOTO
    .word cmd_RUN-1         ; RUN
    .word basic_IF-1          ; IF
    .word basic_RESTORE-1     ; RESTORE         modified command
    .word basic_GOSUB-1       ; GOSUB
    .word LAB_RETIRQ-1      ; RETIRQ          new command
    .word LAB_RETNMI-1      ; RETNMI          new command
    .word LAB_RETURN-1      ; RETURN
    .word basic_REM-1         ; REM
    .word basic_STOP-1        ; STOP
    .word basic_ON-1          ; ON              modified command
    .word LAB_NULL-1        ; NULL            modified command
    .word basic_INC-1         ; INC             new command
    .word basic_WAIT-1        ; WAIT
    .word V_LOAD-1          ; LOAD
    .word V_SAVE-1          ; SAVE
    .word basic_DEF-1         ; DEF
    .word basic_POKE-1        ; POKE
    .word basic_DOKE-1        ; DOKE            new command
    .word basic_CALL-1        ; CALL            new command
    .word basic_DO-1          ; DO              new command
    .word cmd_LOOP-1        ; LOOP            new command
    .word print-1       ; PRINT
    .word basic_CONT-1        ; CONT
    .word cmd_LIST-1        ; LIST
    .word cmd_CLEAR-1       ; CLEAR
    .word cmd_NEW-1         ; NEW
    .word basic_WDTH-1        ; WIDTH           new command
    .word basic_GET-1         ; GET             new command
    .word basic_SWAP-1        ; SWAP            new command
    .word basic_BITSET-1      ; BITSET          new command
    .word basic_BITCLR-1      ; BITCLR          new command
    .word LAB_IRQ-1         ; IRQ             new command
    .word LAB_NMI-1         ; NMI             new command

; function pre process routine table
LAB_FTPL:
LAB_FTPM = LAB_FTPL+$01
    .word LAB_PPFN-1        ; SGN(n)    process numeric expression in ()
    .word LAB_PPFN-1        ; INT(n)          "
    .word LAB_PPFN-1        ; ABS(n)          "
    .word LAB_EVEZ-1        ; USR(x)    process any expression
    .word LAB_1BF7-1        ; FRE(x)          "
    .word LAB_1BF7-1        ; POS(x)          "
    .word LAB_PPFN-1        ; SQR(n)    process numeric expression in ()
    .word LAB_PPFN-1        ; RND(n)          "
    .word LAB_PPFN-1        ; LOG(n)          "
    .word LAB_PPFN-1        ; EXP(n)          "
    .word LAB_PPFN-1        ; COS(n)          "
    .word LAB_PPFN-1        ; SIN(n)          "
    .word LAB_PPFN-1        ; TAN(n)          "
    .word LAB_PPFN-1        ; ATN(n)          "
    .word LAB_PPFN-1        ; PEEK(n)         "
    .word LAB_PPFN-1        ; DEEK(n)         "
    .word $0000             ; SADD()    none
    .word LAB_PPFS-1        ; LEN($)    process string expression in ()
    .word LAB_PPFN-1        ; STR$(n)   process numeric expression in ()
    .word LAB_PPFS-1        ; VAL($)    process string expression in ()
    .word LAB_PPFS-1        ; ASC($)          "
    .word LAB_PPFS-1        ; UCASE$($)       "
    .word LAB_PPFS-1        ; LCASE$($)       "
    .word LAB_PPFN-1        ; CHR$(n)   process numeric expression in ()
    .word LAB_BHSS-1        ; HEX$(n)         "
    .word LAB_BHSS-1        ; BIN$(n)         "
    .word $0000             ; BITTST()  none
    .word LAB_MMPP-1        ; MAX()     process numeric expression
    .word LAB_MMPP-1        ; MIN()           "
    .word LAB_PPBI-1        ; PI        advance pointer
    .word LAB_PPBI-1        ; TWOPI           "
    .word $0000             ; VARPTR()  none
    .word LAB_LRMS-1        ; LEFT$()   process string expression
    .word LAB_LRMS-1        ; RIGHT$()        "
    .word LAB_LRMS-1        ; MID$()          "

; action addresses for functions
LAB_FTBL:
LAB_FTBM = LAB_FTBL+$01
    .word basic_SGN-1         ; SGN()
    .word LAB_INT-1         ; INT()
    .word func_ABS-1         ; ABS()
    .word func_USR-1         ; USR()
    .word LAB_FRE-1         ; FRE()
    .word basic_POS-1         ; POS()
    .word LAB_SQR-1         ; SQR()
    .word LAB_RND-1         ; RND()           modified function
    .word LAB_LOG-1         ; LOG()
    .word LAB_EXP-1         ; EXP()
    .word func_COS-1         ; COS()
    .word func_SIN-1         ; SIN()
    .word func_TAN-1         ; TAN()
    .word func_ATN-1         ; ATN()
    .word LAB_PEEK-1        ; PEEK()
    .word LAB_DEEK-1        ; DEEK()          new function
    .word LAB_SADD-1        ; SADD()          new function
    .word LAB_LENS-1        ; LEN()
    .word LAB_STRS-1        ; STR$()
    .word LAB_VAL-1         ; VAL()
    .word LAB_ASC-1         ; ASC()
    .word LAB_UCASE-1       ; UCASE$()        new function
    .word LAB_LCASE-1       ; LCASE$()        new function
    .word LAB_CHRS-1        ; CHR$()
    .word func_HEXS-1        ; HEX$()          new function
    .word LAB_BINS-1        ; BIN$()          new function
    .word func_BTST-1        ; BITTST()        new function
    .word LAB_MAX-1         ; MAX()           new function
    .word LAB_MIN-1         ; MIN()           new function
    .word LAB_PI-1          ; PI              new function
    .word LAB_TWOPI-1       ; TWOPI           new function
    .word LAB_VARPTR-1      ; VARPTR()        new function
    .word LAB_LEFT-1        ; LEFT$()
    .word LAB_RIGHT-1       ; RIGHT$()
    .word LAB_MIDS-1        ; MID$()

; hierarchy and action addresses for operator
LAB_OPPT:
    .byte $79               ; +
    .word LAB_ADD-1
    .byte $79               ; -
    .word LAB_SUBTRACT-1
    .byte $7B               ; *
    .word LAB_MULTIPLY-1
    .byte $7B               ; /
    .word LAB_DIVIDE-1
    .byte $7F               ; ^
    .word LAB_POWER-1
    .byte $50               ; AND
    .word LAB_AND-1
    .byte $46               ; EOR             new operator
    .word LAB_EOR-1
    .byte $46               ; OR
    .word LAB_OR-1
    .byte $56               ; >>              new operator
    .word LAB_RSHIFT-1
    .byte $56               ; <<              new operator
    .word LAB_LSHIFT-1
    .byte $7D               ; >
    .word LAB_GTHAN-1
    .byte $5A               ; =
    .word LAB_EQUAL-1
    .byte $64               ; <
    .word LAB_LTHAN-1

; keywords start with ..
; this is the first character table and must be in alphabetic order
TAB_1STC:
    .byte "*"
    .byte "+"
    .byte "-"
    .byte "/"
    .byte "<"
    .byte "="
    .byte ">"
    .byte "?"
    .byte "A"
    .byte "B"
    .byte "C"
    .byte "D"
    .byte "E"
    .byte "F"
    .byte "G"
    .byte "H"
    .byte "I"
    .byte "L"
    .byte "M"
    .byte "N"
    .byte "O"
    .byte "P"
    .byte "R"
    .byte "S"
    .byte "T"
    .byte "U"
    .byte "V"
    .byte "W"
    .byte "^"
    .byte $00               ; table terminator

; pointers to keyword tables
TAB_CHRT:
    .word TAB_STAR          ; table for "*"
    .word TAB_PLUS          ; table for "+"
    .word TAB_MNUS          ; table for "-"
    .word TAB_SLAS          ; table for "/"
    .word TAB_LESS          ; table for "<"
    .word TAB_EQUL          ; table for "="
    .word TAB_MORE          ; table for ">"
    .word TAB_QEST          ; table for "?"
    .word TAB_ASCA          ; table for "A"
    .word TAB_ASCB          ; table for "B"
    .word TAB_ASCC          ; table for "C"
    .word TAB_ASCD          ; table for "D"
    .word TAB_ASCE          ; table for "E"
    .word TAB_ASCF          ; table for "F"
    .word TAB_ASCG          ; table for "G"
    .word TAB_ASCH          ; table for "H"
    .word TAB_ASCI          ; table for "I"
    .word TAB_ASCL          ; table for "L"
    .word TAB_ASCM          ; table for "M"
    .word TAB_ASCN          ; table for "N"
    .word TAB_ASCO          ; table for "O"
    .word TAB_ASCP          ; table for "P"
    .word TAB_ASCR          ; table for "R"
    .word TAB_ASCS          ; table for "S"
    .word TAB_ASCT          ; table for "T"
    .word TAB_ASCU          ; table for "U"
    .word TAB_ASCV          ; table for "V"
    .word TAB_ASCW          ; table for "W"
    .word TAB_POWR          ; table for "^"

; tables for each start character, note if a longer keyword with the same start
; letters as a shorter one exists then it must come first, else the list is in
; alphabetical order as follows ..

; [keyword,token
; [keyword,token]]
; end marker (#$00)

TAB_STAR
      .byte token_MUL,$00        ; *
TAB_PLUS
      .byte token_PLUS,$00       ; +
TAB_MNUS
      .byte token_MINUS,$00      ; -
TAB_SLAS
      .byte token_DIV,$00        ; /
TAB_LESS
LBB_LSHIFT
      .byte "<",token_LSHIFT     ; <<  note - "<<" must come before "<"
      .byte token_LT             ; <
      .byte $00
TAB_EQUL
      .byte token_EQUAL,$00      ; =
TAB_MORE
LBB_RSHIFT
      .byte ">",token_RSHIFT     ; >>  note - ">>" must come before ">"
      .byte token_GT             ; >
      .byte $00
TAB_QEST
      .byte token_PRINT,$00      ; ?
TAB_ASCA
LBB_ABS
      .byte "BS(",token_ABS      ; ABS(
LBB_AND
      .byte "ND",token_AND       ; AND
LBB_ASC
      .byte "SC(",token_ASC      ; ASC(
LBB_ATN
      .byte "TN(",token_ATN      ; ATN(
      .byte $00
TAB_ASCB
LBB_BINS
      .byte "IN$(",token_BINS    ; BIN$(
LBB_BITCLR
      .byte "ITCLR",token_BITCLR ; BITCLR
LBB_BITSET
      .byte "ITSET",token_BITSET ; BITSET
LBB_BITTST
      .byte "ITTST(",token_BITTST
                              ; BITTST(
      .byte $00
TAB_ASCC
LBB_CALL
      .byte "ALL",token_CALL     ; CALL
LBB_CHRS
      .byte "HR$(",token_CHRS    ; CHR$(
LBB_CLEAR
      .byte "LEAR",token_CLEAR   ; CLEAR
LBB_CONT
      .byte "ONT",token_CONT     ; CONT
LBB_COS
      .byte "OS(",token_COS      ; COS(
      .byte $00
TAB_ASCD
LBB_DATA
      .byte "ATA",token_DATA     ; DATA
LBB_DEC
      .byte "EC",token_DEC       ; DEC
LBB_DEEK
      .byte "EEK(",token_DEEK    ; DEEK(
LBB_DEF
      .byte "EF",token_DEF       ; DEF
LBB_DIM
      .byte "IM",token_DIM       ; DIM
LBB_DOKE
      .byte "OKE",token_DOKE     ; DOKE note - "DOKE" must come before "DO"
LBB_DO
      .byte "O",token_DO         ; DO
      .byte $00
TAB_ASCE
LBB_ELSE
      .byte "LSE",token_ELSE     ; ELSE
LBB_END
      .byte "ND",token_END       ; END
LBB_EOR
      .byte "OR",token_EOR       ; EOR
LBB_EXP
      .byte "XP(",token_EXP      ; EXP(
      .byte $00
TAB_ASCF
LBB_FN
      .byte "N",token_FN         ; FN
LBB_FOR
      .byte "OR",token_FOR       ; FOR
LBB_FRE
      .byte "RE(",token_FRE      ; FRE(
      .byte $00
TAB_ASCG
LBB_GET
      .byte "ET",token_GET       ; GET
LBB_GOSUB
      .byte "OSUB",token_GOSUB   ; GOSUB
LBB_GOTO
      .byte "OTO",token_GOTO     ; GOTO
      .byte $00
TAB_ASCH
LBB_HEXS
      .byte "EX$(",token_HEXS    ; HEX$(
      .byte $00
TAB_ASCI
LBB_IF
      .byte "F",token_IF         ; IF
LBB_INC
      .byte "NC",token_INC       ; INC
LBB_INPUT
      .byte "NPUT",token_INPUT   ; INPUT
LBB_INT
      .byte "NT(",token_INT      ; INT(
LBB_IRQ
      .byte "RQ",token_IRQ       ; IRQ
      .byte $00
TAB_ASCL
LBB_LCASES
      .byte "CASE$(",token_LCASES
                              ; LCASE$(
LBB_LEFTS
      .byte "EFT$(",token_LEFTS  ; LEFT$(
LBB_LEN
      .byte "EN(",token_LEN      ; LEN(
LBB_LET
      .byte "ET",token_LET       ; LET
LBB_LIST
      .byte "IST",token_LIST     ; LIST
LBB_LOAD
      .byte "OAD",token_LOAD     ; LOAD
LBB_LOG
      .byte "OG(",token_LOG      ; LOG(
LBB_LOOP
      .byte "OOP",token_LOOP     ; LOOP
      .byte $00
TAB_ASCM
LBB_MAX
      .byte "AX(",token_MAX      ; MAX(
LBB_MIDS
      .byte "ID$(",token_MIDS    ; MID$(
LBB_MIN
      .byte "IN(",token_MIN      ; MIN(
      .byte $00
TAB_ASCN
LBB_NEW
      .byte "EW",token_NEW       ; NEW
LBB_NEXT
      .byte "EXT",token_NEXT     ; NEXT
LBB_NMI
      .byte "MI",token_NMI       ; NMI
LBB_NOT
      .byte "OT",token_NOT       ; NOT
LBB_NULL
      .byte "ULL",token_NULL     ; NULL
      .byte $00
TAB_ASCO
LBB_OFF
      .byte "FF",token_OFF       ; OFF
LBB_ON
      .byte "N",token_ON         ; ON
LBB_OR
      .byte "R",token_OR         ; OR
      .byte $00
TAB_ASCP
LBB_PEEK
      .byte "EEK(",token_PEEK    ; PEEK(
LBB_PI
      .byte "I",token_PI         ; PI
LBB_POKE
      .byte "OKE",token_POKE     ; POKE
LBB_POS
      .byte "OS(",token_POS      ; POS(
LBB_PRINT
      .byte "RINT",token_PRINT   ; PRINT
      .byte $00
TAB_ASCR
LBB_READ
      .byte "EAD",token_READ     ; READ
LBB_REM
      .byte "EM",token_REM       ; REM
LBB_RESTORE
      .byte "ESTORE",token_RESTORE
                              ; RESTORE
LBB_RETIRQ
      .byte "ETIRQ",token_RETIRQ ; RETIRQ
LBB_RETNMI
      .byte "ETNMI",token_RETNMI ; RETNMI
LBB_RETURN
      .byte "ETURN",token_RETURN ; RETURN
LBB_RIGHTS
      .byte "IGHT$(",token_RIGHTS
                              ; RIGHT$(
LBB_RND
      .byte "ND(",token_RND      ; RND(
LBB_RUN
      .byte "UN",token_RUN       ; RUN
      .byte $00
TAB_ASCS
LBB_SADD
      .byte "ADD(",token_SADD    ; SADD(
LBB_SAVE
      .byte "AVE",token_SAVE     ; SAVE
LBB_SGN
      .byte "GN(",token_SGN      ; SGN(
LBB_SIN
      .byte "IN(",token_SIN      ; SIN(
LBB_SPC
      .byte "PC(",token_SPC      ; SPC(
LBB_SQR
      .byte "QR(",token_SQR      ; SQR(
LBB_STEP
      .byte "TEP",token_STEP     ; STEP
LBB_STOP
      .byte "TOP",token_STOP     ; STOP
LBB_STRS
      .byte "TR$(",token_STRS    ; STR$(
LBB_SWAP
      .byte "WAP",token_SWAP     ; SWAP
      .byte $00
TAB_ASCT
LBB_TAB
      .byte "AB(",token_TAB      ; TAB(
LBB_TAN
      .byte "AN(",token_TAN      ; TAN(
LBB_THEN
      .byte "HEN",token_THEN     ; THEN
LBB_TO
      .byte "O",token_TO         ; TO
LBB_TWOPI
      .byte "WOPI",token_TWOPI   ; TWOPI
      .byte $00
TAB_ASCU
LBB_UCASES
      .byte "CASE$(",token_UCASES
                              ; UCASE$(
LBB_UNTIL
      .byte "NTIL",token_UNTIL   ; UNTIL
LBB_USR
      .byte "SR(",token_USR      ; USR(
      .byte $00
TAB_ASCV
LBB_VAL
      .byte "AL(",token_VAL      ; VAL(
LBB_VPTR
      .byte "ARPTR(",token_VPTR  ; VARPTR(
      .byte $00
TAB_ASCW
LBB_WAIT
      .byte "AIT",token_WAIT     ; WAIT
LBB_WHILE
      .byte "HILE",token_WHILE   ; WHILE
LBB_WIDTH
      .byte "IDTH",token_WIDTH   ; WIDTH
      .byte $00
TAB_POWR
      .byte token_POWER,$00      ; ^

; new decode table for LIST
; Table is ..
; byte - keyword length, keyword first character
; word - pointer to rest of keyword from dictionary
; note if length is 1 then the pointer is ignored
LAB_KEYT:
      .byte 3,'E'
      .word LBB_END           ; END
      .byte 3,'F'
      .word LBB_FOR           ; FOR
      .byte 4,'N'
      .word LBB_NEXT          ; NEXT
      .byte 4,'D'
      .word LBB_DATA          ; DATA
      .byte 5,'I'
      .word LBB_INPUT         ; INPUT
      .byte 3,'D'
      .word LBB_DIM           ; DIM
      .byte 4,'R'
      .word LBB_READ          ; READ
      .byte 3,'L'
      .word LBB_LET           ; LET
      .byte 3,'D'
      .word LBB_DEC           ; DEC
      .byte 4,'G'
      .word LBB_GOTO          ; GOTO
      .byte 3,'R'
      .word LBB_RUN           ; RUN
      .byte 2,'I'
      .word LBB_IF            ; IF
      .byte 7,'R'
      .word LBB_RESTORE       ; RESTORE
      .byte 5,'G'
      .word LBB_GOSUB         ; GOSUB
      .byte 6,'R'
      .word LBB_RETIRQ        ; RETIRQ
      .byte 6,'R'
      .word LBB_RETNMI        ; RETNMI
      .byte 6,'R'
      .word LBB_RETURN        ; RETURN
      .byte 3,'R'
      .word LBB_REM           ; REM
      .byte 4,'S'
      .word LBB_STOP          ; STOP
      .byte 2,'O'
      .word LBB_ON            ; ON
      .byte 4,'N'
      .word LBB_NULL          ; NULL
      .byte 3,'I'
      .word LBB_INC           ; INC
      .byte 4,'W'
      .word LBB_WAIT          ; WAIT
      .byte 4,'L'
      .word LBB_LOAD          ; LOAD
      .byte 4,'S'
      .word LBB_SAVE          ; SAVE
      .byte 3,'D'
      .word LBB_DEF           ; DEF
      .byte 4,'P'
      .word LBB_POKE          ; POKE
      .byte 4,'D'
      .word LBB_DOKE          ; DOKE
      .byte 4,'C'
      .word LBB_CALL          ; CALL
      .byte 2,'D'
      .word LBB_DO            ; DO
      .byte 4,'L'
      .word LBB_LOOP          ; LOOP
      .byte 5,'P'
      .word LBB_PRINT         ; PRINT
      .byte 4,'C'
      .word LBB_CONT          ; CONT
      .byte 4,'L'
      .word LBB_LIST          ; LIST
      .byte 5,'C'
      .word LBB_CLEAR         ; CLEAR
      .byte 3,'N'
      .word LBB_NEW           ; NEW
      .byte 5,'W'
      .word LBB_WIDTH         ; WIDTH
      .byte 3,'G'
      .word LBB_GET           ; GET
      .byte 4,'S'
      .word LBB_SWAP          ; SWAP
      .byte 6,'B'
      .word LBB_BITSET        ; BITSET
      .byte 6,'B'
      .word LBB_BITCLR        ; BITCLR
      .byte 3,'I'
      .word LBB_IRQ           ; IRQ
      .byte 3,'N'
      .word LBB_NMI           ; NMI

; secondary commands (can't start a statement)
      .byte 4,'T'
      .word LBB_TAB           ; TAB
      .byte 4,'E'
      .word LBB_ELSE          ; ELSE
      .byte 2,'T'
      .word LBB_TO            ; TO
      .byte 2,'F'
      .word LBB_FN            ; FN
      .byte 4,'S'
      .word LBB_SPC           ; SPC
      .byte 4,'T'
      .word LBB_THEN          ; THEN
      .byte 3,'N'
      .word LBB_NOT           ; NOT
      .byte 4,'S'
      .word LBB_STEP          ; STEP
      .byte 5,'U'
      .word LBB_UNTIL         ; UNTIL
      .byte 5,'W'
      .word LBB_WHILE         ; WHILE
      .byte 3,'O'
      .word LBB_OFF           ; OFF

; opperators
      .byte 1,'+'
      .word $0000             ; +
      .byte 1,'-'
      .word $0000             ; -
      .byte 1,'*'
      .word $0000             ; *
      .byte 1,'/'
      .word $0000             ; /
      .byte 1,'^'
      .word $0000             ; ^
      .byte 3,'A'
      .word LBB_AND           ; AND
      .byte 3,'E'
      .word LBB_EOR           ; EOR
      .byte 2,'O'
      .word LBB_OR            ; OR
      .byte 2,'>'
      .word LBB_RSHIFT        ; >>
      .byte 2,'<'
      .word LBB_LSHIFT        ; <<
      .byte 1,'>'
      .word $0000             ; >
      .byte 1,'='
      .word $0000             ; =
      .byte 1,'<'
      .word $0000             ; <

; functions

      .byte 4,'S'             ;
      .word LBB_SGN           ; SGN
      .byte 4,'I'             ;
      .word LBB_INT           ; INT
      .byte 4,'A'             ;
      .word LBB_ABS           ; ABS
      .byte 4,'U'             ;
      .word LBB_USR           ; USR
      .byte 4,'F'             ;
      .word LBB_FRE           ; FRE
      .byte 4,'P'             ;
      .word LBB_POS           ; POS
      .byte 4,'S'             ;
      .word LBB_SQR           ; SQR
      .byte 4,'R'             ;
      .word LBB_RND           ; RND
      .byte 4,'L'             ;
      .word LBB_LOG           ; LOG
      .byte 4,'E'             ;
      .word LBB_EXP           ; EXP
      .byte 4,'C'             ;
      .word LBB_COS           ; COS
      .byte 4,'S'             ;
      .word LBB_SIN           ; SIN
      .byte 4,'T'             ;
      .word LBB_TAN           ; TAN
      .byte 4,'A'             ;
      .word LBB_ATN           ; ATN
      .byte 5,'P'             ;
      .word LBB_PEEK          ; PEEK
      .byte 5,'D'             ;
      .word LBB_DEEK          ; DEEK
      .byte 5,'S'             ;
      .word LBB_SADD          ; SADD
      .byte 4,'L'             ;
      .word LBB_LEN           ; LEN
      .byte 5,'S'             ;
      .word LBB_STRS          ; STR$
      .byte 4,'V'             ;
      .word LBB_VAL           ; VAL
      .byte 4,'A'             ;
      .word LBB_ASC           ; ASC
      .byte 7,'U'             ;
      .word LBB_UCASES        ; UCASE$
      .byte 7,'L'             ;
      .word LBB_LCASES        ; LCASE$
      .byte 5,'C'             ;
      .word LBB_CHRS          ; CHR$
      .byte 5,'H'             ;
      .word LBB_HEXS          ; HEX$
      .byte 5,'B'             ;
      .word LBB_BINS          ; BIN$
      .byte 7,'B'             ;
      .word LBB_BITTST        ; BITTST
      .byte 4,'M'             ;
      .word LBB_MAX           ; MAX
      .byte 4,'M'             ;
      .word LBB_MIN           ; MIN
      .byte 2,'P'             ;
      .word LBB_PI            ; PI
      .byte 5,'T'             ;
      .word LBB_TWOPI         ; TWOPI
      .byte 7,'V'             ;
      .word LBB_VPTR          ; VARPTR
      .byte 6,'L'             ;
      .word LBB_LEFTS         ; LEFT$
      .byte 7,'R'             ;
      .word LBB_RIGHTS        ; RIGHT$
      .byte 5,'M'             ;
      .word LBB_MIDS          ; MID$

; BASIC messages, mostly error messages
LAB_BAER:
    .word ERR_NF            ;$00 NEXT without FOR
    .word ERR_SN            ;$02 syntax
    .word ERR_RG            ;$04 RETURN without GOSUB
    .word ERR_OD            ;$06 out of data
    .word ERR_FC            ;$08 function call
    .word ERR_OV            ;$0A overflow
    .word ERR_OM            ;$0C out of memory
    .word ERR_US            ;$0E undefined statement
    .word ERR_BS            ;$10 array bounds
    .word ERR_DD            ;$12 double dimension array
    .word ERR_D0            ;$14 divide by 0
    .word ERR_ID            ;$16 illegal direct
    .word ERR_TM            ;$18 type mismatch
    .word ERR_LS            ;$1A long string
    .word ERR_ST            ;$1C string too complex
    .word ERR_CN            ;$1E continue error
    .word ERR_UF            ;$20 undefined function
    .word ERR_LD            ;$22 LOOP without DO

; I may implement these two errors to force definition of variables and
; dimensioning of arrays before use.
;     .word ERR_UV            ;$24 undefined variable
; the above error has been tested and works (see code and comments below LAB_1D8B)
;     .word ERR_UA            ;$26 undimensioned array
ERR_NF  .asciiz "NEXT without FOR"
ERR_SN  .asciiz "Syntax"
ERR_RG  .asciiz "RETURN without GOSUB"
ERR_OD  .asciiz "Out of DATA"
ERR_FC  .asciiz "Function call"
ERR_OV  .asciiz "Overflow"
ERR_OM  .asciiz "Out of memory"
ERR_US  .asciiz "Undefined statement"
ERR_BS  .asciiz "Array bounds"
ERR_DD  .asciiz "Double dimension"
ERR_D0  .asciiz "Divide by zero"
ERR_ID  .asciiz "Illegal direct"
ERR_TM  .asciiz "Type mismatch"
ERR_LS  .asciiz "String too long"
ERR_ST  .asciiz "String too complex"
ERR_CN  .asciiz "Can't continue"
ERR_UF  .asciiz "Undefined function"
ERR_LD  .asciiz "LOOP without DO"
;ERR_UV  .asciiz "Undefined variable"
; the above error has been tested and works (see code and comments below LAB_1D8B)
;ERR_UA  .asciiz "Undimensioned array"
LAB_BMSG    .byte $0D,$0A,"Break",$00
LAB_EMSG    .asciiz " Error"
LAB_LMSG    .asciiz " in line "
LAB_RMSG    .byte $0D,$0A,"Ready",$0D,$0A,$00
LAB_IMSG    .byte " Extra ignored",$0D,$0A,$00
LAB_REDO    .byte " Redo from start",$0D,$0A,$00

AA_end_basic

; put the IRQ and MNI code in RAM so that it can be changed

IRQ_vec     = VEC_SV+2        ; IRQ code vector
NMI_vec     = IRQ_vec+$0A     ; NMI code vector

; set up vectors and interrupt code, copy them to page 2

BASIC_init
    ldy   #END_CODE-LAB_vec ; set index/count
LAB_stlp
    lda   LAB_vec-1,Y       ; get byte from interrupt code
    sta   VEC_IN-1,Y        ; save to RAM
    dey                     ; decrement index/count
    bne   LAB_stlp          ; loop if more to do

; now do the signon message, Y = $00 here

LAB_signon
    lda   LAB_mess,Y        ; get byte from sign on message
    beq   LAB_nokey         ; exit loop if done

    jsr   V_OUTP            ; output character
    iny                     ; increment index
    bne   LAB_signon        ; loop, branch always

LAB_nokey
    jsr   V_INPT            ; call scan input device
    bcc   LAB_nokey         ; loop if no key

    and   #$DF              ; mask xx0x xxxx, ensure upper case
    cmp   #'W'              ; compare with [W]arm start
    beq   LAB_dowarm        ; branch if [W]arm start

    cmp   #'C'              ; compare with [C]old start
    bne   BASIC_init        ; loop if not [C]old start

    jmp   cold_start        ; do EhBASIC cold start

LAB_dowarm
    jmp   warm_start        ; do EhBASIC warm start

ACIAout:
    jsr TTY_write_char
    rts

ACIAin:
    jsr TTY_read_char
    bcc LAB_nobyw       ; No char avail
    cmp #'a'            ; Is it < 'a'?
    bcc @done           ; Yes, we're done
    cmp #'{'            ; Is it >= '{'?
    bcs @done           ; Yes, we're done
    and #$5f            ; Otherwise, mask to uppercase
@done
    sec                 ; Flag byte received
    rts
LAB_nobyw
    clc
no_load                       ; empty load vector for EhBASIC
no_save                       ; empty save vector for EhBASIC
    rts

; vector tables

LAB_vec
    .word ACIAin            ; byte in from simulated ACIA
    .word ACIAout           ; byte out to simulated ACIA
    .word no_load           ; null load vector for EhBASIC
    .word no_save           ; null save vector for EhBASIC

; EhBASIC IRQ support

IRQ_CODE
    pha                     ; save A
    lda   IrqBase           ; get the IRQ flag byte
    lsr                     ; shift the set b7 to b6, and on down ...
    ora   IrqBase           ; OR the original back in
    sta   IrqBase           ; save the new IRQ flag byte
    pla                     ; restore A
    RTI

; EhBASIC NMI support

NMI_CODE
    pha                     ; save A
    lda   NmiBase           ; get the NMI flag byte
    lsr                     ; shift the set b7 to b6, and on down ...
    ora   NmiBase           ; OR the original back in
    sta   NmiBase           ; save the new NMI flag byte
    pla                     ; restore A
    RTI

END_CODE

LAB_mess
    .byte $0D,$0A,"6502 EhBASIC [C]old/[W]arm ?",$00
                              ; sign on string
