#ifndef __6502_PICOLINK__
#define __6502_PICOLINK__

#include <stdbool.h>
#include <stdint.h>

// picolink connects the emulator to the JJ65c02 Pico VGA/Sound host simulation
// (../pico-code/sim) over a Unix domain socket, standing in for the physical
// bus between the 6502 SBC and the RP2350 support chip.
//
//   - Bytes the 6502 writes to PICO_ADDR ($A800) are forwarded to the sim,
//     which feeds them into the real firmware renderer's handleByte().
//   - PS/2 key bytes the sim produces are read back and injected into the
//     emulated VIA Port A, exactly as physical keyboard bytes would arrive.
//
// The link is optional: if `path` is NULL or the sim is not reachable, the
// emulator runs standalone and its normal ncurses terminal output is used.

// Connect to the sim's listening socket at `path` (retrying briefly). Returns
// true if connected. A NULL path disables the link. Safe to call once at
// startup.
bool picolink_init(const char *path);

// True if the link is currently connected and usable.
bool picolink_active(void);

// Forward one byte written by the 6502 to the Pico ($A800 store). No-op when
// the link is inactive. A broken pipe deactivates the link.
void picolink_send_byte(uint8_t byte);

// Non-blocking read of one PS/2 byte coming back from the sim. Returns true and
// stores the byte in *out if one was available, false otherwise.
bool picolink_poll_byte(uint8_t *out);

// Tear down the link.
void picolink_close(void);

#endif
