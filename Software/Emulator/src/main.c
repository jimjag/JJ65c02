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
    printf("  -b ADDR the base address at which code will be loaded (in hex, default B000)\n");
    printf("  -n run as fast as possible (non-stop)\n");
    printf("  -s run almost as fast as possible (sprint)\n");
    printf("  -f run fast\n");
    printf("  -p PATH connect to the JJ65c02 Pico VGA/Sound sim at unix socket PATH\n");
}

int main(int argc, char *argv[]) {
    int base_addr = 0xb000;
    bool sprint = false;
    bool fast = false;
    bool non_stop = false;

    int c;
    while ((c = getopt(argc, argv, "hb:snfp:")) != -1) {
        switch (c) {
        case 'b':
            base_addr = strtol(optarg, NULL, 16);
            break;

        case 'h':
            usage();
            return 0;

        case 's':
            sprint=true;
            break;

        case 'f':
            fast=true;
            break;

        case 'n':
            non_stop=true;
            break;

        case 'p':
            picolink_path = optarg;
            break;

        case '?':
            if (optopt == 'b' || optopt == 'p') {
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
    if (non_stop) {
      m->clock_mode = CLOCK_NON_STOP;
    }
    if (sprint) {
      m->clock_mode = CLOCK_SPRINT;
    }
    if (fast) {
      m->clock_mode = CLOCK_FAST;
    }
    while ((b = fgetc(in_f)) != EOF) {
        m->mem[i++] = (uint8_t) b;
    }
    fclose(in_f);
    set_pc(m, (m->mem[0xFFFD] << 8) | m->mem[0xFFFC]);
    main_loop(m);
    destroy_cpu(m);
    return 0;
}
