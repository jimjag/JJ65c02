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
    printf("  -s run as fast as possible (sprint)\n");
    printf("  -f run fast\n");
}

int main(int argc, char *argv[]) {
    int base_addr = 0xb000;
    bool sprint = false;
    bool fast = false;

    int c;
    while ((c = getopt(argc, argv, "hb:sf")) != -1) {
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
