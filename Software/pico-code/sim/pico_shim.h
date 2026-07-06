// Host (macOS) shim for the Pico SDK symbols that pico_core_demo.c and
// vga_core.h reference. Included ONLY when building the SDL simulation
// (compile with -DHOST_SIM). On real hardware none of this is used; the
// firmware build never defines HOST_SIM, so the genuine Pico SDK is used
// instead.
//
// This provides just enough of the SDK surface for the demo to compile and
// run against a host framebuffer + SDL viewer:
//   - flash/placement macros collapse to no-ops
//   - timing (sleep_ms/us), clock, and stdio become host equivalents / stubs
//   - multicore + sound become silent stubs (core1 is not run)
//   - a host repeating timer (pthread) drives the demo's countdown
//   - PS/2 input is fed from SDL keyboard events (see sim_feed_key)
#ifndef SIM_PICO_SHIM_H
#define SIM_PICO_SHIM_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// pico.h normally provides this typedef.
typedef unsigned int uint;

// Flash placement / attribute macros -> no-ops on the host.
#define __in_flash(...)
#define __not_in_flash_func(f) f
#define __time_critical_func(f) f
#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (2 * 1024 * 1024)
#endif

// ---- pico/stdlib timing + init ----
void sleep_ms(uint32_t ms);
void sleep_us(uint64_t us);
bool set_sys_clock_khz(uint32_t khz, bool required);
void stdio_init_all(void);

// ---- pico/multicore (silent stubs) ----
void multicore_launch_core1(void (*entry)(void));
void multicore_fifo_push_blocking(uint32_t data);

// ---- repeating timer (host pthread) ----
struct repeating_timer {
    long  delay_us;
    void *user_data;
    void *_impl;
};
typedef bool (*repeating_timer_callback_t)(struct repeating_timer *);
bool add_repeating_timer_ms(int32_t delay_ms, repeating_timer_callback_t cb,
                            void *user_data, struct repeating_timer *out);

// ---- PS/2 keyboard: fed by the SDL viewer, drained by the demo ----
void          initPS2(void);
void          clearPS2(void);
unsigned char ps2GetChar(bool auto_print);
// Called from the SDL main thread to enqueue a decoded ASCII byte.
void          sim_feed_key(unsigned char c);

// ---- sound synth: silent stubs ----
void initSOUND(void);
void soundTask(void);
void startup_chord(void);
void beep(void);

#endif // SIM_PICO_SHIM_H
