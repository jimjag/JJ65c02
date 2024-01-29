
typedef int32_t Q28; // Signed fixed-point number with 28-bit fractional part
typedef int16_t Q14; // Signed fixed-point number with 14-bit fractional part

#define ONE_Q28 ((Q28) (1 << 28)) // 1.0 for Q28 type
#define ONE_Q14 ((Q14) (1 << 14)) // 1.0 for type Q14
#define PI ((float) M_PI) // Pi in float type
#define FCLKSYS (250000000) // system clock frequency (Hz)
#define FS (44100) // sampling frequency (Hz)
#define FA (440.0F) // reference frequency (Hz)

/* GPIO definitions */
#define PWMA_L_GPIO             28 // GPIO number for PWM output (left channel)

void initSOUND(void);
void soundTask(void);
void startup_chord(void);
void beep(void);
