#ifndef __6502_LCD__
#define __6502_LCD__

#include <stdint.h>
#include <stdbool.h>

/* HD44780U (LCD-II) */

#define CMD_CLEAR             0b00000001

#define CMD_HOME              0b00000010

#define CMD_ENTRY_MODE        0b00000100
#define MASK_ENTRY_MODE       0b11111000
#define BIT_EM_INCREMENT      0b00000010
#define BIT_EM_SHIFT          0b00000001

#define CMD_DISPLAY_SET       0b00001000
#define MASK_DISPLAY_SET      0b11110000
#define BIT_DS_DISPLAY_ON     0b00000100
#define BIT_DS_CURSOR_ON      0b00000010
#define BIT_DS_CURSOR_BLINK   0b00000001

#define CMD_SHIFT_SET         0b00010000
#define MASK_SHIFT_SET        0b11100000
#define BIT_SS_SC             0b00001000
#define BIT_SS_RL             0b00000100

#define CMD_FUNCTION_SET      0b00100000
#define MASK_FUNCTION_SET     0b11000000
#define BIT_FS_8_BIT          0b00010000
#define BIT_FS_TWO_LINE       0b00001000
#define BIT_FS_FONT5x10       0b00000100

#define CMD_SET_CGRAM         0b01000000
#define CMD_SET_DDRAM         0b10000000

#define LCD_MEM_SIZE          80

#define LCD_ROWS              2
#define LCD_COLS              16

typedef struct {
  bool initialized;
  uint8_t function_mode;
  uint8_t entry_mode;
  uint8_t display_mode;
  uint8_t shift_mode;
  // data bus latch
  uint8_t data;
  uint8_t data_msb;
  uint8_t data_lsb;
  bool lower_bits;
  // data
  uint8_t ddram[LCD_MEM_SIZE];
  // cursor position
  uint8_t cursor;
} lcd;

lcd* new_lcd();

void destroy_lcd(lcd* l);

void process_input(lcd *l, bool enable, bool rwb, bool data, uint8_t input);

#endif
