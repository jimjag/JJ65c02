#include "emu.h"

#include <stdio.h>
#include "functions.h"
#include "opcodes.h"
#include "gui.h"
#include "io.h"

#define NEXT_BYTE(cpu) (read_next_byte((cpu), pc_offset++))

void main_loop(cpu *m) {
    uint8_t opcode;
    uint8_t arg1, arg2, t1, t2;
    int8_t s1;
    uint16_t r1, r2;

    // pc_offset is used to read from memory like a stream when processing
    // bytecode without modifying the pc. pc_start is the memory address of the
    // currently-executing opcode; if pc == pc_start at the end of a simulation
    // step, we add pc_offset to get the start of the next instruction. if pc !=
    // pc_start, we branched so we don't touch the pc.
    uint8_t pc_offset = 0;

    // branch_offset is an offset that will be added to the program counter
    // after we move to the next instruction
    int8_t branch_offset = 0;

    init_gui();
    init_io();

    for (;;) {
        reset_emu_flags(m);

        // read IO data
        handle_io(m, true);

        pc_offset = 0;
        branch_offset = 0;
        m->pc_actual = m->pc;
        opcode = NEXT_BYTE(m);
        m->opcode = opcode;
        m->pc_set = false;

        switch (opcode) {
            #include "opcode_handlers/arithmetic.h"
            #include "opcode_handlers/branch.h"
            #include "opcode_handlers/compare.h"
            #include "opcode_handlers/flags.h"
            #include "opcode_handlers/incdec.h"
            #include "opcode_handlers/interrupts.h"
            #include "opcode_handlers/jump.h"
            #include "opcode_handlers/load.h"
            #include "opcode_handlers/logical.h"
            #include "opcode_handlers/shift.h"
            #include "opcode_handlers/stack.h"
            #include "opcode_handlers/store.h"
            #include "opcode_handlers/transfer.h"

            case NOP:
            default:
                // Unknown opcodes are a NOP in the 65C02 processor family
                break;
            
            case STP:
                goto end;
        }

        if (!m->pc_set) {
            m->pc += pc_offset;
        }
        m->pc += branch_offset;

        m->cycle+=translate_opcode_cycles(opcode);

        do {
            // update IO data            
            handle_io(m, false);
            update_gui(m);
            // clear dirty memory flag immediately so that subsequent runs don't
            // redo whatever I/O operation is associated with the dirty memaddr
            m->emu_flags &= ~EMU_FLAG_DIRTY;
        } while ((m->emu_flags & EMU_FLAG_WAIT_FOR_INTERRUPT) &&
                 !m->interrupt_waiting);

        if (m->interrupt_waiting && !get_flag(m, FLAG_INTERRUPT)) {
            STACK_PUSH(m, (m->pc & 0xFF00) >> 8);
            STACK_PUSH(m, m->pc & 0xFF);
            STACK_PUSH(m, m->sr);

            m->interrupt_waiting = 0x00;
            set_pc(m, mem_abs(m->mem[0xFFFE], m->mem[0xFFFF], 0));
            m->sr |= FLAG_INTERRUPT;
        }
        if (m->shutdown) {
            break;
        }
    }
end:
    update_gui(m);
    finish_io();
    finish_gui();
}
