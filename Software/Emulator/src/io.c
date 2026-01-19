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

void handle_io(cpu *m, bool rwb) {
  if (!rwb) {
    int read;
    if ((read = getch()) != ERR) {
      m->interrupt_waiting = 0x01;
      m->mem[IO_GETCHAR] = read;
    }
    if (get_emu_flag(m, EMU_FLAG_DIRTY)) {
      uint16_t addr = m->dirty_mem_addr;
      if (addr == IO_PUTCHAR) {
        addch(m->mem[addr]);
      }
    }
  }
  if (!rwb) {
    // data potentially written to memory
    if (get_emu_flag(m, EMU_FLAG_DIRTY)) {
      uint16_t addr = m->dirty_mem_addr;

      if (addr & 0x8000) {  // in VIA1 address space?
        switch (addr & 0xff) {
        case 0x20:
          m->v1->portb &= (~m->v1->ddrb);
          m->v1->portb |= (m->mem[addr] & m->v1->ddrb);
          break;
        case 0x21:
          m->v1->porta &= (~m->v1->ddra);
          m->v1->porta |= (m->mem[addr] & m->v1->ddra);
          break;
        case 0x22:
          m->v1->ddrb = m->mem[addr];
          break;
        case 0x23:
          m->v1->ddra = m->mem[addr];
          break;
        case 0x2e:
          m->v1->ier = m->mem[addr];
          break;
        }

        if (m->lcd_8_bit) {
          process_input(m->l, m->v1->porta & 0x80, m->v1->porta & 0x40, m->v1->porta & 0x20, m->v1->portb);
        } else {
          process_input(m->l, m->v1->portb & 0x08, m->v1->portb & 0x04, m->v1->portb & 0x02, m->v1->portb & 0xf0);
        }
      }
    }
  } else {
    uint8_t old_porta_input = m->v1->porta & ~m->v1->ddra;

    m->v1->portb &= m->v1->ddrb;
    m->v1->portb |= (m->l->data & ~m->v1->ddrb);
    m->v1->porta &= m->v1->ddra;
    m->v1->porta |= m->k->key_enter ? 0x01 : 0;
    m->v1->porta |= m->k->key_up ? 0x02 : 0;
    m->v1->porta |= m->k->key_down ? 0x04 : 0;
    m->v1->porta |= m->k->key_left ? 0x08 : 0;
    m->v1->porta |= m->k->key_right ? 0x10 : 0;
    m->v1->ier = 0;

    if (old_porta_input != (m->v1->porta & ~m->v1->ddra)) {
      m->interrupt_waiting = 0x01;
    }

    // read operation
    m->mem[0x8020] = m->v1->portb;
    m->mem[0x8021] = m->v1->porta;
    m->mem[0x8022] = m->v1->ddrb;
    m->mem[0x8023] = m->v1->ddra;
    m->mem[0x802e] = m->v1->ier;
  }
}
