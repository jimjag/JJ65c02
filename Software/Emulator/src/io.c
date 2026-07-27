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
#include "picolink.h"

// Set via -p PATH in main.c; NULL disables the Pico sim link.
const char *picolink_path = NULL;

// Set via -o PATH in main.c; NULL disables the console tee.
const char *conlog_path = NULL;
static FILE *conlog = NULL;

void init_io() {
    picolink_init(picolink_path);
    if (conlog_path != NULL) {
        conlog = fopen(conlog_path, "w");
    }
}

void finish_io() {
    picolink_close();
    if (conlog != NULL) {
        fclose(conlog);
        conlog = NULL;
    }
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

  // PS/2 key bytes coming back from the Pico sim arrive on VIA1 Port A, exactly
  // like physical keyboard bytes. Only inject when no IRQ is pending so we never
  // clobber a byte the 6502 hasn't serviced yet; this paces input to the rate
  // the ISR consumes it.
  if (picolink_active() && !m->interrupt_waiting) {
    uint8_t kb;
    if (picolink_poll_byte(&kb)) {
      m->mem[IO_GETCHAR] = kb;
      m->interrupt_waiting = 0x01;
    }
  }

  if (get_emu_flag(m, EMU_FLAG_DIRTY)) {
    uint16_t addr = m->dirty_mem_addr;
    if (addr == IO_PUTCHAR) {
      // Tee the byte before anything else so the log is the same whether or not
      // a Pico sim is attached, and is flushed in case the run is SIGKILLed.
      if (conlog != NULL) {
        fputc(m->mem[addr], conlog);
        fflush(conlog);
      }
      // Forward every byte the 6502 writes to $A800 to the Pico sim, which
      // renders it via the real firmware. When no sim is attached, fall back to
      // the local ncurses terminal so the emulator remains usable standalone.
      if (picolink_active()) {
        picolink_send_byte(m->mem[addr]);
      } else if (m->mem[addr] != '\r') {
        wprintw(m->terminal, "%c", m->mem[addr]);
      }
    }
  }
}
