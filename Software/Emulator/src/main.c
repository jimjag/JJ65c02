#include "cpu.h"
#include "emu.h"
#include "functions.h"
#include "io.h"
#include "gui.h"
#include "opcodes.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>

void usage() {
    printf("x65c02: a simple 65C02/65C22 emulator\n");
    printf("usage: x65c02 [OPTION]... FILE\n");
    printf("options:\n");
    printf("  -b ADDR the base address at which code will be loaded (in hex, default a000)\n");
    printf("  -r run as fast as possible\n");
    printf("  -4 use 4-bit mode for LCD\n");
}

int main(int argc, char *argv[]) {
    int base_addr = 0xa000;
    bool sprint = false;
    bool lcd_8_bit = true;

    int c;
    while ((c = getopt(argc, argv, "hb:r4")) != -1) {
        switch (c) {
        case 'b':
            base_addr = strtol(optarg, NULL, 16);
            break;

        case 'h':
            usage();
            return 0;

        case 'r':
            sprint=true;
            break;

        case '4':
            lcd_8_bit=false;
            break;

        case '?':
            if (optopt == 'b') {
                fprintf(stderr, "Option -%c requires an argument.\n", optopt);
            }
            usage();
            return -1;
        }
    }

    if (optind == argc) {
        printf("no input file specified.\n");
        usage();
        return -1;
    }

    FILE *in_f = fopen(argv[optind], "r");
    if (in_f == NULL) {
        printf("Invalid input file specified\n");
        usage();
        return -1;
    }
    int b;
    int i = base_addr;
    cpu *m = new_cpu();
    if (sprint) {
      m->clock_mode = CLOCK_SPRINT;
    }
    m->lcd_8_bit=lcd_8_bit;
    while ((b = fgetc(in_f)) != EOF) {
        m->mem[i++] = (uint8_t) b;
    }
    fclose(in_f);
    set_pc(m, (m->mem[0xFFFD] << 8) | m->mem[0xFFFC]);
    main_loop(m);
    destroy_cpu(m);
    return 0;
}
