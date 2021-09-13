#include "cpu.h"
#include "via.h"
#include <stdlib.h>
#include <string.h>

cpu * new_cpu() {
    cpu *m = malloc(sizeof(cpu));
    m->clock_mode = CLOCK_STEP;
    m->opcode = 0;
    m->pc = 0;
    m->pc_set = false;
    m->pc_actual = 0;
    m->sr = FLAG_INTERRUPT;
    m->sp = 0xFF;
    m->interrupt_waiting = 0x00;
    memset(m->mem, 0xFF, MEMORY_SIZE);
    m->v1 = new_via();
    m->l = new_lcd();
    m->k = new_keys();
    m->cycle = 0;
    return m;
}

void destroy_cpu(cpu* m) {
  destroy_via(m->v1);
  destroy_lcd(m->l);
  destroy_keys(m->k);
  free(m);
}