.include "minios.inc"
.include "via.inc"
.include "acia.inc"
.include "lcd.h"
.include "sysram.inc"

.export LCD_clear_video_ram
.export LCD_print
.export LCD_print_with_offset
.export LCD_print_text
.export LCD_initialize
.export LCD_clear_screen
.export LCD_set_cursor
.export LCD_render
.export LCD_wait_busy
.export LCD_send_instruction
.export LCD_send_data

.export VRAM_OFFSETS

.export POSITION_MENU
.export POSITION_CURSOR

E =  %10000000
RW = %01000000
RS = %00100000

.segment "SYSRAM"
    
POSITION_MENU:      .res 1              ; initialize positions for menu and cursor in RAM
POSITION_CURSOR:    .res 1

.segment "RODATA"

DDRAM:
    .byte $00
    .byte $40
    .byte LCD_COLS
    .byte $40+LCD_COLS
VRAM_OFFSETS:
    .byte 0, LCD_COLS, 2*LCD_COLS, 3*LCD_COLS, 4*LCD_COLS, 5*LCD_COLS
    .byte 6*LCD_COLS, 7*LCD_COLS, 8*LCD_COLS, 9*LCD_COLS, 10*LCD_COLS

; Actual start of ROM code
.segment "CODE"

;================================================================================
;
;   LCD_clear_video_ram - clears the Video Ram segment with 0x00 bytes
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

LCD_clear_video_ram:
    pha                                         ; preserve A via stack
    phy                                         ; same for Y
    ldy #(LCD_LASTIDX)                          ; set index to last byte
    lda #' '                                    ; set character to 'space'
@loop:
    sta VIDEO_RAM,Y                             ; clean video ram
    dey                                         ; decrease index
    bne @loop                                   ; are we done? no, repeat
    sta VIDEO_RAM                               ; yes, write zero'th location manually
    ply                                         ; restore Y
    pla                                         ; restore A
    rts

;================================================================================
;
;   LCD_print - prints a string to the LCD (highlevel)
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD_print:
    ldx #0                                      ; set offset to 0 as default
    jsr LCD_print_with_offset                   ; call printing subroutine
    rts

;================================================================================
;
;   LCD_print_with_offset - prints string on LCD screen at given offset in Vram
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;                    .X: Offset Byte
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y, Z0, Z1
;   ————————————————————————————————————
;
;================================================================================

LCD_print_with_offset:
STRING_ADDRESS_PTR = Z0
    sta STRING_ADDRESS_PTR                      ; load t_string lsb
    sty STRING_ADDRESS_PTR+1                    ; load t_string msb
    ldy #0
@loop:
    cpx #(LCD_SIZE)
    beq @return
    lda (STRING_ADDRESS_PTR),Y                  ; load char from given string at position Y
    beq @return                                 ; is string terminated via 0x00? yes
    sta VIDEO_RAM,X                             ; no - store char to video ram
    iny
    inx
    bne @loop                                   ; loop until we find 0x00
@return:
    jsr LCD_render                              ; render video ram contents to LCD screen aka scanline
    rts

;================================================================================
;
;   LCD_print_text - prints a scrollable / escapeable multiline text (highlevel)
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
;   Destroys:        .A, .X, .Y, Z0, Z1, Z2, Z3
;   ————————————————————————————————————
;
;================================================================================

LCD_print_text:
    sta Z0                                      ; store text pointer in zero page
    sty Z1
    dex                                         ; reduce X by one to get cardinality of pages
    stx Z2                                      ; store given number of pages
@CURRENT_PAGE = Z3
    lda #0
    sta Z3
@render_page:
    jsr LCD_clear_video_ram                     ; clear video ram
    ldy #0                                      ; reset character index
@render_chars:
    lda (Z0),Y                                  ; load character from given text at current character index
    cmp #$00
    beq @do_render                              ; text ended? yes then render
    sta VIDEO_RAM,Y                             ; no, store char in video ram at current character index
    iny                                         ; increase index
    bne @render_chars                           ; repeat with next char
@do_render:
    jsr LCD_render                              ; render current content to screen

@wait_for_input:                                ; handle keyboard input
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:
    cmp #$01
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$04
    beq @exit                                   ; LEFT key pressed
    bne @wait_for_input
@exit:
    rts

@move_up:
    lda @CURRENT_PAGE                           ; are we on the first page?
    beq @wait_for_input                         ; yes, just ignore the keypress and wait for next one

    dec @CURRENT_PAGE                           ; no, decrease current page by 1

    sec                                         ; decrease reading pointer by 40 bytes
    lda Z0
    sbc #40
    sta Z0
    bcs @skipdec
    dec Z1
@skipdec:
    jmp @render_page                            ; and re-render

@move_down:
    lda @CURRENT_PAGE                           ; load current page
    cmp Z2                                      ; are we on last page already
    beq @wait_for_input                         ; yes, just ignore keypress and wait for next one

    inc @CURRENT_PAGE                           ; no, increase current page by 1

    clc                                         ; add 40 to the text pointer
    lda Z0
    adc #40
    sta Z0
    bcc @skipinc
    inc Z1
@skipinc:
    jmp @render_page                            ; and re-render

;================================================================================
;
;   LCD_initialize - initializes the LCD display
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

LCD_initialize:
    lda #%11111111                              ; set all pins on port B to output
    ldx #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr VIA_configure_ddrs

    lda #%00111000                              ; set 8-bit mode, 2-line display, 5x8 font
    jsr LCD_send_instruction

    lda #%00001100                              ; display on, cursor off, blink off
    jsr LCD_send_instruction

    lda #%00000110                              ; increment and shift cursor, don't shift display
    jsr LCD_send_instruction

    jmp LCD_clear_screen                        ; reset and clear LCD

;================================================================================
;
;   LCD_clear_screen - clears the screen on hardware level (low level)
;
;   Not to confuse with LCD_clear_video_ram, which in contrast just deletes
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

LCD_clear_screen:
    pha
    lda #%00000001                              ; clear display
    jsr LCD_send_instruction
    pla
    rts

;================================================================================
;
;   LCD_set_cursor - sets the cursor on hardware level
;
;   Always positions the cursor in the first column of the chosen row
;   ————————————————————————————————————
;   Preparatory Ops: .Y: byte representing row number
;                    .X: col number
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD_set_cursor:
    pha                                         ; preserve A
    txa
    clc
    adc DDRAM,Y
    clc
    ora #$80
    jsr LCD_send_instruction
    pla                                         ; restore A
    rts


;================================================================================
;
;   LCD_render - transfers Video Ram contents onto the LCD display
;
;   Automatically breaks text into the second row if necessary but takes the
;   additional LCD memory into account
;   ————————————————————————————————————
;   Preparatory Ops: Content in Video Ram needs to be available
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y, Z3
;   ————————————————————————————————————
;
;================================================================================

LCD_render:
    ldx #0
    ldy #0
    jsr LCD_set_cursor
    stz Z3
@write_char:                                    ; start writing chars from video ram
    lda VIDEO_RAM,X                             ; read video ram char at X
    cpx #(LCD_SIZE)
    beq @return
    cpy #(LCD_COLS)
    beq @next_line
    jsr LCD_send_data
    inx
    iny
    bne @write_char
@next_line:
    inc Z3
    ldy Z3
    phx
    ldx #0
    jsr LCD_set_cursor
    plx
    jsr LCD_send_data
    ldy #1
    inx
    bne @write_char
@return:
    rts

;================================================================================
;
;   LCD_wait_busy - Check if LCD is busy and, if so, loop until not
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

LCD_wait_busy:
    pha                                         ; preserve A
    sei                                         ; hold off on interrupts

    lda #0
    sta DDRB
@not_ready:
    lda #(RW)                                     ; prepare read mode
    sta PORTA
    lda #(RW | E)                               ; prepare execution
    sta PORTA

    lda #%10000000                              ; for the bit test
    bit PORTB                                   ; read data from LCD
    bne @not_ready                              ; bit 7 set, LCD is still busy, need waiting

    lda #(RW)
    sta PORTA
    lda #%11111111
    sta DDRB
    pla
    cli
    rts

;================================================================================
;
;   LCD_send_instruction - sends a control instruction to the LCD display
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

LCD_send_instruction:
    jsr LCD_wait_busy

    sta PORTB                                   ; write accumulator content into PORTB
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits
    lda #(E)
    sta PORTA                                   ; set E bit to send instruction
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits
    rts

;================================================================================
;
;   LCD_send_data - sends content data to the LCD controller
;
;   In contrast to instructions, there seems to be no constraint, and data can
;   be sent at any rate to the display (see LCD_send_instruction)
;   ————————————————————————————————————
;   Preparatory Ops: .A: Content Byte
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD_send_data:
    jsr LCD_wait_busy

    sta PORTB                                   ; write accumulator content into PORTB
    lda #(RS)
    sta PORTA                                   ; clear RW/E bits
    lda #(RS | E)
    sta PORTA                                   ; set E bit AND register select bit to send instruction
    lda #(RS)
    sta PORTA                                   ; clear E bit
    rts

