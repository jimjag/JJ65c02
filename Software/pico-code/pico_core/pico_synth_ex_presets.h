#ifndef PICO_SYNTH_EX_PRESETS_H_
#define PICO_SYNTH_EX_PRESETS_H_

typedef struct {
    int8_t octave_shift;
    uint8_t Osc_waveform;
    int8_t Osc_2_coarse_pitch;
    int8_t Osc_2_fine_pitch;
    uint8_t Osc_1_2_mix;
    uint8_t Filter_cutoff;
    uint8_t Filter_resonance;
    int8_t Filter_mod_amount;
    uint8_t EG_decay_time;
    uint8_t EG_sustain_level;
    uint8_t LFO_depth;
    uint8_t LFO_rate;
    uint16_t Voice_lifetime;
} Preset_t;

#define NUM_PRESETS 10
Preset_t presets[NUM_PRESETS];
Preset_t defaults[NUM_PRESETS] = {
    {0,  0, 0,  4,  16, 60,  3, 60, 40, 0,  16, 48, 2048}, // Default
    {0,  1, 4,  0,  8,  50,  1, 60, 40, 0,  16, 24, 2048}, // Vibrola
    {0,  1, 0,  2,  1,  33,  4, 42, 35, 50, 7,  39, 2048}, // Recorder
    {-2, 0, 12, 12, 24, 68,  3, 45, 14, 46, 12, 45, 20480}, // Superlead
    {0,  1, 3,  0,  0,  100, 4, 60, 20, 0,  12, 32, 2048}, // Chromabits
    {0,  1, 12, 2,  21, 70,  4, 19, 53, 29, 4,  8,  2048}, // Bell
    {-2, 0, 0,  0,  55, 40,  5, 18, 34, 64, 0,  0,  2048}, // Oboe
    {-3, 0, 12, 0,  61, 97,  1, 40, 12, 50, 4,  45, 20480}, // Acid bass
    //{ 0,  0, 12,  2,   9,  44,  3,  59,  42, 32, 10,  9, 2048}, // Lasercat
    {-2, 0, 0,  0,  39, 80,  5, 23, 31, 43, 3,  19, 2048}, // Zippy Zap
    {0,  1, 0,  0,  59, 60,  4, 2,  18, 56, 8,  58, 2048}, // Minitone
};

#endif
