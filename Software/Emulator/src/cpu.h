#ifndef __6502_CPU__
#define __6502_CPU__

#include <stdint.h>
#include <stdbool.h>
#include <ncurses.h>
#include "via.h"
#include "lcd.h"
#include "keys.h"

#define MEMORY_SIZE (64*1024)
#define STACK_START 0x0100

#define FLAG_NEGATIVE 0x80
#define FLAG_OVERFLOW 0x40
#define FLAG_BREAK 0x10
#define FLAG_DECIMAL 0x08
#define FLAG_INTERRUPT 0x04
#define FLAG_ZERO 0x02
#define FLAG_CARRY 0x01

// set if memory was modified during processing of the last instruction
#define EMU_FLAG_DIRTY 0x01
// set if the emulator should wait for an interrupt before continuing
#define EMU_FLAG_WAIT_FOR_INTERRUPT 0x02

#define CLOCK_SPRINT 0x00
#define CLOCK_FAST   0x01
#define CLOCK_SLOW   0x02
#define CLOCK_STEP   0x04

typedef struct {
    // clock mode
    uint8_t clock_mode;
    // program counter
    uint16_t pc;
    // flag indicating whether instruction set new pc
    bool pc_set;
    // actual value of program counter
    uint16_t pc_actual;
    // current opcode
    uint8_t opcode;
    // index registers
    uint8_t x, y;
    // stack pointer
    uint8_t sp;
    // accumulator
    uint8_t ac;
    // status register
    uint8_t sr;
    // emulator flag register (not in 6502 spec, not accessible from assembler)
    uint8_t emu_flags;
    // set to nonzero if there is an outstanding interrupt
    uint8_t interrupt_waiting;
    // RAM
    uint8_t mem[MEMORY_SIZE];
    // stores the address of memory modified by the last instruction
    uint16_t dirty_mem_addr;
    // cycle counter
    uint32_t cycle;
    //
    bool shutdown;
    //
    WINDOW* terminal;
} cpu;

cpu * new_cpu();

void destroy_cpu(cpu* m);

#endif
