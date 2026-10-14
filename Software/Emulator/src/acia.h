#ifndef __6502_ACIA__
#define __6502_ACIA__

#include <stdbool.h>
#include <stdint.h>

#include "cpu.h"

// 6551 ACIA at $A010-$A013, serial line over a Unix socket the harness
// listens on (-a PATH). Without a path the registers stay plain RAM.
extern const char *acia_path;

bool acia_init(const char *path);
bool acia_active(void);
void acia_close(void);

// Call after every instruction: delivers a pending byte and refreshes $A011.
void acia_service(cpu *m);
// Call when the last instruction stored to addr in $A010-$A013.
void acia_write(cpu *m, uint16_t addr);
// Call from read_byte for every bus read.
void acia_note_read(uint16_t addr);

#endif
