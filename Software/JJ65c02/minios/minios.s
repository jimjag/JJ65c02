.include "minios.inc"
.include "sysram.inc"
.include "lcd.inc"
.include "via.inc"
;.include "sound.inc"
.include "lib.inc"
.include "acia.inc"
.include "tty.inc"
.include "keyboard.inc"

.import BASIC_init
.export MINIOS_main_menu

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;
;   miniOS: RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $04ff      RAM: miniOS set-aside / Page 2-4
;      . $0500 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8010 - $8fff      IO Blk: 4k
;      . $8010 - $801f      ACIA:
;      . $8020 - $802f      VIA1:
;    $9000 - $ffff      ROM: 28K
;--------

; Actual start of ROM code
.segment "CODE"


;================================================================================
;
;   main - routine to initialize the bootloader
;
;   Initializes the bootloader, LCD, VIA, Video Ram and prints a welcome message
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

    ; Init the 6551
    jsr ACIA_init
    jsr TTY_setup_term
    TTY_writeln welcome_msg

    jsr LCD_clear_video_ram

    ; VIA1_
    jsr VIA_initialize
    jsr LCD_initialize

    ; Are we serial enabled?
    lda #(MINIOS_ACIA_ENABLED_FLAG)
    bit MINIOS_STATUS
    beq @no_acia
    LCD_writeln message_welcomeacia
    TTY_writeln message_welcomeacia
    bra @welcome
@no_acia:
    LCD_writeln message_welcome                 ; render the boot screen

@welcome:
    cli                                         ; interupts are back on
    ldy #0
    ldx #19
    jsr LCD_set_cursor
    lda #(MINIOS_RAM_TEST_PASS_FLAG)
    bit MINIOS_STATUS
    beq @ram_failed
    lda #'+'
    bra @cont2
@ram_failed:
    lda #'-'
@cont2:
    jsr LCD_send_data
    ;jsr Welcome_tone
    jsr MINIOS_main_menu                    ; start the menu routine
    jmp main                                    ; should the menu ever return ...


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
    stz POSITION_MENU
    stz POSITION_CURSOR

    jmp @start
@MAX_SCREEN_POS:                                ; define some constants in ROM
    .byte 6                                     ; its always: number of menu items - LCD_ROWS
@start:                                         ; and off we go
    jsr LCD_clear_video_ram
    ldx POSITION_MENU
    ldy VRAM_OFFSETS,x
                                                ; load first offset into Y
    ldx #0                                      ; set X to 0
@loop:
    lda menu_items,y                            ; load string char for Y
    sta VIDEO_RAM,x                             ; store in video ram at X
    iny
    inx
    cpx #(LCD_SIZE)                             ; fill LCD
    bne @loop

@render_cursor:                                 ; render cursor position based on current state
    lda #'>'
    ldy POSITION_CURSOR
    ldx VRAM_OFFSETS,y
    sta VIDEO_RAM,x

@render:                                        ; and update the screen
    jsr LCD_render

@wait_for_input:                                ; handle keyboard input
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:
    cmp #(VIA_up_key)
    beq @move_up                                ; UP key pressed
    cmp #(VIA_down_key)
    beq @move_down                              ; DOWN key pressed
    cmp #(VIA_right_key)
    beq @select_option                          ; RIGHT key pressed
    bne @wait_for_input                         ; and go around

@move_up:
    lda POSITION_CURSOR                         ; load cursor position
    beq @dec_menu_offset                        ; is cursor in up position? yes?
    dec a                                       ; no?
    sta POSITION_CURSOR                         ; set cursor in up position
    jmp @start                                  ; re-render the whole menu
@dec_menu_offset:
    lda POSITION_MENU
    beq @wait_for_input                         ; yes, just re-render
@decrease:
    dec POSITION_MENU                           ; decrease menu position by one
    jmp @start                                  ; and re-render

@move_down:
    lda POSITION_CURSOR                         ; load cursor position
    cmp #(LCD_ROWS-1)                           ; is cursor in lower position?
    beq @inc_menu_offset                        ; yes?
    inc a                                       ; no?
    sta POSITION_CURSOR                         ; set cursor in lower position
    jmp @start                                  ; and re-render the whole menu
@inc_menu_offset:
    lda POSITION_MENU                           ; load current menu positions
    cmp @MAX_SCREEN_POS                         ; are we at the bottom yet?
    bne @increase                               ; no?
    jmp @wait_for_input                         ; yes
@increase:
    adc #1                                      ; increase menu position
    sta POSITION_MENU
    jmp @start                                  ; and re-render

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
    beq @hexdump
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
@hexdump:                                       ; start up the memory hexdump
    lda #<PROGRAM_START                         ; have it render the start location
    ldy #>PROGRAM_START                         ; can also be set as params during debugging
    jsr HEXDUMP_main
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
    LCD_writeln message_readybasic
    jsr VIA_read_mini_keyboard
    cmp #(VIA_right_key)
    beq @go_basic
    jmp @start
@go_basic:
    jsr LCD_clear_screen
    jsr BASIC_init
    jmp @start
@about:                                         ; start the about routine
    LCD_writetxt about
    jmp @start
@thanks:                                        ; start the thanks routine
    LCD_writetxt thanks
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
    LCD_writeln message_readyload
    jsr VIA_read_mini_keyboard
    cmp #(VIA_right_key)
    beq @start_load
    rts
@start_load:
    jsr LCD_clear_screen
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
    jsr LCD_clear_video_ram                     ; print a message
    LCD_writeln message_runprog
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
    jsr LCD_clear_video_ram                     ; render message
    LCD_writeln message_ramclean

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
    jsr LCD_clear_video_ram                     ; render message
    LCD_writeln message_ramtest
    ldy #1
    ldx #2
    jsr LCD_set_cursor

    ldy #<PROGRAM_START                         ; load start location into zero page
    sty Z0
    lda #>PROGRAM_START
    sta Z1
    jsr MINIOS_test_ram_core
    bcs @failed
    LCD_writeln_direct message_pass
    bra @done
@failed:
    LCD_writeln_direct message_fail
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
;   HEXDUMP_main - RAM/ROM Hexdump (r/o)
;
;   Currently read only, traverses RAM and ROM locations, shows hex data contents
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

HEXDUMP_main:
    sta Z0                                      ; store LSB
    sty Z1                                      ; store MSB

@render_current_ram_location:
    jsr LCD_clear_video_ram

    lda #$00                                    ; select upper row of video ram
    sta Z3                                      ; #TODO
    jsr @transform_contents                     ; load and transform ram and address bytes

    clc                                         ; add offset to address
    lda Z0
    adc #$04
    sta Z0
    bcc @skip
    inc Z1
@skip:
    lda #$01                                    ; select lower row of video ram
    sta Z3
    jsr @transform_contents                     ; load and transform ram and address bytes there

    jsr LCD_render

@wait_for_input:                                ; wait for key press
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:                         ; determine action for key pressed
    cmp #(VIA_up_key)
    beq @move_up                                ; UP key pressed
    cmp #(VIA_down_key)
    beq @move_down                              ; DOWN key pressed
    cmp #(VIA_left_key)
    beq @exit_hexdump                           ; LEFT key pressed
    cmp #(VIA_right_key)
    beq @fast_forward                           ; RIGHT key pressed
    bne @wait_for_input
@exit_hexdump:
    lda #0                                      ; needed for whatever reason
    rts

@move_down:
    jmp @render_current_ram_location            ; no math needed, the address is up to date already
@move_up:
    sec                                         ; decrease the 16bit RAM Pointer
    lda Z0
    sbc #$08
    sta Z0
    lda Z1
    sbc #$00
    sta Z1
    jmp @render_current_ram_location            ; and re-render
@fast_forward:                                  ; add $0800 to current RAM location
    sec
    lda Z0
    adc #$00
    sta Z0
    lda Z1
    adc #$04
    sta Z1
    jmp @render_current_ram_location            ; and re-render
@transform_contents:                            ; start reading address and ram contents into stack
    ldy #3
@iterate_ram:                                   ; transfer 4 ram bytes to stack
    lda (Z0),y
    pha
    dey
    bne @iterate_ram
    lda (Z0),y
    pha

    lda Z0                                      ; transfer the matching address bytes to stack too
    pha
    lda Z1
    pha

    ldy #0
@iterate_stack:                                 ; transform stack contents from bin to hex
    cpy #6
    beq @end_mon
    sty Z2                                      ; preserve Y #TODO
    pla
    jsr LIB_bin_to_hex
    ldy Z2                                      ; restore Y
    pha                                         ; push least sign. nibble (LSN) onto stack
    phx                                         ; push most sign. nibble (MSN) too

    tya                                         ; calculate nibble positions in video ram
    adc MON_position_map,y                      ; use the static map for that
    tax
    pla
    jsr @store_nibble                           ; store MSN to video ram
    inx
    pla
    jsr @store_nibble                           ; store LSN to video ram

    iny
    jmp @iterate_stack                          ; repeat for all 6 bytes on stack
@store_nibble:                                  ; subroutine to store nibbles in two lcd rows
    pha
    lda Z3
    beq @store_upper_line                       ; should we store in upper line? yes
    pla                                         ; no, store in lower line
    sta VIDEO_RAM+LCD_COLS,x
    jmp @end_store
@store_upper_line:                              ; upper line storage
    pla
    sta VIDEO_RAM,x
@end_store:
    rts
@end_mon:
    lda #':'                                    ; writing the two colons
    sta VIDEO_RAM+4
    sta VIDEO_RAM+4+LCD_COLS
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
    jsr LCD_clear_video_ram
    ldx #0
@fill_vram:
    lda clock_spd,x
    sta VIDEO_RAM,x
    inx
    cpx #13
    bne @fill_vram

    ; Now convert the value of Z2 (from 1 to 8) to ASCII
    lda #'0'
    adc Z2
    ldx #8
    sta VIDEO_RAM,x
    jsr LCD_render

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
    jsr LCD_clear_video_ram
    LCD_writeln message9
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
    ; First see if this was an ACIA IRQ
    bit ACIA_STATUS
    bpl @not_acia                               ; Nope
    jsr ACIA_ihandler
@not_acia:
@done:
    plx
    pla
    rti


;----------------------------------------------------

.segment "RODATA"

message_welcome:
    .byte "      JJ65c02       "
    .byte "   miniOS v1.2      ", $00
message_welcomeacia:
    .byte "      JJ65c02       "
    .byte "  miniOS v1.2 ACIA  ", $00
message_cmd:
    .asciiz "Enter Command..."
message_readybasic:
    .byte "Starting EhBASIC    "
    .byte "Interpreter via TTY."
    .byte "Press Mini Keyboard "
    .byte "R Button When Ready:", $00
message_readyload:
    .byte "Getting Ready To    "
    .byte "LOAD RAM. Tap Mini  "
    .byte "Keyboard R Button To"
    .byte "Start:              ", $00
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
MON_position_map:
    .byte $00, $01, $03, $05, $07, $09
menu_items:
    .byte " Load & Run         "
    .byte " Load               "
    .byte " Run                "
    .byte " Hexdump            "
    .byte " Clear RAM          "
    .byte " Test RAM           "
    .byte " Adjust Clk Speed   "
    .byte " Run BASIC Int      "
    .byte " About              "
    .byte " Thanks             "
about:
    .addr a1, a2, $0000
a1: .asciiz "github.com/"
a2: .asciiz "    jimjag/JJ65c02"

thanks:
    .addr c1, c2, c3, c4, c5, c6, c7, c8, $0000
c1: .asciiz "Ben Eater"
c2: .asciiz "  BE6502 Project"
c3: .asciiz "Jan Roesner"
c4: .asciiz "  Orig sixty/5o2"
c5: .asciiz "Kris Foster"
c6: .asciiz "  Ideas from KrisOS"
c7: .asciiz "Dawid Buchwald"
c8: .asciiz "  Ideas from OS1"

clock_spd:
    .byte " Clock: % Mhz"
message9:
    .asciiz "Clk Spd Saved"

.segment "VECTORS"

    .word $0000
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine
