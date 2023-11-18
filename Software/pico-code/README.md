
# JJ65c02: The Pi Pico PS/2|VGA Support Chip

`pico_core` serves as the core code for the Pi Pico support chip for
the JJ65c02 SBC. It performs 3 main functions:

* Interfaces with a PS/2 keyboard for console input
* Outputs VGA at 640x480, 4-bit color
* Provides Smart Terminal, Graphics and Text mode primitives

## PS/2 Keyboard

2 __GPIO__ pins are used on the Pi Pico for the PS/2 data and clock signals. Data is
read and serialized using a __PIO__ state machine. This data is then fed into the
VGA/terminal subsystem as well as sent to the JJ65c02 system using 6 pins on
the VIA chip and one pin for the data handshake.

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

* `ESC[<n>A` Move cursor up `<n>` lines (Arrow Up)
* `ESC[<n>B` Move cursor down `<n>` lines (Arrow Down)
* `ESC[<n>C` Move cursor right `<n>` cells (Arrow Right)
* `ESC[<n>D` Move cursor left `<n>` cells (Arrow Left)
* `ESC[H` Move cursor to home `(0,0)`
* `ESC[x;yH` Move cursor to `(x,y)`
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
* `ESC[s` Save cursor position
* `ESC[u` Move cursor to saved position

#### Extension

* `ESC[Z;<c>Z` Write character `<c>` at current cursor position
* `ESC[Z1;<x0>;<y0>;<x1>;<y1>Z` Draw line from `(x0,y0)` to `(x1,y1)` with current FG color
* `ESC[Z2;<x>;<y>;<w>;<h>Z`Draw rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis)
* `ESC[Z3;<x>;<y>;<w>;<h>Z`Draw filled rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis)
* `ESC[Z4;<x>;<y>;<r>Z`Draw circle with center at `(x,y)` radius `r`
* `ESC[Z5;<x>;<y>;<r>Z`Draw filled circle with center at `(x,y)` radius `r`
* `ESC[Z6;<x>;<y>;<w>;<h>;<r>Z`Draw rounded rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis) and corner radius of `<r>`
* `ESC[Z7;<x>;<y>;<w>;<h>;<r>Z`Draw filled rounded rectangle starting at `(x,y)` with width `w` (x-axis) and height `h` (y-axis) and corner radius of `<r>`
* `ESC[Z8;<color>Z` Set FG color to `<color>`
* `ESC[Z9;<color>Z]` Set BG color to `<color>`

Graphics use FG color.
Our color set uses:
```
enum colors {BLACK, RED, GREEN, YELLOW,
             BLUE, MAGENTA, CYAN, LIGHT_GREY,
             GREY, LIGHT_RED, LIGHT_GREEN, LIGHT_YELLOW,
             LIGHT_BLUE, LIGHT_MAGENTA, LIGHT_CYAN, WHITE};
```