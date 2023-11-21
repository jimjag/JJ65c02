.include "minios.inc"
.include "sysram.inc"
;.include "lcd.inc"
.include "via.inc"
;.include "sound.inc"
.include "lib.inc"
.include "acia.inc"
.include "tty.inc"
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
;      . $0500 - $9fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
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
    ;jsr MINIOS_test_ram_core
    stz MINIOS_STATUS
    ;bcs @continue
    lda #(MINIOS_RAM_TEST_PASS_FLAG)
    tsb MINIOS_STATUS

@continue:
    lda #1
    sta CLK_SPD                                 ; Assume a 1Mhz clock to start

    ;lda #<ISR_HANDLER
    ;sta ISR_VECTOR
    ;lda #>ISR_HANDLER
    ;sta ISR_VECTOR + 1

    ; Init the ACIA and VIA chips
    jsr ACIA_init
    jsr TTY_setup_term
    TTY_writeln welcome_msg
    jsr VIA_init
    jsr CON_init
    CON_writeln welcome_msg

    ; Are we serial enabled?
    lda #(MINIOS_ACIA_ENABLED_FLAG)
    bit MINIOS_STATUS
    beq @no_acia
    TTY_writeln message_welcomeacia
    CON_writeln message_welcomeacia
    bra @welcome
@no_acia:
    CON_writeln message_welcome                 ; render the boot screen

@welcome:
    cli                                         ; interupts are back on
    lda #(MINIOS_RAM_TEST_PASS_FLAG)
    bit MINIOS_STATUS
    beq @ram_failed
    lda #'+'
    bra @cont2
@ram_failed:
    lda #'-'
@cont2:
    jsr CON_write_byte_data
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


@select_option:
    clc
    lda #0                                      ; clear A
    adc POSITION_MENU
    adc POSITION_CURSOR                         ; calculate index of selected option
    cmp #0                                      ; branch trough all options
    beq @load_and_run
    cmp #1
    beq @load
    cmp #2
    beq @run
    cmp #3
    beq @go_wozmon
    cmp #4
    beq @clear_ram
    cmp #5
    beq @test_ram
    cmp #6
    beq @adj_clock
    cmp #7
    beq @start_basic
    cmp #8
    beq @about
    cmp #9
    beq @thanks
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
@adj_clock:
    jsr MINIOS_adj_clock
    jmp @start
@start_basic:
    lda #100                                    ; wait a bit, say 100ms
    jsr LIB_delay1ms
    CON_writeln message_readybasic
    beq @go_basic
    jmp @start
@go_basic:
    jsr BASIC_init
    jmp @start
@about:                                         ; start the about routine
    CON_writeln about
    jmp @start
@thanks:                                        ; start the thanks routine
    CON_writeln thanks
    jmp @start
@do_load:                                       ; orchestration of program loading
    lda #100                                    ; wait a bit, say 100ms
    jsr LIB_delay1ms
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
    beq @start_load
    rts
@start_load:
    jmp YMODEM_recv

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
;   MINIOS_adj_clock - Changes the internal setting for the clock speed (CLK_SPD).
;
;   This routine simply updates the internal setting for the clock speed of the
;   system, in Mhz. This only currently affects LIB_delay1ms so that depending
;   on the setting here, and it matching the actual clock speed, we get close
;   to an actual 10ms delay
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

MINIOS_adj_clock:
    pha                                         ; Save .A, .X, .Y
    phx
    phy
    lda CLK_SPD
    sta Z2
@redisplay:

@wait_for_input:                                ; wait for key press
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:                         ; determine action for key pressed
    cmp #(VIA_up_key)
    beq @increase_spd                           ; UP key pressed
    cmp #(VIA_down_key)
    beq @decrease_spd                           ; DOWN key pressed
    cmp #(VIA_left_key)
    beq @exit_adj                               ; LEFT key pressed
    cmp #(VIA_right_key)
    beq @save_spd                               ; RIGHT key pressed
    bne @wait_for_input
@increase_spd:
    lda Z2
    cmp #8
    beq @redisplay
    inc Z2
    bne @redisplay
@decrease_spd:
    lda Z2
    cmp #1
    beq @redisplay
    dec Z2
    bne @redisplay
@save_spd:
    lda Z2
    sta CLK_SPD
    CON_writeln message9
    lda #10
    jsr LIB_delay100ms                          ; let them see know it
    jmp @redisplay
@exit_adj:
    ply                                         ; Restore .Y, .X, .A
    plx
    pla
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

message_welcome:
    .asciiz "      JJ65c02"
    .asciiz "   miniOS v2.0"
message_welcomeacia:
    .asciiz "      JJ65c02"
    .asciiz "  miniOS v2.0 ACIA"
message_cmd:
    .asciiz "Enter Command..."
message_readybasic:
    .asciiz "Starting EhBASIC"
    .asciiz "Press any key on console to start: "
message_readyload:
    .asciiz "Getting Ready To LOAD RAM.
    .asciiz "Press any key on console to start: "
message_waitdata:
    .asciiz "Awaiting data..."
message_loaddone:
    .asciiz "Loading done!"
message_runprog:
    .asciiz "Running RAM@$0500"
message_ramclean:
    .asciiz "Cleaning RAM..."
message_ramtest:
    .asciiz "Testing RAM..."
message_pass:
    .asciiz "PASS"
message_fail:
    .asciiz "FAIL"
menu_items:
    .asciiz "1. Load & Run"
    .asciiz "2. Load"
    .asciiz "3. Run"
    .asciiz "4. WOZMON"
    .asciiz "5. Clear RAM"
    .asciiz "6. Test RAM"
    .asciiz "7. Adjust Clk Speed"
    .asciiz "8. Run EhBASIC Interpreter"
    .asciiz "9. About"
about:
    .addr a1, a2, $0000
a1: .asciiz "github.com/"
a2: .asciiz "    jimjag/JJ65c02"

clock_spd:
    .byte " Clock: % Mhz"
message9:
    .asciiz "Clk Spd Saved"

.segment "VECTORS"

    .word $0000
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine
