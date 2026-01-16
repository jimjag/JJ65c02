.include "minios.inc"
.include "sysram.inc"
;.include "lcd.inc"
.include "via.inc"
;.include "sound.inc"
.include "lib.inc"
.include "acia.inc"
.include "tty.inc"
.include "xmodem.inc"
.include "console.inc"

.import BASIC_init
.import WOZMON
.export MINIOS_main_menu

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;
;   miniOS: RAM bootloader and viewer (r/o) w/ TTY and serial connection support
;
;   Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 40k
;      . $0000 - $00ff      RAM: Zero Page
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $04ff      RAM: miniOS set-aside / Page 2-4
;      . $0400 - $9fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;      . $8000 - $9fff      RAM Bank (8K)
;    $A010 - $Afff      IO Blk: 4k
;      . $A010 - $A01f      ACIA:
;      . $A020 - $A02f      VIA1:
;      . $A800              PICO:
;    $B000 - $ffff      ROM: 20K
;--------

; Actual start of ROM code
.segment "CODE"


;================================================================================
;
;   main - routine to initialize the bootloader
;
;   Initializes the bootloader, ACIA, VIA (and Pico) and prints a welcome message
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y, .X
;   ————————————————————————————————————
;
;================================================================================

main:                                           ; boot routine, first thing loaded
    sei                                         ; disable all interupts as we boot
    ldx #$ff                                    ; initialize the stackpointer with 0xff
    txs
    cld
    ; Check RAM - since this is at boot time, we can also check the
    ; RAM set aside for SYSRAM (RAM0 in the cc65 config file)
    ldy #<__RAM0_START__
    sty Z0
    lda #>__RAM0_START__
    sta Z1
    jsr MINIOS_test_ram_core
    stz MINIOS_STATUS
    bcs @continue
    lda #(MINIOS_RAM_TEST_PASS_FLAG)
    tsb MINIOS_STATUS

@continue:
    lda #8
    sta CLK_SPD                                 ; Assume a 8Mhz clock to start

    ;lda #<ISR_HANDLER
    ;sta ISR_VECTOR
    ;lda #>ISR_HANDLER
    ;sta ISR_VECTOR + 1

    ; Init the ACIA and VIA chips
    jsr ACIA_init
    jsr TTY_setup_term
    jsr VIA_init
    lda #0
    jsr LIB_setrambank
    jsr CON_init
    CON_writeln logo
    TTY_writeln logo

    ; Are we serial enabled?
    lda #(MINIOS_ACIA_ENABLED_FLAG)
    bit MINIOS_STATUS
    beq @no_acia
    TTY_writeln message_welcomeacia
    CON_writeln message_welcomeacia
    bra @welcome
@no_acia:
    CON_writeln message_welcome                 ; render the boot screen
    TTY_writeln message_welcome
@welcome:
    ; Show clock speed (compile-time constant)
    CON_writeln clock_spd
    lda CLK_SPD
    clc
    adc #'0'
    jsr CON_write_byte
    CON_writeln new_line
    ; Rest of boot up
    cli                                         ; interupts are back on
    CON_writeln message_ramtest
    lda #(MINIOS_RAM_TEST_PASS_FLAG)
    bit MINIOS_STATUS
    beq @ram_failed
    CON_writeln message_pass
    bra @cont2
@ram_failed:
    CON_writeln message_fail
@cont2:
    jsr CON_read_byte                       ; in case there is junk in the buffer
    jsr MINIOS_main_menu                    ; start the menu routine
    jmp main                                ; should the menu ever return ...


;================================================================================
;
;   MINIOS_main_menu - renders a scrollable menu w/ dynamic number of entries
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

MINIOS_main_menu:
@start:
    CON_writeln new_line
    CON_writeln menu_items
    CON_writeln new_line
    CON_writeln prompt
    jsr CON_read_byte_blk
    sec
    sbc #'0'
@select_option:
    clc
    cmp #1                                      ; branch trough all options
    beq @load_and_run
    cmp #2
    beq @load
    cmp #3
    beq @run
    cmp #4
    beq @go_wozmon
    cmp #5
    beq @clear_ram
    cmp #6
    beq @test_ram
    cmp #7
    beq @start_basic
    cmp #8
    beq @about
    jmp @start                                  ; should we have an invalid option, restart

@load_and_run:                                  ; load and directly run
    jsr @do_load                                ; load first
    jsr @do_run                                 ; run immediately after
    jmp @start                                  ; should a program ever return ...
@load:                                          ; load program and go back into menu
    jsr @do_load
    jmp @start
@run:                                           ; run a program already loaded
    jsr @do_run
    jmp @start
@go_wozmon:                                     ; start up WOZMON
    jsr WOZMON
    jmp @start
@clear_ram:                                     ; start the clear ram routine
    jsr MINIOS_clear_ram
    jmp @start
@test_ram:                                      ; start the test ram routine
    jsr MINIOS_test_ram
    jmp @start
@start_basic:
    CON_writeln message_readybasic
    jsr CON_read_byte_blk
    cmp #'B'
    beq @go_basic
    cmp #'b'
    beq @go_basic
    jmp @start
@go_basic:
    jsr BASIC_init
    jmp @start
@about:                                         ; start the about routine
    CON_writeln about
    jmp @start
@do_load:                                       ; orchestration of program loading
    lda #10                                     ; wait a bit, say 1s
    jsr LIB_delay100ms
    jsr MINIOS_load_ram                         ; call the bootloaders programming routine
    jmp @start
@do_run:                                        ; orchestration of running a program
    jsr MINIOS_execute
    jmp @start

;================================================================================
;
;   MINIOS_load_ram - Load program into RAM space
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

MINIOS_load_ram:
    CON_writeln message_readyload
    jsr CON_read_byte_blk
    cmp #'L'
    beq @start_load
    cmp #'l'
    beq @start_load
    rts
@start_load:
    lda #<PROGRAM_START
    sta YMBLPTR
    lda #>PROGRAM_START
    sta YMBLPTR+1
    jmp XMODEM_recv

;================================================================================
;
;   MINIOS_execute - executes a user program in RAM
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

MINIOS_execute:
    CON_writeln message_runprog
    lda #10                                     ; wait a bit, say 1s
    jsr LIB_delay100ms
    jmp PROGRAM_START                           ; and jump to program location

;================================================================================
;
;   MINIOS_ram_check - checks RAM w/ .A from Z0/Z1 up to PROGRAM_END
;
;   ————————————————————————————————————
;   Preparatory Ops: Z0, Z1: address of start
;
;   Returned Values: none
;
;   Destroys:        .Y, .X
;   ————————————————————————————————————
;
;================================================================================

MINIOS_ram_check:
    ldy #0
@loop:
    cmp (Z0),y
    bne @mem_fail
    inc Z0
    bne @check_end
    inc Z1
@check_end:
    ldx #<PROGRAM_END
    cpx Z0
    bne @loop
    ldx #>PROGRAM_END
    cpx Z1
    bne @loop
    clc
    rts
@mem_fail:
    sec
    rts

;================================================================================
;
;   MINIOS_ram_set - sets RAM w/ .A from Z0/Z1 up to PROGRAM_END
;
;   ————————————————————————————————————
;   Preparatory Ops: Z0, Z1: address of start
;
;   Returned Values: none
;
;   Destroys:        .Y, .X
;   ————————————————————————————————————
;
;================================================================================

MINIOS_ram_set:
    ldy #0
@loop:
    sta (Z0),y                                  ; store it in current location
    inc Z0
    bne @check_end                              ; rollover?
    inc Z1                                      ; Yes, so increment upper address byte
@check_end:
    ldx #<PROGRAM_END
    cpx Z0
    bne @loop
    ldx #>PROGRAM_END
    cpx Z1
    bne @loop
    rts

;================================================================================
;
;   MINIOS_clear_ram - clears RAM from PROGRAM_START up to PROGRAM_END
;
;   Useful during debugging or when using non-volatile RAM chips. Because
;   START and END are arbitrary addresses, we need a super generic routine
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y, .X
;   ————————————————————————————————————
;
;================================================================================

MINIOS_clear_ram:
    CON_writeln message_ramclean

    ldy #<PROGRAM_START                         ; load start location into zero page
    sty Z0
    lda #>PROGRAM_START
    sta Z1
    lda #$00                                    ;  load 0x00 cleaner byte
    jmp MINIOS_ram_set

;================================================================================
;
;   MINIOS_test_ram - clears RAM from PROGRAM_START up to PROGRAM_END
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y, .X
;   ————————————————————————————————————
;
;================================================================================

MINIOS_test_ram:
    CON_writeln message_ramtest
    ldy #<PROGRAM_START                         ; load start location into zero page
    sty Z0
    lda #>PROGRAM_START
    sta Z1
    jsr MINIOS_test_ram_core
    bcs @failed
    CON_writeln message_pass
    bra @done
@failed:
    CON_writeln message_fail
@done:
    lda #10
    jsr LIB_delay100ms                          ; let them see know it
    rts

;================================================================================
;
;   MINIOS_test_ram_core - tests RAM from Z0/Z1 up to PROGRAM_END
;
;   Useful during debugging or when using non-volatile RAM chips. Sets
;   CARRY if error.
;   ————————————————————————————————————
;   Preparatory Ops: Z0, Z1: address of starting range
;
;   Returned Values: none
;
;   Destroys:        .A, .Y, .X
;   ————————————————————————————————————
;
;================================================================================

MINIOS_test_ram_core:
    lda Z0
    sta Z2
    lda Z1
    sta Z3

    lda #$5A
    jsr MINIOS_ram_set
    lda Z2
    sta Z0
    lda Z3
    sta Z1
    lda #$5A
    jsr MINIOS_ram_check
    bcs @skip
    lda Z2
    sta Z0
    lda Z3
    sta Z1
    lda #$A5
    jsr MINIOS_ram_set
    lda Z2
    sta Z0
    lda Z3
    sta Z1
    lda #$A5
    jsr MINIOS_ram_check
@skip:
    rts

;================================================================================
;
;   IRQ - Interrupt Handler
;
;   Just handles reading data from ACIA and VIA for now
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

ISR:
    pha
    phx
    ; First see if this was an ACIA IRQ (for rs232/tty)
    bit ACIA_STATUS
    bpl @not_acia       ; Nope
    jsr ACIA_ihandler
@not_acia:
    ; Check if CA1 interrupt (ps/2 keyboard - Pi Pico)
    lda VIA1_IFR
    and #%00000010
    beq @done
    jsr VIA_ihandler
@done:
    plx
    pla
    rti


;----------------------------------------------------

.segment "RODATA"

logo:
    .asciiz "     _     _  __  ____   ____ ___ ____\r\n    | |   | |/ /_| ___| / ___/ _ \\___ \\\r\n _  | |_  | | '_ \\___ \\| |  | | | |__) |\r\n| |_| | |_| | (_) |__) | |__| |_| / __/\r\n \\___/ \\___/ \\___/____/ \\____\\___/_____|\r\n"
message_welcome:
    .asciiz "      JJ65c02\r\n   miniOS v2.0.0"
message_welcomeacia:
    .asciiz "      JJ65c02\r\n  miniOS v2.0.0 ACIA"
message_cmd:
    .asciiz "Enter Command..."
message_readybasic:
    .asciiz "\r\n Starting EhBASIC\r\n Press 'B' or 'b' key on console to start: "
message_readyload:
    .asciiz "\r\n Getting Ready To LOAD RAM.\r\n Press 'L' or 'l' key on console to start: "
message_waitdata:
    .asciiz "Awaiting data..."
message_loaddone:
    .asciiz "Loading done!"
message_runprog:
    .asciiz "\r\n Running RAM@$0400"
message_ramclean:
    .asciiz "\r\n Cleaning RAM... "
message_ramtest:
    .asciiz "\r\n Testing RAM... "
message_pass:
    .asciiz "PASS"
message_fail:
    .asciiz "FAIL"
menu_items:
    .asciiz "1. Load RAM Image & Run\r\n2. Load RAM Image (via XMODEM)\r\n3. Run Prog Loaded @0400\r\n4. WOZMON\r\n5. Clear RAM\r\n6. Test RAM\r\n7. Run EhBASIC Interpreter\r\n8. About"
about:
    .asciiz "\r\nhttps://github.com/jimjag/JJ65c02"
clock_spd:
    .asciiz " Clock Mhz: "

.segment "VECTORS"

    .word $0000
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine
