
# JJ65c02: The Pi Pico Console Chip

`pico_core` serves as the core code for the Pi Pico support chip for
the JJ65c02 SBC. It performs 4 main functions:

* Interfaces with a PS/2 keyboard for console input
* Outputs VGA at 640x480, 4-bit color
* Provides Smart Terminal, Graphics and Text mode primitives
* Sound generation and output (4 voices, 10 tones)

## PS/2 Keyboard

2 __GPIO__ pins are used on the Pi Pico for the PS/2 data and clock signals. Data is
read and serialized using a __PIO__ state machine. This data is then fed into the
VGA/terminal subsystem (if desired) as well as sent to the JJ65c02 system using 7 pins on
the VIA chip and one pin for the data handshake. In general, we expect the 6502 to echo back
any characters rec'd/sent from the PS/2 system.

PS/2 scancodes are translated to ASCII, and support uppercase, lowercase and
control characters. The __arrow keys__ are specially handled and mapped
to ASCII `0x11` through `0x14`.

## VGA Output

The Pi Pico supports a resolution of 640x480 pixels at 60Khz, with a 4 bit
color palette. The `HSYNC`, `VSYNC` and `RGBI` signals are generated using
3 __PIO__ state machines with 6 output pins. Higher resolutions are possible
but are limited by the onboard memory available on the __RP2040__.

The display itself is fully bitmapped, allowing for each individual pixel
to be directly addressed.  Changes to the bitmap are automatically reflected
in the output using the __RP2040__ DMA capability.

Character bytes can be written to the __RP2040__ from the 65C02 by simply writing
to the Pi Pico's mapped direct address. This uses 8 pins on the Pi Pico for the
data and 1 pin to serve as a `write/data-ready/chip-select` signal.

## Terminal, Graphics and Text

Included in the VGA subsystem is a set of text and graphics primitives. These include:

### Graphics

* Drawing a pixel
* Drawing a line
* Drawing an outlined rectangle
* Drawing a filled rectangle
* Drawing a circle
* Drawing a filled circle

### Terminal/Text

* 80x30 screen size (8x16 fonts)
* Multiple font glyphs
* Fully addressable cursor
* Blinking cursor
* Smooth and Jump scrolling
* A subset of ANSI/Xterm/VT100 escape sequences

### Supported Escape Sequences

#### Standard

* `ESC[<n>A` Move text cursor up `<n>` lines (Arrow Up)
* `ESC[<n>B` Move text cursor down `<n>` lines (Arrow Down)
* `ESC[<n>C` Move text cursor right `<n>` cells (Arrow Right)
* `ESC[<n>D` Move text cursor left `<n>` cells (Arrow Left)
* `ESC[H` Move text cursor to home `(1,1)`
* `ESC[x;yH` Move text cursor to terminal location `(x,y)`
* `ESC[2J` Clear entire screen
* `ESC[<n>S` Scroll up `<n>` lines
* `ESC[?4h` Enable smooth scrolling
* `ESC[?25h` Enable/show cursor
* `ESC[?4l` Disable smooth scrolling - use jump scrolling
* `ESC[?25l` Disable/hide cursor
* `ESC[0m` Reset to default foreground (FG) and background (BG) colors
* `ESC[7m` Reverse colors (swap FG and BG)
* `ESC[<30–37>m` Set FG color to `<30-37>`(ANSI color)
* `ESC[38;5;<n>m` Set FG color to `<n>` (RGB)
* `ESC[<40–47>m` Set BG color to `<40-47>`(ANSI color)
* `ESC[38;5;<n>m` Set BG color to `<n>` (RGB)
* `ESC[s` Save text cursor position
* `ESC[u` Move text cursor to saved position

NOTE: Text cursor positions are 1-based: (1,1) to (80,30) in keeping with ANSI terminal standards.

#### Extensions

* `ESC[Z;<c>Z` Write character `<c>` at current text cursor position
* `ESC[Z1;<x0>;<y0>;<x1>;<y1>Z` Draw line from `(x0,y0)` to `(x1,y1)` with current FG color
* `ESC[Z2;<x>;<y>;<w>;<h>Z`Draw rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis)
* `ESC[Z3;<x>;<y>;<w>;<h>Z`Draw filled rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis)
* `ESC[Z4;<x>;<y>;<r>Z`Draw circle with center at `(x,y)` radius `r`
* `ESC[Z5;<x>;<y>;<r>Z`Draw filled circle with center at `(x,y)` radius `r`
* `ESC[Z6;<x>;<y>;<w>;<h>;<r>Z`Draw rounded rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis) and corner radius of `<r>`
* `ESC[Z7;<x>;<y>;<w>;<h>;<r>Z`Draw filled rounded rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis) and corner radius of `<r>`
* `ESC[Z8;<color>Z` Set FG color to `<color>`
* `ESC[Z9;<color>Z` Set BG color to `<color>`
* `ESC[Z10;<x>;<y>;<c>Z` Graphically draw the char `<c>` with its upper left corner starting at pixel location (x,y)
* `ESC[Z11;<code>Z` Send ascii char decimal code`<code>` to the Pi Pico Sound `soundTask()` function (see `pico_synth_ex.c`). For example, `ESC[Z11;101Z` will send `e` to `soundTask()` to play a single `Mi` note

Pixel locations are 0-based: (0,0) to (639, 479).

Graphics (lines, circles, ...) use FG color for their color.

Our color set uses:
```
RGB:          332:      Us:
--------      ----      ------------
0x000000  ->  0x00  ->  Black
0xc00000  ->  0xc0  ->  Red
0x00c000  ->  0x18  ->  Green
0xc0c000  ->  0xd8  ->  Yellow
0x0000c0  ->  0x03  ->  Blue
0xc000c0  ->  0xc3  ->  Magenta
0x00c0c0  ->  0x1b  ->  Cyan
0xc0c0c0  ->  0xdb  ->  Light Grey
0x808080  ->  0x92  ->  Grey
0xff0000  ->  0xe0  ->  Bright Red
0x00ff00  ->  0x1c  ->  Bright Green
0xffff00  ->  0xfc  ->  Bright Yellow
0x0080ff  ->  0x13  ->  Bright Blue
0xff00ff  ->  0xe3  ->  Bright Magenta
0x00ffff  ->  0x1f  ->  Bright Cyan
0xffffff  ->  0xff  ->  White

0xffc0cb/*  ->  0xfb  ->  Transparent  // All other colors are assumed to be transparent

enum colors { BLACK=0x00, RED=0xc0; GREEN=0x18, YELLOW=0xd8,
    BLUE=0x03, MAGENTA=0xc3, CYAN=0x1b, LIGHT_GREY=0xdb,
    GREY=0x92, LIGHT_RED=0xe0, LIGHT_GREEN=0x1c, LIGHT_YELLOW=0xfc,
    LIGHT_BLUE=0x13, LIGHT_MAGENTA=0xe3, LIGHT_CYAN=0x1f, WHITE=0xff,
    TRANSPARENT=0xfb };

```

When creating graphics, including Sprites and Tiles, use the above RGB colors
for the master copies and then use software such as
`./lv_img_conv.js -c CF_TRUE_COLOR -f` to create an RGB332 bitmap from
the RGB image itself. You can also create the bimap directly, using the
RGB332 values as well. When Sprites and Tiles are loaded, the RGB332 colors,
including transparency, are converted to our internal colors. When specifying
colors for graphic primitives (eg: `ESC[Z8;<color>Z`), the color must
be in the corresponding RGB332 value noted above.
