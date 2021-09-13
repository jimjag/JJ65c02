#ifndef __6502_KEYS__
#define __6502_KEYS__

#include <stdint.h>
#include <stdbool.h>

typedef struct {
  // key states
  bool key_up;
  bool key_down;
  bool key_left;
  bool key_right;
  bool key_enter;
} keys;

keys* new_keys();

void destroy_keys(keys* l);

#endif
