.include "minios.inc"
.include "sysram.inc"
.include "lcd.inc"
.include "via.inc"
.include "lib.inc"
.include "acia.inc"
.include "tty.inc"

CURRENT_RAM_ADDRESS = Z0                ; a RAM address handle for indirect writing
CURRENT_RAM_ADDRESS_L = Z0
CURRENT_RAM_ADDRESS_H = Z1
LOADING_STATE = Z2

;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;;
;   miniOS: RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Updated by Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $0300      RAM: miniOS set-aside / Page 2
;      . $0300 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8010 - $8fff      IO Blk: 4k
;      . $8010 - $801f      ACIA:
;      . $8020 - $802f      VIA:
;    $9000 - $ffff      ROM: 28K
;--------

.segment "SYSRAM"
ISR_FIRST_RUN:  .res 1          ; used to determine first run of the ISRD


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
    stz minios_status

    lda #1
    sta CLK_SPD                                 ; Assume a 1Mhz clock to start

    lda #<ISR_RAMWRITE
    sta ISR_VECTOR
    lda #>ISR_RAMWRITE
    sta ISR_VECTOR + 1

    ; Init the 6551
    jsr ACIA_init
    jsr TTY_setup_term
    TTY_writeln welcome_msg

    jsr LCD_clear_video_ram

    ; This also inits the VIA chip
    jsr LCD_initialize

    ; Are we serial enabled?
    lda #(MINIOS_ACIA_ENABLED)
    bit minios_status
    beq @no_acia
    LCD_writeln message1
    bra @delay
@no_acia:
    LCD_writeln message                         ; render the boot screen

@delay:
    lda #25
    jsr LIB_delay100ms

    cli                                         ; interupts are back on
    jsr MENU_main                               ; start the menu routine
    jmp main                                    ; should the menu ever return ...


;================================================================================
;
;   MENU_main - renders a scrollable menu w/ dynamic number of entries
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

MENU_main:
    lda #0                                      ; since in RAM, positions need initialization
    sta POSITION_MENU
    sta POSITION_CURSOR

    jmp @start
@MAX_SCREEN_POS:                                ; define some constants in ROM
    .byte $06                                   ; its always number of items - 2, here its 7 windows ($00-$06) in 8 items
@start:                                         ; and off we go
    jsr LCD_clear_video_ram
    ldx POSITION_MENU
    ldy VRAM_OFFSETS,X
                                                ; load first offset into Y
    ldx #0                                      ; set X to 0
@loop:
    lda menu_items,Y                            ; load string char for Y
    sta VIDEO_RAM,X                             ; store in video ram at X
    iny
    inx
    cpx #(LCD_SIZE)                             ; fill LCD
    bne @loop

@render_cursor:                                 ; render cursor position based on current state
    lda #'>'
    ldy POSITION_CURSOR
    ldx VRAM_OFFSETS,Y
    sta VIDEO_RAM, X

@render:                                        ; and update the screen
    jsr LCD_render

@wait_for_input:                                ; handle keyboard input
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:
    cmp #$01
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$08
    beq @select_option                          ; RIGHT key pressed
    bne @wait_for_input                         ; and go around

@move_up:
    lda POSITION_CURSOR                         ; load cursor position
    beq @dec_menu_offset                        ; is cursor in up position? yes?
    dec A                                       ; no?
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
    inc A                                       ; no?
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
    beq @adj_clock
    cmp #6
    beq @about
    cmp #7
    beq @credits
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
    jsr BOOTLOADER_clear_ram
    jmp @start
@adj_clock:
    jsr BOOTLOADER_adj_clock
    jmp @start
@about:                                         ; start the about routine
    lda #<about
    ldy #>about
    ldx #1
    jsr LCD_print_text
    jmp @start
@credits:                                       ; start the credits routine
    lda #<credits
    ldy #>credits
    ldx #3
    jsr LCD_print_text
    jmp @start
@do_load:                                       ; orchestration of program loading
    lda #100                                    ; wait a bit, say 100ms
    jsr LIB_delay1ms
    jsr BOOTLOADER_program_ram                  ; call the bootloaders programming routine

    rts
@do_run:                                        ; orchestration of running a program
    jmp BOOTLOADER_execute

;================================================================================
;
;   BOOTLOADER_program_ram - writes serial data to RAM
;
;   Used in conjunction w/ the ISR, orchestrates user program reading
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;                    none
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

BOOTLOADER_program_ram:
    lda #%01111111                              ; we disable all 6522 interrupts!!!
    sta IER

    lda #0                                      ; for a reason I dont get, the ISR is triggered...
    sta ISR_FIRST_RUN                           ; one time before the first byte arrives, so we mitigate here

    jsr LCD_clear_video_ram
    LCD_writeln message4

    lda #$00                                    ; initializing loading state byte
    sta LOADING_STATE

    lda #>PROGRAM_START                         ; initializing RAM address counter
    sta CURRENT_RAM_ADDRESS_H
    lda #<PROGRAM_START
    sta CURRENT_RAM_ADDRESS_L

    cli                                         ; enable interrupt handling

    lda #%00000000                              ; set all pins on port B to input
    ldx #%11100001                              ; set top 3 pins and bottom ones to on port A to output, 4 middle ones to input
    jsr VIA_configure_ddrs

@wait_for_first_data:
    lda LOADING_STATE                           ; checking loading state
    cmp #$00                                    ; the ISR will set to $01 as soon as a byte is read
    beq @wait_for_first_data

@loading_data:
    lda #$02                                    ; assuming we're done loading, we set loading state to $02
    sta LOADING_STATE

    lda #120
    jsr LIB_delay1ms

    lda LOADING_STATE                           ; check back loading state, which was eventually updated by the ISR
    cmp #$02
    bne @loading_data
                                                ; when no data came in in last * cycles, we're done loading
@done_loading:
    lda #%11111111                              ; Reset VIA ports for output, set all pins on port B to output
    ldx #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr VIA_configure_ddrs

    jsr LCD_clear_video_ram
    LCD_writeln message6

    lda #25
    jsr LIB_delay100ms
    rts

;================================================================================
;
;   BOOTLOADER_execute - executes a user program in RAM
;
;   Program needs to be loaded via serial loader or other mechanism beforehand
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

BOOTLOADER_execute:
    sei                                         ; disable interrupt handling
    jsr LCD_clear_video_ram                     ; print a message
    LCD_writeln message7
    jmp PROGRAM_START                           ; and jump to program location

;================================================================================
;
;   BOOTLOADER_clear_ram - clears RAM from PROGRAM_START up to PROGRAM_END
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

BOOTLOADER_clear_ram:
    jsr LCD_clear_video_ram                     ; render message
    LCD_writeln message8

    ldy #<PROGRAM_START                         ; load start location into zero page
    sty Z0
    lda #>PROGRAM_START
    sta Z1
    lda #$00                                    ;  load 0x00 cleaner byte
    ldy #0
@loop:
    sta (Z0),Y                                  ; store it in current location
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
    cmp #$01
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$04
    beq @exit_hexdump                           ; LEFT key pressed
    cmp #$08
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
    lda (Z0),Y
    pha
    dey
    bne @iterate_ram
    lda (Z0),Y
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
    adc MON_position_map,Y                      ; use the static map for that
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
    sta VIDEO_RAM+LCD_COLS,X
    jmp @end_store
@store_upper_line:                              ; upper line storage
    pla
    sta VIDEO_RAM,X
@end_store:
    rts
@end_mon:
    lda #':'                                    ; writing the two colons
    sta VIDEO_RAM+4
    sta VIDEO_RAM+4+LCD_COLS
    rts

;================================================================================
;
;   BOOTLOADER_adj_clock - Changes the internal setting for the clock speed (CLK_SPD).
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

BOOTLOADER_adj_clock:
    pha                                         ; Save .A, .X, .Y
    phx
    phy
    lda CLK_SPD
    sta Z2
@redisplay:
    jsr LCD_clear_video_ram
    ldx #0
@fill_vram:
    lda clock_spd,X
    sta VIDEO_RAM,X
    inx
    cpx #14
    bne @fill_vram

; Now convert the value of Z2 (from 1 to 16) to ASCII
    lda Z2
    cmp #10                                     ; 1 or 2 digits?
    bcc @ones_place
    lda #'1'
    ldx #8
    sta VIDEO_RAM,X
@ones_place:
    lda #'0'
    adc Z2
    ldx #9
    sta VIDEO_RAM,X
    jsr LCD_render

@wait_for_input:                                ; wait for key press
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:                         ; determine action for key pressed
    cmp #$01
    beq @increase_spd                           ; UP key pressed
    cmp #$02
    beq @decrease_spd                           ; DOWN key pressed
    cmp #$04
    beq @exit_adj                               ; LEFT key pressed
    cmp #$08
    beq @save_spd                               ; RIGHT key pressed
    bne @wait_for_input
@increase_spd:
    lda Z2
    cmp #16
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

;----------------------------------------------------

.segment "RODATA"

message:
    .byte "      JJ65c02       "
    .byte "   miniOS v0.8      ", $00
message1:
    .byte "      JJ65c02       "
    .byte "  miniOS v0.8 ACIA  ", $00
message2:
    .asciiz "Enter Command..."
message3:
    .asciiz "Programming RAM"
message4:
    .asciiz "Awaiting data..."
message6:
    .asciiz "Loading done!"
message7:
    .asciiz "Running $0x0300"
message8:
    .asciiz "Cleaning RAM    Patience please!"
MON_position_map:
    .byte $00, $01, $03, $05, $07, $09
menu_items:
    .byte " Load & Run         "
    .byte " Load               "
    .byte " Run                "
    .byte " Hexdump            "
    .byte " Clear RAM          "
    .byte " Adjust Clk Speed   "
    .byte " About              "
    .byte " Credits            "
about:
    .asciiz "github.com/            jimjag/JJ65c02   "
credits:
    .byte "Jan Roesner            Orig sixty/5o2   "
    .byte "Ben Eater              6502 Project     "
    .byte "Steven Wozniak         bin2hex routine  ",$00
clock_spd:
    .byte " Clock:  % Mhz"
message9:
    .asciiz "Clk Spd Saved"

;================================================================================
;
;   ISR_RAMWRITE - Interrupt Service Routine
;
;   This might be the most naive approach to serial RAM writing ever, but it is
;   enormously stable and effective.
;
;   Whenever the Arduino set up a data bit on the 8 data lines of VIA PortB, it
;   pulls the 6502's interrupt line low for 3 microseconds. This triggers an
;   interrupt, and causes the 6502 to lookup the ISR entry vector in memory
;   location $fffe and $ffff. This is, where this routines address is put, so
;   each time an interrupt is triggered, this routine is called.
;
;   The routine reads the current byte from VIA PortB, writes it to the RAM and
;   increases the RAM address by $01.
;
;   In addition it REsets the LOADING_STATE byte, so the BOOTLOADER_program_ram
;   routine knows, there is still data flowing in. Since there is no "Control Byte"
;   that can be used to determine EOF, it is ust assumed, that EOF is reached, when
;   no data came in for a defined number of cycles.
;
;   Important: Due to the current hardware design (interrupt line) there is no
;              way to have the ISR service different interrupt calls.
;
;   Important: The routine is put as close to the end of the ROM as possible to
;              not fragment the ROM for additional routines. In case of additional
;              operations, the entry address needs recalculation!
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

.segment "ISR"                              ; as close as possible to the ROM's end

ISR_RAMWRITE:
    pha
    phy
                                                ; for a reason I dont get, the ISR is called once with 0x00
    lda ISR_FIRST_RUN                           ; check whether we are called for the first time
    bne @write_data                             ; if not, just continue writing

    lda #1                                      ; otherwise set the first time marker
    sta ISR_FIRST_RUN                           ; and return from the interrupt

    jmp @doneisr

@write_data:
    lda #$01                                    ; progressing state of loading operation
    sta LOADING_STATE                           ; so program_ram routine knows, data's still flowing

    lda PORTB                                   ; load serial data byte
    ldy #0
    sta (CURRENT_RAM_ADDRESS),Y                 ; store byte at current RAM location

                                                ; increase the 16bit RAM location
    inc CURRENT_RAM_ADDRESS_L
    bne @doneisr
    inc CURRENT_RAM_ADDRESS_H
@doneisr:
    ply                                         ; restore Y
    pla                                         ; restore A
    rti

ISR:
    jmp (ISR_VECTOR)

.segment "VECTORS"

    .word $0000
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine
