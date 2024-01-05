/**
 *
 * HARDWARE CONNECTIONS
 *  - GPIO 17 ---> VGA Hsync
 *  - GPIO 18 ---> VGA Vsync
 *  - GPIO 19 ---> 470 ohm resistor ---> VGA Red
 *  - GPIO 20 ---> 470 ohm resistor ---> VGA Green
 *  - GPIO 21 ---> 470 ohm resistor ---> VGA Blue
 *  - GPIO 22 ---> 1k ohm resistor ---> VGA Intensity (bright)
 *  - GPIO 15 ---> PS2 Data pin
 *  - GPIO 16 ---> PS2 Clock pin
 *  - RP2040 GND ---> VGA GND
 *
 * RESOURCES USED
 *  - VGA:
 *  -   PIO state machines 0, 1, and 2 on PIO instance 0
 *  -   DMA channels 0, 1, 2, and 3
 *  -   153.6 kBytes of RAM (for pixel color data)
 *  - PS2:
 *  -   PIO state machine 0 on PIO instance 1
 *
 */


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

