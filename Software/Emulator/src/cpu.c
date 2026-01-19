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
    memset(m->mem, 0x00, MEMORY_SIZE);
    m->cycle = 0;
    m->terminal = NULL;
    return m;
}

void destroy_cpu(cpu* m) {
  free(m);
}
