#include "io.h"
#include "lcd.h"

#include <ncurses.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <sys/time.h>

#include "functions.h"
#include "opcodes.h"

void init_io() {
}

void finish_io() {
}

void handle_io(cpu *m) {
  int read;
  if ((read = getch()) != ERR) {
    switch(read) {
      case KEY_F(5): // F5
      case KEY_F(6): // F6
      case KEY_F(7): // F7
      case KEY_F(8): // F8
      case 27:
      case KEY_DOWN:
      case KEY_UP:
      case KEY_LEFT:
      case KEY_RIGHT:
        ungetch(read);
        break;
      default:
        m->interrupt_waiting = 0x01;
        m->mem[IO_GETCHAR] = read;
    }
  }
  if (get_emu_flag(m, EMU_FLAG_DIRTY)) {
    uint16_t addr = m->dirty_mem_addr;
    if (addr == IO_PUTCHAR) {
      if (m->mem[addr] != '\r') {
        wprintw(m->terminal, "%c", m->mem[addr]);
      }
    }
  }
}
