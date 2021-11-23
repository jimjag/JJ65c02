.include "minios.inc"
.include "sysram.inc"
.include "via.inc"
.include "acia.inc"
.include "tty.inc"
.include "lcd.h"

.export LCD_clear_video_ram
.export LCD_write_string
.export LCD_write_string_with_offset
.export LCD_write_text
.export LCD_initialize
.export LCD_clear_screen
.export LCD_set_cursor
.export LCD_render
.export LCD_wait_busy
.export LCD_send_instruction
.export LCD_send_data

E_bit =  %10000000
RW_bit = %01000000
RS_bit = %00100000

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
    sta VIDEO_RAM,y                             ; clean video ram
    dey                                         ; decrease index
    bne @loop                                   ; are we done? no, repeat
    sta VIDEO_RAM                               ; yes, write zero'th location manually
    ply                                         ; restore Y
    pla                                         ; restore A
    rts

;================================================================================
;
;   LCD_write_string - prints a string to the LCD (highlevel)
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: LCD_SPTR, LCD_SPTR+1: Pointer to null terminated string
;
;   Returned Values: none
;
;   Destroys:        .X
;   ————————————————————————————————————
;
;================================================================================

LCD_write_string:
    ldx #0                                      ; set offset to 0 as default
    jmp LCD_write_string_with_offset            ; call printing subroutine
    ;rts

;================================================================================
;
;   LCD_write_string_with_offset - prints string on LCD screen at given offset in Vram
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .X: Offset Byte
;                    LCD_SPTR LCD_SPTR+1: Pointer to null terminated string
;
;   Returned Values: none
;
;   Destroys:        .X
;   ————————————————————————————————————
;
;================================================================================

LCD_write_string_with_offset:
    pha
    phy
    ldy #0
@loop:
    cpx #(LCD_SIZE)
    beq @return
    lda (LCD_SPTR),y                            ; load char from given string at position Y
    beq @return                                 ; is string terminated via 0x00? yes
    sta VIDEO_RAM,x                             ; no - store char to video ram
    iny
    inx
    bne @loop                                   ; loop until we find 0x00
@return:
    jsr LCD_render                              ; render video ram contents to LCD screen aka scanline
    ply
    pla
    rts

;================================================================================
;
;   LCD_write_text - prints a scrollable / escapeable multiline text (highlevel)
;
;   The text location must be given as memory pointer
;
;   Important: The text MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: TEXT_BLK, TEXT_BLK+1: Pointer to sptr array
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y, Z2, Z3, Z6, Z7
;   ————————————————————————————————————
;
;================================================================================
CURRENT_PTR = Z2
VRAM_IDX = Z3
LCD_START_IDX = Z6
LCD_UPPER_IDX = Z7

LCD_write_text:
    stz LCD_START_IDX                           ; Orig starting index into string ptr "array"
    lda #$ff
    sta LCD_UPPER_IDX
@redo:
    stz VRAM_IDX                                ; row# for Vram
    lda LCD_START_IDX
    sta CURRENT_PTR
    jsr LCD_clear_video_ram                     ; clear video ram
@setup_ptrs:                                    ; Called for each string/line
    lda CURRENT_PTR
    asl a
    tay
    lda (TEXT_BLK),y                            ; get actual string address and tuck in LCD_SPTR
    sta LCD_SPTR
    iny
    lda (TEXT_BLK),y
    sta LCD_SPTR+1
    lda LCD_SPTR                                ; check for $0000
    bne @setup_indexes
    lda LCD_SPTR+1
    bne @setup_indexes
    lda CURRENT_PTR                             ; if we hit $0000, then we know now the index to the last element
    dec a
    sta LCD_UPPER_IDX
    bra @do_render                              ; If $0000, then we hit the end of the block. Render what we have
@setup_indexes:
    ldy VRAM_IDX
    ldx VRAM_OFFSETS,y
    ldy #0
@copy_chars:
    lda (LCD_SPTR),y                            ; load character from given text at current character index
    beq @next_line                              ; text ended? yes then next line
    sta VIDEO_RAM,x                             ; no, store char in video ram at current character index
    iny                                         ; increase index
    inx
    cpx #(LCD_SIZE)
    bne @copy_chars                             ; repeat with next char
@next_line:
    inc CURRENT_PTR
    inc VRAM_IDX
    lda VRAM_IDX
    cmp #(LCD_ROWS)
    bne @setup_ptrs
@do_render:
    jsr LCD_render                              ; render current content to screen

@wait_for_input:                                ; handle keyboard input
    jsr VIA_read_mini_keyboard

@handle_keyboard_input:
    cmp #(VIA_up_key)
    beq @scroll_down
    cmp #(VIA_down_key)
    beq @scroll_up
    cmp #(VIA_left_key)
    beq @exit
    bne @wait_for_input
@exit:
    rts

@scroll_down:
    lda LCD_START_IDX                           ; are we on the first page?
    beq @wait_for_input                         ; yes, just ignore the keypress and wait for next one
    dec LCD_START_IDX
    jmp @redo

@scroll_up:
    lda LCD_START_IDX
    cmp LCD_UPPER_IDX
    beq @wait_for_input                         ; at the bottom, just ignore the keypress and wait for next one
    inc LCD_START_IDX
    jmp @redo

;================================================================================
;
;   LCD_initialize - initializes the LCD display
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD_initialize:
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
;   LCD_set_cursor - positions the cursor on hardware level
;
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
    adc DDRAM,y
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
;   Destroys:        Z4
;   ————————————————————————————————————
;
;================================================================================

LCD_render:
    pha
    phy
    phx
    ldx #0
    ldy #0
    jsr LCD_set_cursor
    stz Z4
@write_char:                                    ; start writing chars from video ram
    lda VIDEO_RAM,x                             ; read video ram char at X
    cpx #(LCD_SIZE)
    beq @return
    cpy #(LCD_COLS)
    beq @next_line
    jsr LCD_send_data
    inx
    iny
    bne @write_char
@next_line:
    inc Z4
    ldy Z4
    phx
    ldx #0
    jsr LCD_set_cursor
    plx
    jsr LCD_send_data
    ldy #1
    inx
    bne @write_char
@return:
    plx
    ply
    pla
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
    sta VIA1DDRB
@not_ready:
    lda #(RW_bit)                               ; prepare read mode
    sta VIA1PORTA
    lda #(RW_bit | E_bit)                       ; prepare execution
    sta VIA1PORTA

    lda #%10000000                              ; for the bit test
    bit VIA1PORTB                               ; read data from LCD
    bne @not_ready                              ; bit 7 set, LCD is still busy, need waiting

    lda #(RW_bit)
    sta VIA1PORTA
    lda #%11111111
    sta VIA1DDRB
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

    sta VIA1PORTB                               ; write accumulator content into PORTB
    lda #0
    sta VIA1PORTA                               ; clear RS/RW/E bits
    lda #(E_bit)
    sta VIA1PORTA                               ; set E bit to send instruction
    lda #0
    sta VIA1PORTA                               ; clear RS/RW/E bits
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

    sta VIA1PORTB                               ; write accumulator content into PORTB
    lda #(RS_bit)
    sta VIA1PORTA                               ; clear RW/E bits
    lda #(RS_bit | E_bit)
    sta VIA1PORTA                               ; set E bit AND register select bit to send instruction
    lda #(RS_bit)
    sta VIA1PORTA                               ; clear E bit
    rts

