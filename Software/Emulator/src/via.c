#include "via.h"
#include <stdlib.h>
#include <string.h>

via * new_via() {
  via *v = malloc(sizeof(via));
  v->portb=0x00;
  v->porta=0x00;
  v->ddrb=0x00;
  v->ddrb=0x00;
  return v;
}

void destroy_via(via* v) {
  free(v);
}
