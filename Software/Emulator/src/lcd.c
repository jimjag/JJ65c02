#include "lcd.h"
#include "gui.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

lcd * new_lcd() {
  lcd *l = malloc(sizeof(lcd));

  l->lower_bits = false;
  l->function_mode = BIT_FS_8_BIT;
  l->entry_mode = BIT_EM_INCREMENT;
  l->display_mode = 0;
  l->shift_mode = 0;
  l->data = 0xff;
  l->cursor = 0;
  memset(l->ddram, 0x00, LCD_MEM_SIZE);
  return l;
}

void destroy_lcd(lcd* l) {
  free(l);
}

void process_command(lcd* l, bool rwb, uint8_t input);
void process_data(lcd* l, bool rwb, uint8_t input);

void process_input(lcd* l, bool enable, bool rwb, bool data, uint8_t input)
{
  char message[32];
  // when in 4-bit mode
  if (!(l->function_mode & BIT_FS_8_BIT)) {
    // if these are most significant bits
    if (!l->lower_bits) {
      // store them in msb latch
      l->data_msb = input;
      // indicate we are waiting for lsb
      l->lower_bits = true;
      sprintf(message, "LCD received 4-bits, msb: %01x\n", (input & 0xf0));
    } else {
      // not waiting anymore
      l->lower_bits = false;
      // store them in lsb latch
      l->data_lsb = input;
      // move full byte to data latch
      l->data = (l->data_msb & 0xf0) | ((l->data_lsb & 0xf0) >> 4);
      sprintf(message, "LCD received 4-bits, lsb: %01x\n", (input & 0xf0));
    }
  } else {
    // simply move input to data latch
    sprintf(message, "LCD received 8-bits: %02x\n", input);
    l->data = input;
  }
  trace_emu(message);
  if (enable && ((l->function_mode & BIT_FS_8_BIT) || !l->lower_bits)) {
    // we are either in 4-bit mode and received both halves or in 8-bit mode
    if (!data) {
      process_command(l, rwb, l->data);
    } else {
      process_data(l, rwb, l->data);
    }
  }

}

void process_command(lcd* l, bool rwb, uint8_t input) {
  char message[32];
  if (!rwb) { // write operations
    if (input == CMD_CLEAR) {
      trace_emu("LCD clearing screen\n");
      memset(l->ddram, 0x00, LCD_MEM_SIZE);
      return;
    } else if (input == CMD_HOME) {
      trace_emu("LCD moving to home location\n");
      l->cursor=0;
      return;
    }

    if ((input & CMD_FUNCTION_SET) && !(input & MASK_FUNCTION_SET)) {
      l->function_mode = input;
      sprintf(message, "LCD function set to %02x\n", input);
      trace_emu(message);
      if (input & BIT_FS_8_BIT) {
        trace_emu("LCD set to 8-bit mode\n");
      } else {
        trace_emu("LCD set to 4-bit mode\n");
      }
      if (input & BIT_FS_TWO_LINE) {
        trace_emu("LCD set to 2-line mode\n");
      } else {
        trace_emu("LCD set to 1-line mode\n");
      }
      if (input & BIT_FS_FONT5x10) {
        trace_emu("LCD set to 5x10 font\n");
      } else {
        trace_emu("LCD set to 5x8 font\n");
      }
    } else if ((input & CMD_DISPLAY_SET) && !(input & MASK_DISPLAY_SET)) {
      l->display_mode = input;
      sprintf(message, "LCD display mode set to %02x\n", input);
      trace_emu(message);
      if (input & BIT_DS_DISPLAY_ON) {
        trace_emu("LCD set to display on\n");
      } else {
        trace_emu("LCD set to display off\n");
      }
      if (input & BIT_DS_CURSOR_ON) {
        trace_emu("LCD set to cursor on\n");
      } else {
        trace_emu("LCD set to cursor off\n");
      }
      if (input & BIT_DS_CURSOR_BLINK) {
        trace_emu("LCD set to blink on\n");
      } else {
        trace_emu("LCD set to blink off\n");
      }
    } else if ((input & CMD_ENTRY_MODE) && !(input & MASK_ENTRY_MODE)) {
      l->entry_mode = input;
      sprintf(message, "LCD entry mode set to %02x\n", input);
      trace_emu(message);
      if (input & BIT_EM_INCREMENT) {
        trace_emu("LCD set to increment+shift cursor\n");
      } else {
        trace_emu("LCD set to NOT increment+shift cursor\n");
      }
      if (input & BIT_EM_SHIFT) {
        trace_emu("LCD set to shift display\n");
      } else {
        trace_emu("LCD set to NOT shift display\n");
      }
    } else if ((input & CMD_SET_DDRAM)) {
      input &= CMD_MASK_DDRAM;
      sprintf(message, "LCD cursor set to %02x\n", input);
      trace_emu(message);
        l->cursor=input;
    }
  } else {
    l->data = l->cursor;
  }
}
void process_data(lcd* l, bool rwb, uint8_t input) {
  char message[32];
  if (!rwb) { // write operation
    sprintf(message, "LCD write %02x to location %02x\n", input, l->cursor);
    trace_emu(message);
    l->ddram[l->cursor++] = input;
    if (l->cursor >= LCD_MEM_SIZE) {
      l->cursor = 0;
    }
  }
}
