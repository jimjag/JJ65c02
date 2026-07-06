// Headless audio verification: run the real synth DSP (pico_synth_ex.c) for the
// startup chord and report peak/RMS + write a WAV. Confirms the emulated sound
// path produces non-silent samples without needing to open an audio device.
//
//   cc -DHOST_SIM sim_audio_probe.c ../pico_core/pico_synth_ex.c -lm -o _probe
//   ./_probe && open chord.wav
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pico_shim.h"

// soundTask (compiled in pico_synth_ex.c) references these; not called here.
bool     multicore_fifo_rvalid(void)      { return false; }
uint32_t multicore_fifo_pop_blocking(void){ return 0; }

static void wr16(FILE *f, uint16_t v){ fputc(v,f); fputc(v>>8,f); }
static void wr32(FILE *f, uint32_t v){ fputc(v,f); fputc(v>>8,f); fputc(v>>16,f); fputc(v>>24,f); }

static void write_wav(const char *path, const int16_t *s, int n, int rate) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror("fopen"); return; }
    uint32_t data = (uint32_t)n * 2;
    fwrite("RIFF", 1, 4, f); wr32(f, 36 + data); fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f); wr32(f, 16); wr16(f, 1); wr16(f, 1);
    wr32(f, rate); wr32(f, rate * 2); wr16(f, 2); wr16(f, 16);
    fwrite("data", 1, 4, f); wr32(f, data);
    fwrite(s, 2, n, f);
    fclose(f);
}

int main(void) {
    initSOUND();
    startup_chord();

    const int rate = 44100, n = rate * 2;          // 2 seconds
    int16_t *buf = malloc((size_t)n * sizeof(int16_t));
    synth_render_s16(buf, n);

    int peak = 0; double sumsq = 0;
    for (int i = 0; i < n; i++) {
        int a = buf[i] < 0 ? -buf[i] : buf[i];
        if (a > peak) peak = a;
        sumsq += (double)buf[i] * buf[i];
    }
    double rms = (n > 0) ? __builtin_sqrt(sumsq / n) : 0;
    printf("samples=%d  peak=%d/32767  rms=%.1f\n", n, peak, rms);
    write_wav("chord.wav", buf, n, rate);
    printf("wrote chord.wav (%d Hz, %.1fs)\n", rate, (double)n / rate);
    free(buf);
    return peak > 0 ? 0 : 2;                        // nonzero exit if silent
}
