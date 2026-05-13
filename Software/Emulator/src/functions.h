#ifndef __6502_FUNCTIONS__
#define __6502_FUNCTIONS__

#include <stdlib.h>

#include "cpu.h"
#include "gui.h"

static inline uint8_t read_byte(cpu *m, uint16_t address) {
    static char trace_entry[80];
    sprintf(trace_entry, "Bus addr:%04x mode:r value:%02x\n", address, m->mem[address]);
    trace_emu(trace_entry);
    return m->mem[address];
}

static inline uint8_t write_byte(cpu *m, uint16_t address, uint8_t value) {
    static char trace_entry[80];
    sprintf(trace_entry, "Bus addr:%04x mode:W value:%02x\n", address, value);
    trace_emu(trace_entry);
    return m->mem[address]=value;
}

static inline uint8_t read_next_byte(cpu *m, uint8_t pc_offset) {
    return read_byte(m, m->pc + pc_offset);
}

static inline void set_pc(cpu *m, uint16_t address) {
    m->pc = address;
    m->pc_set = true;
}

#define ZP(x) ((uint8_t) (x))
//#define STACK_PUSH(m) (m)->mem[(m)->sp-- + STACK_START]
#define STACK_PUSH(m, v) (write_byte(m, m->sp-- + STACK_START, v))
//#define STACK_POP(m) (m)->mem[++(m)->sp + STACK_START]
#define STACK_POP(m) (read_byte(m, ++(m)->sp + STACK_START))

static inline size_t mem_abs(uint8_t low, uint8_t high, uint8_t off) {
    return (uint16_t) off + (uint16_t) low + ((uint16_t) high << 8);
}

static inline size_t mem_indirect_index(cpu *m, uint8_t addr, uint8_t off) {
    return mem_abs(read_byte(m, addr), read_byte(m, ZP(addr+1)), off);
}

static inline size_t mem_indexed_indirect(cpu *m, uint8_t addr, uint8_t off) {
    return mem_abs(read_byte(m, ZP(addr+off)), read_byte(m, ZP(addr+off+1)), 0);
}

static inline size_t mem_indirect_zp(cpu *m, uint8_t addr) {
    return mem_abs(read_byte(m, addr), read_byte(m, ZP(addr+1)), 0);
}

// set arg MUST be 16 bits, not 8, so that add results can fit into set.
static inline void set_flag(cpu *m, uint8_t flag, uint16_t set) {
    if (set) {
        m->sr |= flag;
    } else {
        m->sr &= ~flag;
    }
}

static inline uint8_t get_flag(cpu *m, uint8_t flag) {
    return (m->sr & flag) > 0;
}

static inline uint8_t get_emu_flag(cpu *m, uint8_t flag) {
    return (m->emu_flags & flag) > 0;
}

// set flags for the result of a computation. set_flags should be called on the
// result of any arithmetic operation.
static inline void set_flags(cpu *m, uint8_t val) {
    set_flag(m, FLAG_ZERO, !val);
    set_flag(m, FLAG_NEGATIVE, val & 0x80);
}

static inline uint8_t bcd(uint8_t val) {
    // bcd is "binary coded decimal"; it treats the upper nibble and lower
    // nibble of a byte each as a decimal digit, so 01011000 -> 0101 1000 -> 58.
    // in other words, treat hex output as decimal output, so 0x58 is treated as
    // 58. this is dumb and adds a bunch of branching to opcode interpretation
    // that I Do Not Like.
    return 10 * (val >> 4) + (0x0F & val);
}

static inline void add(cpu *m, uint16_t r1) {
    uint8_t operand = (uint8_t) r1;
    uint8_t a = m->ac;
    uint8_t carry_in = get_flag(m, FLAG_CARRY);
    uint16_t result;
    if (get_flag(m, FLAG_DECIMAL)) {
        uint16_t dec = bcd(a) + bcd(operand) + carry_in;
        set_flag(m, FLAG_CARRY, dec > 99);
        dec %= 100;
        result = ((dec / 10) << 4) | (dec % 10);
    } else {
        result = a + operand + carry_in;
        set_flag(m, FLAG_CARRY, result & 0xFF00);
    }
    set_flag(m, FLAG_OVERFLOW, (a ^ result) & (operand ^ result) & 0x80);
    set_flag(m, FLAG_ZERO, !(result & 0xFF));
    set_flag(m, FLAG_NEGATIVE, result & 0x80);
    m->ac = (uint8_t) result;
}

static inline void sub(cpu *m, uint16_t r1) {
    uint8_t operand = (uint8_t) r1;
    uint8_t a = m->ac;
    uint8_t carry_in = get_flag(m, FLAG_CARRY);
    uint16_t bin = a - operand - !carry_in;
    set_flag(m, FLAG_OVERFLOW, (a ^ operand) & (a ^ bin) & 0x80);
    set_flag(m, FLAG_CARRY, !(bin & 0xFF00));
    if (get_flag(m, FLAG_DECIMAL)) {
        int16_t dec = bcd(a) - bcd(operand) - !carry_in;
        if (dec < 0) dec += 100;
        m->ac = ((dec / 10) << 4) | (dec % 10);
    } else {
        m->ac = (uint8_t) bin;
    }
    set_flag(m, FLAG_ZERO, !m->ac);
    set_flag(m, FLAG_NEGATIVE, m->ac & 0x80);
}

static inline void cmp(cpu *m, uint8_t mem, uint8_t reg) {
    set_flag(m, FLAG_CARRY, reg >= mem);
    set_flag(m, FLAG_ZERO, reg == mem);
    set_flag(m, FLAG_NEGATIVE, 0x80 & (reg - mem));
}

// called at the start of processing an instruction to reset instruction-local
// emulator state
static inline void reset_emu_flags(cpu *m) {
    m->emu_flags = 0x00;
}

// mark a memory address as dirty
static inline void mark_dirty(cpu *m, uint16_t addr) {
    m->emu_flags |= EMU_FLAG_DIRTY;
    m->dirty_mem_addr = addr;
}

#endif
