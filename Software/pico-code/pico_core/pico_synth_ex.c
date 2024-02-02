/**
 * MIT License
 * Copyright (c) 2021-2024 Jim Jagielski
 */


#include <stdio.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"
#include "hardware/gpio.h"
#include "hardware/irq.h"
#include "hardware/pwm.h"
#include "pico/multicore.h"
#include "pico_synth_ex_presets.h"
#include "pico_synth_ex_tables.h"

#include "pico_synth_ex.h"

static volatile uint8_t current_preset = 0;
static volatile uint8_t current_voice = 0;
static volatile uint8_t previous_voice = 0;

static void pwm_irq_handler();
static void set_sound(uint8_t preset);
static void load_sound();

/////// Oscillator group //////////////////////////////
static volatile uint8_t Osc_waveform[4]; // waveform setting value
static volatile int8_t Osc_2_coarse_pitch[4]; // oscillator 2 coarse pitch setting value
static volatile int8_t Osc_2_fine_pitch[4]; // oscillator 2 fine pitch setting value
static volatile uint8_t Osc_1_2_mix[4]; // oscillator mix setting

static inline Q28 Osc_phase_to_audio(uint8_t id, uint32_t phase, uint8_t pitch) {
    Q14 *wave_table = Osc_wave_tables[Osc_waveform[id]][(pitch + 3) >> 2];
    uint16_t curr_index = phase >> 23;
    uint16_t next_index = (curr_index + 1) & 0x000001FF;
    Q14 curr_sample = wave_table[curr_index];
    Q14 next_sample = wave_table[next_index];
    Q14 next_weight = (phase >> 9) & 0x3FFF;
    return (curr_sample << 14) + ((next_sample - curr_sample) * next_weight);
}

static inline Q28 Osc_process(uint8_t id,
                              uint16_t full_pitch, Q14 pitch_mod_in) {
    static uint32_t phase_1[4]; // Oscillator 1 phase
    int32_t full_pitch_1 = full_pitch + ((256 * pitch_mod_in) >> 14);
    full_pitch_1 += (full_pitch_1 < 0) * (0 - full_pitch_1);
    full_pitch_1 -= (full_pitch_1 > (120 << 8)) * (full_pitch_1 - (120 << 8));
    uint8_t pitch_1 = (full_pitch_1 + 128) >> 8;
    uint8_t tune_1 = (full_pitch_1 + 128) & 0xFF;
    uint32_t freq_1 = Osc_freq_table[pitch_1];
    phase_1[id] += freq_1 + ((id - 1) << 8); // Shift by voice
    phase_1[id] += ((int32_t)(freq_1 >> 8) * Osc_tune_table[tune_1]) >> 6;

    static uint32_t phase_2[4]; // Oscillator 2 phase
    int32_t full_pitch_2 =
            full_pitch_1 + (Osc_2_coarse_pitch[id] << 8) + (Osc_2_fine_pitch[id] << 2);
    full_pitch_2 += (full_pitch_2 < 0) * (0 - full_pitch_2);
    full_pitch_2 -= (full_pitch_2 > (120 << 8)) * (full_pitch_2 - (120 << 8));
    uint8_t pitch_2 = (full_pitch_2 + 128) >> 8;
    uint8_t tune_2 = (full_pitch_2 + 128) & 0xFF;
    uint32_t freq_2 = Osc_freq_table[pitch_2];
    phase_2[id] += freq_2 + ((id - 1) << 8); // Shift by voice
    phase_2[id] += ((int32_t)(freq_2 >> 8) * Osc_tune_table[tune_2]) >> 6;

    // TODO: I want to make wave_table switching smoother (Is it better to switch at the beginning of the cycle?)
    return ((Osc_phase_to_audio(id, phase_1[id], pitch_1) >> 14) *
            Osc_mix_table[Osc_1_2_mix[id] - 0]) +
           ((Osc_phase_to_audio(id, phase_2[id], pitch_2) >> 14) *
            Osc_mix_table[64 - Osc_1_2_mix[id]]);
}

//////// filter ///////////////////////////////////
static volatile uint8_t Filter_cutoff[4]; // Cutoff setting value
static volatile uint8_t Filter_resonance[4]; // Resonance setting value
static volatile int8_t Filter_mod_amount[4]; // Cutoff modulation amount setting value

static inline int32_t mul_s32_s32_h32(int32_t x, int32_t y) {
    // Higher 32 bits of signed 32-bit multiplication result
    int32_t x1 = x >> 16;
    uint32_t x0 = x & 0xFFFF;
    int32_t y1 = y >> 16;
    uint32_t y0 = y & 0xFFFF;
    int32_t x0_y1 = x0 * y1;
    int32_t z = ((x0 * y0) >> 16) + (x1 * y0) + (x0_y1 & 0xFFFF);
    return (z >> 16) + (x0_y1 >> 16) + (x1 * y1);
}

static inline Q28 Filter_process(uint8_t id, Q28 audio_in, Q14 cutoff_mod_in) {
    static uint16_t curr_cutoff[4]; // Cutoff current value
    int32_t targ_cutoff = Filter_cutoff[id] << 2; // Cutoff target value
    targ_cutoff += (Filter_mod_amount[id] * cutoff_mod_in) >> (14 - 2);
    targ_cutoff += (targ_cutoff < 0) * (0 - targ_cutoff);
    targ_cutoff -= (targ_cutoff > 480) * (targ_cutoff - 480);
    curr_cutoff[id] += (curr_cutoff[id] < targ_cutoff);
    curr_cutoff[id] -= (curr_cutoff[id] > targ_cutoff);
    struct FILTER_COEFS *coefs_ptr =
            &Filter_coefs_table[Filter_resonance[id]][curr_cutoff[id]];

    static Q28 x1[4], x2[4], y1[4], y2[4];
    Q28 x0 = audio_in;
    Q28 x3 = x0 + (x1[id] << 1) + x2[id];
    Q28 y0 = mul_s32_s32_h32(coefs_ptr->b0_a0, x3) << 4;
    y0 -= mul_s32_s32_h32(coefs_ptr->a1_a0, y1[id]) << 4;
    y0 -= mul_s32_s32_h32(coefs_ptr->a2_a0, y2[id]) << 4;
    x2[id] = x1[id];
    y2[id] = y1[id];
    x1[id] = x0;
    y1[id] = y0;
    return y0;
}

//////// Amplifier //////////////////////////////////
static inline Q28 Amp_process(uint8_t id, Q28 audio_in, Q14 gain_in) {
    return (audio_in >> 14) * gain_in; // Simplify calculation
}

//////// EG (Envelope Generator) /////////////////
static uint32_t EG_exp_table[65]; // Exponential table

static volatile uint8_t EG_decay_time[4]; // Decay time setting value
static volatile uint8_t EG_sustain_level[4]; // Sustain level setting value

static inline Q14 EG_process(uint8_t id, uint8_t gate_in) {
    static int32_t curr_level[4]; // EG output level current value
    static uint8_t curr_gate[4]; // gate input level current value
    static uint8_t curr_attack_phase[4]; // current attack phase

    curr_attack_phase[id] |= (curr_gate[id] == 0) & gate_in;
    curr_attack_phase[id] &= (curr_level[id] < (1 << 24)) & gate_in;
    curr_gate[id] = gate_in;

    if (curr_attack_phase[id]) {
        int32_t attack_targ_level = (1 << 24) + (1 << 23);
        curr_level[id] += ((attack_targ_level - curr_level[id]) >> 5);
    } else {
        static uint32_t decay_counter[4]; // Decay counter
        ++decay_counter[id];
        decay_counter[id] = (decay_counter[id] < EG_exp_table[EG_decay_time[id]]) * decay_counter[id];
        int32_t decay_targ_level = (EG_sustain_level[id] << 18) * curr_gate[id];
        int32_t to_decay = (curr_level[id] > decay_targ_level) & (decay_counter[id] == 0);
        curr_level[id] += to_decay * ((decay_targ_level - curr_level[id]) >> 5);
    }

    return curr_level[id] >> 10;
}

//////// Low Frequency Oscillator (LFO) /////////
static volatile uint8_t LFO_depth[4]; // Depth setting value
static volatile uint8_t LFO_rate[4]; // Speed ​​setting value

static inline Q14 LFO_process(uint8_t id) {
    static uint32_t phase[4]; // Phase
    phase[id] += LFO_freq_table[LFO_rate[id]] + ((id - 1) << 8); // Shift by voice

    // Generate triangle wave
    uint16_t phase_h16 = phase[id] >> 16;
    uint16_t out = phase_h16;
    out += (phase_h16 >= 32768) * (65536 - (phase_h16 << 1));
    return ((out - 16384) * LFO_depth[id]) >> 7;
}

//////// Low Frequency Oscillator (LFO) /////////
static volatile uint16_t Voice_lifetime[4]; // How long the voice lasts

//////// PWM audio output block ///////////////////////
static uint8_t PWMA_L_SLICE;
static uint8_t PWMA_L_CHAN;

#define PWMA_CYCLE (FCLKSYS / FS) // PWM cycle

void initSOUND(void) {
    PWMA_L_SLICE = pwm_gpio_to_slice_num(PWMA_L_GPIO);
    PWMA_L_CHAN = pwm_gpio_to_channel(PWMA_L_GPIO);
    gpio_set_function(PWMA_L_GPIO, GPIO_FUNC_PWM);
    pwm_set_wrap(PWMA_L_SLICE, PWMA_CYCLE - 1);
    pwm_set_chan_level(PWMA_L_SLICE, PWMA_L_CHAN, PWMA_CYCLE / 2);
    pwm_set_enabled(PWMA_L_SLICE, true);
    pwm_set_irq_enabled(PWMA_L_SLICE, true);
    irq_set_exclusive_handler(PWM_IRQ_WRAP, pwm_irq_handler);
    irq_set_enabled(PWM_IRQ_WRAP, true);
    set_sound(0);
}

static inline void PWMA_process(Q28 audio_in) {
    int32_t level_int32 = (audio_in >> 18) + (PWMA_CYCLE / 2);
    uint16_t level = (level_int32 > 0) * level_int32;
    pwm_set_chan_level(PWMA_L_SLICE, PWMA_L_CHAN, level);
}

//////// Interrupt handler and main function ////////////
static volatile uint16_t voice_gate[4]; // gate control value (per voice)
static volatile uint8_t voice_pitch[4]; // pitch control value (per voice)
static volatile int8_t octave_shift[4]; // key octave shift amount

static inline Q28 process_voice(uint8_t id) {
    Q14 lfo_out = LFO_process(id);
    Q14 eg_out = EG_process(id, (voice_gate[id] ? 1 : 0));
    Q28 osc_out = Osc_process(id, voice_pitch[id] << 8, lfo_out);
    Q28 filter_out = Filter_process(id, osc_out, eg_out);
    Q28 amp_out = Amp_process(id, filter_out, eg_out);
    if (eg_out <= 5) voice_gate[id] = 0;  // We need to force a note_off
    if (voice_gate[id]) voice_gate[id]--;
    return amp_out;
}

static void pwm_irq_handler() {
    pwm_clear_irq(PWMA_L_SLICE);

    Q28 voice_out[4];
    voice_out[0] = process_voice(0);
    voice_out[1] = process_voice(1);
    voice_out[2] = process_voice(2);
    voice_out[3] = process_voice(3);
    PWMA_process((voice_out[0] + voice_out[1] + voice_out[2] + voice_out[3]) >> 2);
}

static void set_sound(uint8_t preset) {
    if (preset < 0 || preset > (NUM_PRESETS - 1)) return;
    current_preset = preset;
}

static void load_sound() {
    printf("loading preset %d\n", current_preset);
    octave_shift[current_voice] = presets[current_preset].octave_shift;
    Osc_waveform[current_voice] = presets[current_preset].Osc_waveform;
    Filter_cutoff[current_voice] = presets[current_preset].Filter_cutoff;
    Filter_resonance[current_voice] = presets[current_preset].Filter_resonance;
    Filter_mod_amount[current_voice] = presets[current_preset].Filter_mod_amount;
    EG_decay_time[current_voice] = presets[current_preset].EG_decay_time;
    EG_sustain_level[current_voice] = presets[current_preset].EG_sustain_level;
    Osc_2_coarse_pitch[current_voice] = presets[current_preset].Osc_2_coarse_pitch;
    Osc_2_fine_pitch[current_voice] = presets[current_preset].Osc_2_fine_pitch;
    Osc_1_2_mix[current_voice] = presets[current_preset].Osc_1_2_mix;
    LFO_depth[current_voice] = presets[current_preset].LFO_depth;
    LFO_rate[current_voice] = presets[current_preset].LFO_rate;
    Voice_lifetime[current_voice] = presets[current_preset].Voice_lifetime;
}

static void play_note(uint8_t key) {
    load_sound();
    uint8_t pitch = key + (octave_shift[current_voice] * 12);
    voice_pitch[current_voice] = pitch;
    voice_gate[current_voice] = Voice_lifetime[current_voice];
    previous_voice = current_voice;
    current_voice = (++current_voice % 4);
}

static void note_off(uint8_t key) {
    uint8_t pitch = key + (octave_shift[previous_voice] * 12);
    for (uint8_t id = 0; id < 4; ++id) {
        if (voice_pitch[id] == pitch) { voice_gate[id] = 0; }
    }
}

static void all_notes_off() {
    for (uint8_t id = 0; id < 4; ++id) { voice_gate[id] = 0; }
}

void startup_chord(void) {
    //for (uint8_t id = 0; id < 4; ++id) { voice_pitch[id] = 60; }
    play_note(60);
    play_note(64);
    play_note(67);
    play_note(71);
}

/*
 * Control method

    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i': Do, Re, Mi, Fa, G, A, C, C sounds. Play (range: from middle C to C one octave above)
    '2', '3', '5', '6', '7': Sounds C#, D#, F#, G#, A#
    '1'/'9': Decrease/increase the key octave shift amount by 1 (-5 to +4)
    '0': Stop all sounds
    'A'/'a': Decrease/increase the oscillator waveform setting value by 1 (0: descending sawtooth wave, 1: square wave)
    'S'/'s': Decrease/increase oscillator 2 coarse pitch setting value by 1 (+0 to +24)
    'D'/'d': Decrease/increase oscillator 2 fine pitch setting value by 1 (+0 to +32)
    'F'/'f': Decrease/increase the oscillator mix setting value by 1 (0 to 64, mix balance of oscillators 1 and 2)
    'G'/'g': Lowers/raises the filter cutoff setting value by 1 (0 to 120, cutoff frequency changes from approximately 19Hz to approximately 20kHz)
    'H'/'h': Decrease/increase filter resonance setting value by 1 (0 to 5, Q value changes from approximately 0.7 to 4.0)
    'J'/'j': Lower/increase the cutoff modulation amount setting value from the filter's EG by 1 (+0 to +60)
    'X'/'x': Decrease/increase the EG decay time setting value by 1 (0 to 64)
    'C'/'c': Decrease/increase the EG sustain level setting value by 1 (0 to 64)
    'B'/'b': Decrease/increase the LFO depth setting value by 1 (0 to 64, pitch modulation amount)
    'N'/'n': Decrease/increase the LFO speed setting value by 1 (0 to 64, frequency changes from approximately 0.2Hz to approximately 20Hz)
    'K'/'k': Decrease/increase Lifetime setting value by 512 (0 to 64511)
    ')': Default voice
    '!': Vibrola voice
    '@': Recorder voice
    '#': Superlead voice
    '$': Chromabits voice
    '%': Bell voice
    '^': Oboe voice
    '&': Acid bass voice
    '*': Lasercat voice
    '(': Minitone voice
 */

void soundTask(void) {
    if (multicore_fifo_rvalid()) {
        uint32_t cmd = multicore_fifo_pop_blocking();
        switch ((char)cmd) {
            case 'q': play_note(60); break;
            case '2': play_note(61); break;
            case 'w': play_note(62); break;
            case '3': play_note(63); break;
            case 'e': play_note(64); break;
            case 'r': play_note(65); break;
            case '5': play_note(66); break;
            case 't': play_note(67); break;
            case '6': play_note(68); break;
            case 'y': play_note(69); break;
            case '7': play_note(70); break;
            case 'u': play_note(71); break;
            case 'i': play_note(72); break;

            case '1': if (presets[current_preset].octave_shift > -5) { --presets[current_preset].octave_shift; } break;
            case '9': if (presets[current_preset].octave_shift < +4) { ++presets[current_preset].octave_shift; } break;
            case '0': all_notes_off(); break;

            case 'A': if (presets[current_preset].Osc_waveform > 0) { --presets[current_preset].Osc_waveform; } break;
            case 'a': if (presets[current_preset].Osc_waveform < 1) { ++presets[current_preset].Osc_waveform; } break;

            case 'S': if (presets[current_preset].Osc_2_coarse_pitch > +0)  { --presets[current_preset].Osc_2_coarse_pitch; } break;
            case 's': if (presets[current_preset].Osc_2_coarse_pitch < +24) { ++presets[current_preset].Osc_2_coarse_pitch; } break;

            case 'D': if (presets[current_preset].Osc_2_fine_pitch > +0)  { --presets[current_preset].Osc_2_fine_pitch; } break;
            case 'd': if (presets[current_preset].Osc_2_fine_pitch < +32) { ++presets[current_preset].Osc_2_fine_pitch; } break;

            case 'F': if (presets[current_preset].Osc_1_2_mix > 0)  { --presets[current_preset].Osc_1_2_mix; } break;
            case 'f': if (presets[current_preset].Osc_1_2_mix < 64) { ++presets[current_preset].Osc_1_2_mix; } break;

            case 'G': if (presets[current_preset].Filter_cutoff > 0)   { --presets[current_preset].Filter_cutoff; } break;
            case 'g': if (presets[current_preset].Filter_cutoff < 120) { ++presets[current_preset].Filter_cutoff; } break;

            case 'H': if (presets[current_preset].Filter_resonance > 0) { --presets[current_preset].Filter_resonance; } break;
            case 'h': if (presets[current_preset].Filter_resonance < 5) { ++presets[current_preset].Filter_resonance; } break;

            case 'J': if (presets[current_preset].Filter_mod_amount > +0)  { --presets[current_preset].Filter_mod_amount; } break;
            case 'j': if (presets[current_preset].Filter_mod_amount < +60) { ++presets[current_preset].Filter_mod_amount; } break;

            case 'X': if (presets[current_preset].EG_decay_time > 0)  { --presets[current_preset].EG_decay_time; } break;
            case 'x': if (presets[current_preset].EG_decay_time < 64) { ++presets[current_preset].EG_decay_time; } break;

            case 'C': if (presets[current_preset].EG_sustain_level > 0)  { --presets[current_preset].EG_sustain_level; } break;
            case 'c': if (presets[current_preset].EG_sustain_level < 64) { ++presets[current_preset].EG_sustain_level; } break;

            case 'B': if (presets[current_preset].LFO_depth > 0)  { --presets[current_preset].LFO_depth; } break;
            case 'b': if (presets[current_preset].LFO_depth < 64) { ++presets[current_preset].LFO_depth; } break;

            case 'N': if (presets[current_preset].LFO_rate > 0)  { --presets[current_preset].LFO_rate; } break;
            case 'n': if (presets[current_preset].LFO_rate < 64) { ++presets[current_preset].LFO_rate; } break;

            case 'K': if (presets[current_preset].Voice_lifetime > 0)     { presets[current_preset].Voice_lifetime -= 512; } break;
            case 'k': if (presets[current_preset].Voice_lifetime < 64511) { presets[current_preset].Voice_lifetime += 512; } break;

            case ')': set_sound(0); break;
            case '!': set_sound(1); break;
            case '@': set_sound(2); break;
            case '#': set_sound(3); break;
            case '$': set_sound(4); break;
            case '%': set_sound(5); break;
            case '^': set_sound(6); break;
            case '&': set_sound(7); break;
            case '*': set_sound(8); break;
            case '(': set_sound(9); break;
        }
    }
}

void beep(void) {
    uint8_t preset = current_preset;
    load_sound(1);
    play_note(65);
    load_sound(preset);
}
