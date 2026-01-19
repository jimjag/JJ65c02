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
    m->interrupt_waiting = 0x01;
    m->mem[IO_GETCHAR] = read;
  }
  if (get_emu_flag(m, EMU_FLAG_DIRTY)) {
    uint16_t addr = m->dirty_mem_addr;
    if (addr == IO_PUTCHAR) {
      waddch(m->terminal, m->mem[addr]);
    }
  }
}
