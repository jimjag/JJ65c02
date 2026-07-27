#ifndef __6502_EMU__
#define __6502_EMU__

#include "cpu.h"

#include <stdbool.h>

void main_loop(cpu *m);

// true once SIGINT (Ctrl-C) has been caught. NON_STOP never polls the keyboard,
// so Esc cannot request a shutdown in that mode; Ctrl-C is the only way out and
// it has to unwind through finish_io()/finish_gui() rather than killing the
// process, or the unix socket is left behind and the terminal is left in
// cbreak/noecho with the cursor hidden.
bool emu_interrupted(void);

#endif
