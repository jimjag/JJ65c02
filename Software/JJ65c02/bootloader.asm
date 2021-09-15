;================================================================================
;
;                                    "JJ65c02"
;                                    _________
;
;                                      v0.6
;
;   RAM bootloader and viewer (r/o) w/ serial connection support
;
;   Updated by Jim Jagielski for the JJ65c02 Hobby Breadboard Project
;      ==> https://github.com/jimjag/JJ65c02
;   
;   Credits:
;               - Jan Roesner <jan@roesner.it>     Original Sixty/5o2 project
;               - Ben Eater                        (Project 6502)
;               - Steven Wozniak                   (bin2hex routine)
;
;================================================================================

;--------
; Assumed memory map (based on the JJ65c02):
;    $0000 - $7fff      RAM: 32k
;      . $0000 - $00ff      RAM: Zero Page / we use $00-$03
;      . $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
;      . $0200 - $022f      RAM: Bootloader set-aside / Page 2
;      . $0230 - $7fff      RAM: Runnable code area (also see PROGRAM_START/PROGRAM_END)
;    $8000 - $8fff      VIA 2: 4K (not currently used)
;    $9000 - $9fff      VIA 1: 4K
;    $a000 - $ffff      ROM: 24K
;--------

;
; Assemble with: vasm6502_oldstyle -wdc02 -dotdir -Fbin
;

PORTB = $9000                                   ; VIA port B
PORTA = $9001                                   ; VIA port A
DDRB = $9002                                    ; Data Direction Register B
DDRA = $9003                                    ; Data Direction Register A
IER = $900e                                     ; VIA Interrupt Enable Register

E =  %10000000
RW = %01000000
RS = %00100000

DEBOUNCE = 15                                   ; 150ms seems about right

Z0 = $00                                        ; General purpose ZP memory locations
Z1 = $01
Z2 = $02
Z3 = $03

VIDEO_RAM = $0210                               ; $0210 - $022f - Video RAM for 32 char LCD display
POSITION_MENU = $0204                           ; initialize positions for menu and cursor in RAM
POSITION_CURSOR = $0205
CLK_SPD = $0200                                 ; Clock speed, in MHz
DELAY1 = $0201                                  ; Loop counter for LIB__delay10ms
DELAY2 = $0202                                  ; same
ISR_FIRST_RUN = $0203                           ; used to determine first run of the ISRD
ISR_VECTOR = $0206                              ; Store true ISR vector ($0206, $0207)

PROGRAM_START = $0230                           ; memory location for user programs
PROGRAM_END = $8000                             ; End of RAM

    ; Start of ROM / Not really, but we use a 32k ROM chip, so we need to write all of it
    .org $8000                                  ; be sure to fill all 32k of ROM
    nop

    ; Actual start of ROM code
    .org $a000


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
    ldx #$ff                                    ; initialize the stackpointer with 0xff
    txs

    lda #1
    sta CLK_SPD                                 ; Assume a 1Mhz clock to start

    lda #<ISR_RAMWRITE
    sta ISR_VECTOR
    lda #>ISR_RAMWRITE
    sta ISR_VECTOR + 1

    jsr LCD__clear_video_ram
    jsr LCD__initialize

    lda #<message                               ; render the boot screen
    ldy #>message
    jsr LCD__print

    lda #255
    jsr LIB__delay10ms

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

    jmp .start
.MAX_SCREEN_POS:                                ; define some constants in ROM     
    .byte $06                                   ; its always number of items - 2, here its 7 windows ($00-$06) in 8 items
.OFFSETS:
    .byte $00, $10, $20, $30, $40, $50, $60     ; content offsets for all 6 screen windows
.start:                                         ; and off we go
    jsr LCD__clear_video_ram
    ldx POSITION_MENU
    ldy .OFFSETS,X
                                                ; load first offset into Y
    ldx #0                                      ; set X to 0
.loop:
    lda menu_items,Y                            ; load string char for Y
    sta VIDEO_RAM,X                             ; store in video ram at X
    iny
    inx
    cpx #$20                                    ; repeat 32 times
    bne .loop

.render_cursor:                                 ; render cursor position based on current state
    lda #">"
    ldy POSITION_CURSOR
    bne .lower_cursor
    sta VIDEO_RAM
    jmp .render

.lower_cursor:
    sta VIDEO_RAM+$10

.render:                                        ; and update the screen
    jsr LCD__render

.wait_for_input:                                ; handle keyboard input
    jsr VIA__read_keyboard_input
      
.handle_keyboard_input:
    cmp #$01    
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$08
    beq .select_option                          ; RIGHT key pressed
    bne .wait_for_input                         ; and go around

.move_up:
    lda POSITION_CURSOR                         ; load cursor position
    beq .dec_menu_offset                        ; is cursor in up position? yes?
    lda #0                                      ; no? 
    sta POSITION_CURSOR                         ; set cursor in up position
    jmp .start                                  ; re-render the whole menu
.dec_menu_offset:
    lda POSITION_MENU
    beq .wait_for_input                         ; yes, just re-render
.decrease:
    dec POSITION_MENU                           ; decrease menu position by one
    jmp .start                                  ; and re-render

.move_down:
    lda POSITION_CURSOR                         ; load cursor position
    cmp #1                                      ; is cursor in lower position?
    beq .inc_menu_offset                        ; yes?
    lda #1                                      ; no?
    sta POSITION_CURSOR                         ; set cursor in lower position
    jmp .start                                  ; and re-render the whole menu
.inc_menu_offset:
    lda POSITION_MENU                           ; load current menu positions
    cmp .MAX_SCREEN_POS                         ; are we at the bottom yet?
    bne .increase                               ; no?
    jmp .wait_for_input                         ; yes
.increase:
    adc #1                                      ; increase menu position
    sta POSITION_MENU
    jmp .start                                  ; and re-render

.select_option:
    clc
    lda #0                                      ; clear A
    adc POSITION_MENU
    adc POSITION_CURSOR                         ; calculate index of selected option
    cmp #0                                      ; branch trough all options
    beq .load_and_run
    cmp #1
    beq .load
    cmp #2
    beq .run
    cmp #3
    beq .monitor
    cmp #4
    beq .clear_ram
    cmp #5
    beq .adj_clock
    cmp #6
    beq .about
    cmp #7
    beq .credits
    jmp .start                                  ; should we have an invalid option, restart

.load_and_run:                                  ; load and directly run
    jsr .do_load                                ; load first
    jsr .do_run                                 ; run immediately after
    jmp .start                                  ; should a program ever return ...
.load:                                          ; load program and go back into menu
    jsr .do_load
    jmp .start
.run:                                           ; run a program already loaded
    jsr .do_run
    jmp .start
.monitor:                                       ; start up the monitor
    lda #<PROGRAM_START                         ; have it render the start location
    ldy #>PROGRAM_START                         ; can also be set as params during debugging
    jsr MONITOR__main
    jmp .start
.clear_ram:                                     ; start the clear ram routine
    jsr BOOTLOADER__clear_ram
    jmp .start
.adj_clock:
    jsr BOOTLOADER__adj_clock
    jmp .start
.about:                                         ; start the about routine
    lda #<about
    ldy #>about
    ldx #1
    jsr LCD__print_text
    jmp .start
.credits:                                       ; start the credits routine
    lda #<credits
    ldy #>credits
    ldx #3
    jsr LCD__print_text
    jmp .start
.do_load:                                       ; orchestration of program loading
    lda #10                                     ; wait a bit, say 100ms
    jsr LIB__delay10ms
    jsr BOOTLOADER__program_ram                 ; call the bootloaders programming routine

    rts
.do_run:                                        ; orchestration of running a program
    jmp BOOTLOADER__execute
                                  ; should we ever reach this point ...


;================================================================================
;
;   BOOTLOADER__program_ram - writes serial data to RAM
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

BOOTLOADER__program_ram:
CURRENT_RAM_ADDRESS_L = Z0
CURRENT_RAM_ADDRESS_H = Z1
LOADING_STATE = Z2
    lda #%01111111                              ; we disable all 6522 interrupts!!!
    sta IER

    lda #0                                      ; for a reason I dont get, the ISR is triggered...
    sta ISR_FIRST_RUN                           ; one time before the first byte arrives, so we mitigate here

    jsr LCD__clear_video_ram
    lda #<message4                              ; Rendering a message
    ldy #>message4
    jsr LCD__print

    lda #$00                                    ; initializing loading state byte
    sta LOADING_STATE

    lda #>PROGRAM_START                         ; initializing RAM address counter
    sta CURRENT_RAM_ADDRESS_H
    lda #<PROGRAM_START
    sta CURRENT_RAM_ADDRESS_L

    cli                                         ; enable interrupt handling

    lda #%00000000                              ; set all pins on port B to input
    ldx #%11100001                              ; set top 3 pins and bottom ones to on port A to output, 4 middle ones to input
    jsr VIA__configure_ddrs

.wait_for_first_data:
    lda LOADING_STATE                           ; checking loading state
    cmp #$00                                    ; the ISR will set to $01 as soon as a byte is read
    beq .wait_for_first_data

.loading_data:
    lda #$02                                    ; assuming we're done loading, we set loading state to $02
    sta LOADING_STATE

    lda #120
    jsr LIB__delay10ms

    lda LOADING_STATE                           ; check back loading state, which was eventually updated by the ISR
    cmp #$02
    bne .loading_data
                                                ; when no data came in in last * cycles, we're done loading  
.done_loading:
    lda #%11111111                              ; Reset VIA ports for output, set all pins on port B to output
    ldx #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr VIA__configure_ddrs

    jsr LCD__clear_video_ram
    lda #<message6
    ldy #>message6
    jsr LCD__print

    lda #250
    jsr LIB__delay10ms

    rts


;================================================================================
;
;   BOOTLOADER__execute - executes a user program in RAM
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

BOOTLOADER__execute:
    sei                                         ; disable interrupt handling
    jsr LCD__clear_video_ram                    ; print a message
    lda #<message7
    ldy #>message7
    jsr LCD__print
    jmp PROGRAM_START                           ; and jump to program location

;================================================================================
;
;   BOOTLOADER__clear_ram - clears RAM from PROGRAM_START up to PROGRAM_END
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

BOOTLOADER__clear_ram:
    jsr LCD__clear_video_ram                    ; render message 
    lda #<message8
    ldy #>message8
    jsr LCD__print

    ldy #<PROGRAM_START                         ; load start location into zero page
    sty Z0
    lda #>PROGRAM_START
    sta Z1
    lda #$00                                    ;  load 0x00 cleaner byte
    ldy #0
.loop:
    sta (Z0),Y                                  ; store it in current location
    inc Z0
    bne .check_end                              ; rollover?
    inc Z1                                      ; Yes, so increment upper address byte
.check_end:
    ldx #<PROGRAM_END
    cpx Z0
    bne .loop
    ldx #>PROGRAM_END
    cpx Z1
    bne .loop
    rts

;================================================================================
;
;   MONITOR__main - RAM/ROM Hexmonitor (r/o)
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

MONITOR__main:
    sta Z0                                      ; store LSB
    sty Z1                                      ; store MSB

.render_current_ram_location:
    jsr LCD__clear_video_ram

    lda #$00                                    ; select upper row of video ram
    sta Z3                                      ; #TODO
    jsr .transform_contents                     ; load and transform ram and address bytes

    clc                                         ; add offset to address
    lda Z0
    adc #$04
    sta Z0
    bcc .skip
    inc Z1
.skip:    

    lda #$01                                    ; select lower row of video ram
    sta Z3
    jsr .transform_contents                     ; load and transform ram and address bytes there

    jsr LCD__render

.wait_for_input:                                ; wait for key press
    jsr VIA__read_keyboard_input
 
.handle_keyboard_input:                         ; determine action for key pressed
    cmp #$01    
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$04
    beq .exit_monitor                           ; LEFT key pressed
    cmp #$08
    beq .fast_forward                           ; RIGHT key pressed
    bne .wait_for_input
.exit_monitor:
    lda #0                                      ; needed for whatever reason
    rts

.move_down:
    jmp .render_current_ram_location            ; no math needed, the address is up to date already
.move_up:
    sec                                         ; decrease the 16bit RAM Pointer
    lda Z0
    sbc #$08
    sta Z0
    lda Z1
    sbc #$00
    sta Z1
    jmp .render_current_ram_location            ; and re-render
.fast_forward:                                  ; add $0800 to current RAM location
    sec
    lda Z0
    adc #$00
    sta Z0
    lda Z1
    adc #$04
    sta Z1
    jmp .render_current_ram_location            ; and re-render
.transform_contents:                            ; start reading address and ram contents into stack
    ldy #3
.iterate_ram:                                   ; transfer 4 ram bytes to stack
    lda (Z0),Y
    pha
    dey
    bne .iterate_ram
    lda (Z0),Y
    pha

    lda Z0                                      ; transfer the matching address bytes to stack too
    pha
    lda Z1 
    pha

    ldy #0
.iterate_stack:                                 ; transform stack contents from bin to hex
    cpy #6
    beq .end_mon
    sty Z2                                      ; preserve Y #TODO
    pla
    jsr LIB__bin_to_hex
    ldy Z2                                      ; restore Y
    pha                                         ; push least sign. nibble (LSN) onto stack
    phx                                         ; push most sign. nibble (MSN) too

    tya                                         ; calculate nibble positions in video ram
    adc MON__position_map,Y                     ; use the static map for that
    tax
    pla
    jsr .store_nibble                           ; store MSN to video ram
    inx
    pla
    jsr .store_nibble                           ; store LSN to video ram

    iny
    jmp .iterate_stack                          ; repeat for all 6 bytes on stack
.store_nibble:                                  ; subroutine to store nibbles in two lcd rows
    pha
    lda Z3
    beq .store_upper_line                       ; should we store in upper line? yes
    pla                                         ; no, store in lower line
    sta VIDEO_RAM+$10,X
    jmp .end_store
.store_upper_line:                              ; upper line storage
    pla
    sta VIDEO_RAM,X
.end_store:
    rts
.end_mon:
    lda #":"                                    ; writing the two colons
    sta VIDEO_RAM+$4
    sta VIDEO_RAM+$14

    rts


;================================================================================
;
;   VIA__read_keyboard_input - returns 4-key keyboard inputs
;
;   Input is read, normalized and returned to the caller. We wait until
;   they actually *enter* something
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A: (UP: $1, DOWN: $2, LEFT: $4, RIGHT: $8)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

VIA__read_keyboard_input:
.waiting:
    lda #DEBOUNCE                               ; debounce
    jsr LIB__delay10ms                          ; ~150ms

    lda PORTA                                   ; load current key status from VIA
    ror                                         ; normalize the input to $1, $2, $4 and $8
    and #$0f                                    ; ignore first 4 bits
    ;eor #$0f                                   ; deactivate / comment this line, if your keyboard
                                                ; is built with buttons tied normal low, when
                                                ; pushed turning high (in contrast to Ben's schematics)

    beq .waiting                         ; no
    rts


;================================================================================
;
;   VIA__configure_ddrs - configures data direction registers of the VIA chip
;
;   Expects one byte per register with bitwise setup input/output directions
;   ————————————————————————————————————
;   Preparatory Ops: .A: Byte for DDRB
;                    .X: Byte for DDRA
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

VIA__configure_ddrs:
    sta DDRB                                    ; configure data direction for port B from A reg.
    stx DDRA                                    ; configure data direction for port A from X reg.

    rts


;================================================================================
;
;   LCD__clear_video_ram - clears the Video Ram segment with 0x00 bytes
;
;   Useful before rendering new contents by writing to the video ram
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__clear_video_ram:
    pha                                         ; preserve A via stack
    phy                                         ; same for Y
    ldy #$1f                                    ; set index to 31
    lda #$20                                    ; set character to 'space'
.loop:
    sta VIDEO_RAM,Y                             ; clean video ram
    dey                                         ; decrease index
    bne .loop                                   ; are we done? no, repeat
    sta VIDEO_RAM                               ; yes, write zero'th location manually
    ply                                         ; restore Y
    pla                                         ; restore A

    rts

;================================================================================
;
;   LCD__print - prints a string to the LCD (highlevel)
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST NOT be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print:
    ldx #0                                      ; set offset to 0 as default
    jsr LCD__print_with_offset                  ; call printing subroutine

    rts


;================================================================================
;
;   LCD__print_with_offset - prints string on LCD screen at given offset
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST NOT be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;                    .X: Offset Byte
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print_with_offset:
STRING_ADDRESS_PTR = Z0
    sta STRING_ADDRESS_PTR                      ; load t_string lsb
    sty STRING_ADDRESS_PTR+1                    ; load t_string msb
    stx Z2                                      ; X can not directly be added to A, therefore we store it #TODO
    ldy #0
.loop:
    clc
    tya
    adc Z2                                      ; compute offset based on given offset and current cursor position
    tax
    lda (STRING_ADDRESS_PTR),Y                  ; load char from given string at position Y
    beq .return                                 ; is string terminated via 0x00? yes
    sta VIDEO_RAM,X                             ; no - store char to video ram
    iny
    jmp .loop                                   ; loop until we find 0x00
.return:
    jsr LCD__render                             ; render video ram contents to LCD screen aka scanline

    rts


;================================================================================
;
;   LCD__print_text - prints a scrollable / escapeable multiline text (highlevel)
;
;   The text location must be given as memory pointer, the number of pages to
;   be rendered needs to be given as well
;
;   Important: The text MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN Text Address
;                    .Y: MSN Text Address
;                    .X: Page Number Byte
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print_text:
    sta Z0                                      ; store text pointer in zero page
    sty Z1
    dex                                         ; reduce X by one to get cardinality of pages
    stx Z2                                      ; store given number of pages
.CURRENT_PAGE = Z3
    lda #0
    sta Z3
.render_page:
    jsr LCD__clear_video_ram                    ; clear video ram
    ldy #0                                      ; reset character index
.render_chars:
    lda (Z0),Y                                  ; load character from given text at current character index
    cmp #$00
    beq .do_render                              ; text ended? yes then render
    sta VIDEO_RAM,Y                             ; no, store char in video ram at current character index
    iny                                         ; increase index
    bne .render_chars                           ; repeat with next char
.do_render:
    jsr LCD__render                             ; render current content to screen

.wait_for_input:                                ; handle keyboard input
    jsr VIA__read_keyboard_input

.handle_keyboard_input:
    cmp #$01    
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$04
    beq .exit                                   ; LEFT key pressed
    bne .wait_for_input
.exit:

    rts
.move_up:
    lda .CURRENT_PAGE                           ; are we on the first page?
    beq .wait_for_input                         ; yes, just ignore the keypress and wait for next one

    dec .CURRENT_PAGE                           ; no, decrease current page by 1

    sec                                         ; decrease reading pointer by 32 bytes
    lda Z0
    sbc #$20
    sta Z0
    bcs .skipdec
    dec Z1
.skipdec:    
    jmp .render_page                            ; and re-render

.move_down:
    lda .CURRENT_PAGE                           ; load current page
    cmp Z2                                      ; are we on last page already
    beq .wait_for_input                         ; yes, just ignore keypress and wait for next one

    inc .CURRENT_PAGE                           ; no, increase current page by 1

    clc                                         ; add 32 to the text pointer
    lda Z0
    adc #$20
    sta Z0
    bcc .skipinc
    inc Z1
.skipinc:
    jmp .render_page                            ; and re-render

;================================================================================
;
;   LCD__initialize - initializes the LCD display
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X
;   ————————————————————————————————————
;
;================================================================================

LCD__initialize:
    lda #%11111111                              ; set all pins on port B to output
    ldx #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr VIA__configure_ddrs

    lda #%00111000                              ; set 8-bit mode, 2-line display, 5x8 font
    jsr LCD__send_instruction

    lda #%00001110                              ; display on, cursor on, blink off
    jsr LCD__send_instruction
    
    lda #%00000110                              ; increment and shift cursor, don't shift display
    jsr LCD__send_instruction

    jmp LCD__clear_screen                       ; reset and clear LCD

;================================================================================
;
;   LCD__clear_screen - clears the screen on hardware level (low level)
;
;   Not to confuse with LCD__clear_video_ram, which in contrast just deletes
;   the stored RAM values which shall be displayed
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__clear_screen:
    pha
    lda #%00000001                              ; clear display
    jsr LCD__send_instruction
    pla

    rts

;================================================================================
;
;   LCD__set_cursor - sets the cursor on hardware level into upper or lower row
;
;   Always positions the cursor in the first column of the chosen row
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing upper or lower row
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__set_cursor:
    jmp LCD__send_instruction

;================================================================================
;
;   LCD__set_cursor_second_line - sets cursor to second row, first column
;
;   Low level convenience function
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__set_cursor_second_line:
    pha                                         ; preserve A
    lda #%11000000                              ; set cursor to line 2 hardly
    jsr LCD__send_instruction
    pla                                         ; restore A

    rts

;================================================================================
;
;   LCD__render - transfers Video Ram contents onto the LCD display
;
;   Automatically breaks text into the second row if necessary but takes the
;   additional LCD memory into account
;   ————————————————————————————————————
;   Preparatory Ops: Content in Video Ram needs to be available
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__render:
    lda #%10000000                              ; force cursor to first line
    jsr LCD__set_cursor                         
    ldx #0
.write_char:                                    ; start writing chars from video ram
    lda VIDEO_RAM,X                             ; read video ram char at X
    cpx #$10                                    ; are we done with the first line?
    beq .next_line                              ; yes - move on to second line
    cpx #$20                                    ; are we done with 32 chars?
    beq .return                                 ; yes, return from routine
    jsr LCD__send_data                          ; no, send data to lcd
    inx
    jmp .write_char                             ; repeat with next char
.next_line:
    jsr LCD__set_cursor_second_line             ; set cursort into line 2
    jsr LCD__send_data                          ; send data to lcd
    inx
    jmp .write_char                             ; repear with next char
.return:

    rts


;================================================================================
;
;   LCD__wait_busy - Check if LCD is busy and, if so, loop until not
;
;   Since the LCD needs clock cycles internally to process instructions, it can
;   not handle instructions at all times. Therefore it provides a busy flag,
;   which when 0 signals, that the LCD is ready to accept the next instruction
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__wait_busy:
    pha                                         ; preserve A
    sei                                         ; hold off on interrupts

    lda #0
    sta DDRB
.not_ready:
    lda #RW                                     ; prepare read mode
    sta PORTA
    lda #(RW | E)                               ; prepare execution
    sta PORTA

    lda #%10000000                              ; for the bit test
    bit PORTB                                   ; read data from LCD
    bne .not_ready                              ; bit 7 set, LCD is still busy, need waiting

    lda #RW
    sta PORTA
    lda #%11111111
    sta DDRB
    pla
    cli
    rts

;================================================================================
;
;   LCD__send_instruction - sends a control instruction to the LCD display
;
;   In contrast to data, the LCD accepts a number of control instructions as well
;   This routine can be used, to send arbitrary instructions following the LCD's
;   specification
;   ————————————————————————————————————
;   Preparatory Ops: .A: control byte (see LCD manual)
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__send_instruction:
    jsr LCD__wait_busy

    sta PORTB                                   ; write accumulator content into PORTB
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits
    lda #E
    sta PORTA                                   ; set E bit to send instruction
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits
    rts


;================================================================================
;
;   LCD__send_data - sends content data to the LCD controller
;
;   In contrast to instructions, there seems to be no constraint, and data can
;   be sent at any rate to the display (see LCD__send_instruction)
;   ————————————————————————————————————
;   Preparatory Ops: .A: Content Byte
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__send_data:
    jsr LCD__wait_busy

    sta PORTB                                   ; write accumulator content into PORTB
    lda #RS
    sta PORTA                                   ; clear RW/E bits
    lda #(RS | E)
    sta PORTA                                   ; set E bit AND register select bit to send instruction
    lda #RS
    sta PORTA                                   ; clear E bit
    rts

;================================================================================
;
;   LIB__bin_to_hex: CONVERT BINARY BYTE TO HEX ASCII CHARS - THX Woz!
;
;   Slighty modified version - original from Steven Wozniak for Apple I
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte to convert
;
;   Returned Values: .A: LSN ASCII char
;                    .X: MSN ASCII char
;   ————————————————————————————————————
;
;================================================================================

LIB__bin_to_hex:
    ldy #$ff                                    ; state for output switching #TODO
    pha                                         ; save A for LSD
    lsr
    lsr
    lsr                     
    lsr                                         ; MSD to LSD position
    jsr .to_hex                                 ; output hex digit, using internal recursion
    pla                                         ; restore A
.to_hex:
    and #%00001111                              ; mask LSD for hex print
    ora #"0"                                    ; add "0"
    cmp #"9"+1                                  ; is it a decimal digit?
    bcc .output                                 ; yes! output it
    adc #6                                      ; add offset for letter A-F
.output:
    iny                                         ; set switch for second nibble processing
    bne .return                                 ; did we process second nibble already? yes
    tax                                         ; no
.return:

    rts

;================================================================================
;
;   LIB__delay10ms - "sleeps" for about 10ms
;
;   The routine does not actually sleep, but delays by burning cycles in TWO(!)
;   nested loops. The user must configure the number 10ms delays in .A
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing the sleep duration
;
;   Returned Values: none
;
;   Destroys:       none
;   ————————————————————————————————————
;
;================================================================================

LIB__delay10ms:
    sta DELAY1                                  ; store away .A
    phx                                         ; save .X
    phy                                         ; and .Y
    lda CLK_SPD
    sta DELAY2
    lda DELAY1                                  ; Restore .A
.sleep_4:
    sta DELAY1                                  ; Reset for each clock speed related loop
.sleep_3:
    ldy #8                                      ; 8 externals of 255 internals is ~10ms
.sleep_2:
    ldx #$ff
.sleep_1:
    dex
    bne .sleep_1
    dey
    bne .sleep_2
    dec DELAY1                                  ; Number of 10ms delays
    bne .sleep_3
    dec DELAY2                                  ; Account for different clock speeds
    bne .sleep_4                                ; Faster clocks means more loops
    sta DELAY1                                  ; We are done. Save .A once more
    ply                                         ; Restore .Y
    plx                                         ; and .X
    lda DELAY1                                  ; and .A
    rts

;================================================================================
;
;   BOOTLOADER_adj_clock - Changes the internal setting for the clock speed (CLK_SPD).
;
;   This routine simply updates the internal setting for the clock speed of the
;   system, in Mhz. This only currently affects LIB__delay10ms so that depending
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

BOOTLOADER__adj_clock:
    pha                                         ; Save .A, .X, .Y
    phx
    phy
    lda CLK_SPD
    sta Z0
.redisplay:
    jsr LCD__clear_video_ram
    ldx #0
.fill_vram:
    lda clock_spd,X
    sta VIDEO_RAM,X
    inx
    cpx #14
    bne .fill_vram

; Now convert the value of Z0 (from 1 to 14) to ASCII
    lda Z0
    cmp #10                                      ; 1 or 2 digits?
    bcc .ones_place
    lda #"1"
    ldx #8
    sta VIDEO_RAM,X
.ones_place:
    lda #"0"
    adc Z0
    ldx #9
    sta VIDEO_RAM,X
    jsr LCD__render

.wait_for_input:                                ; wait for key press
    jsr VIA__read_keyboard_input

.handle_keyboard_input:                         ; determine action for key pressed
    cmp #$01
    beq .increase_spd                           ; UP key pressed
    cmp #$02
    beq .decrease_spd                           ; DOWN key pressed
    cmp #$04
    beq .exit_adj                               ; LEFT key pressed
    cmp #$08
    beq .save_spd                               ; RIGHT key pressed
    bne .wait_for_input
.increase_spd:
    lda Z0
    cmp #14
    beq .redisplay
    inc Z0
    bne .redisplay
.decrease_spd:
    lda Z0
    cmp #1
    beq .redisplay
    dec Z0
    bne .redisplay
.save_spd:
    lda Z0
    sta CLK_SPD
    jsr LCD__clear_video_ram
    lda #<message9                              ; saved feedback
    ldy #>message9
    jsr LCD__print
    lda #50
    jsr LIB__delay10ms                          ; let them see know it
    jmp .redisplay
.exit_adj:
    ply                                         ; Restore .Y, .X, .A
    plx
    pla
    rts

message:
    .asciiz "     JJ65c02    Bootloader v0.6 "
message2:
    .asciiz "Enter Command..."
message3:
    .asciiz "Programming RAM"
message4:
    .asciiz "Awaiting data..."
message6:
    .asciiz "Loading done!"
message7:
    .asciiz "Running $0x0230"
message8:
    .asciiz "Cleaning RAM    Patience please!"
MON__position_map:
    .byte $00, $01, $03, $05, $07, $09
menu_items:
    .text " Load & Run     "
    .text " Load           "
    .text " Run            "
    .text " Monitor        "
    .text " Clear RAM      "
    .text " Adjust Clk Spd "
    .text " About          "
    .text " Credits        "
about:
    .asciiz "github.com/      jimjag/JJ65c02 "
credits:
    .asciiz "Jan Roesner      Orig sixty/5o2 Ben Eater       6502 Project    Steven Wozniak  bin2hex routine "
clock_spd:
    .text " Clock:  % Mhz"
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
;   In addition it REsets the LOADING_STATE byte, so the BOOTLOADER__program_ram
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

    .org $FFC0                                  ; as close as possible to the ROM's end

ISR_RAMWRITE:
CURRENT_RAM_ADDRESS = Z0                        ; a RAM address handle for indirect writing

    pha
    phy
                                                ; for a reason I dont get, the ISR is called once with 0x00
    lda ISR_FIRST_RUN                           ; check whether we are called for the first time
    bne .write_data                             ; if not, just continue writing

    lda #1                                      ; otherwise set the first time marker
    sta ISR_FIRST_RUN                           ; and return from the interrupt

    jmp .doneisr

.write_data:
    lda #$01                                    ; progressing state of loading operation
    sta LOADING_STATE                           ; so program_ram routine knows, data's still flowing

    lda PORTB                                   ; load serial data byte
    ldy #0
    sta (CURRENT_RAM_ADDRESS),Y                 ; store byte at current RAM location

                                               ; increase the 16bit RAM location
    inc CURRENT_RAM_ADDRESS_L
    bne .doneisr
    inc CURRENT_RAM_ADDRESS_H
.doneisr:
    ply                                         ; restore Y
    pla                                         ; restore A

    rti

ISR:
    jmp (ISR_VECTOR)

    .org $fffc                                  
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine
