#include "keys.h"
#include <stdlib.h>
#include <stdio.h>

keys * new_keys() {
  keys *k = malloc(sizeof(keys));

  k->key_up = false;
  k->key_down = false;
  k->key_left = false;
  k->key_right = false;
  k->key_enter = false;

  return k;
}

void destroy_keys(keys* k) {
  free(k);
}

