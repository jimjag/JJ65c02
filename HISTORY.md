# History and Changelog for the JJ65c02 Project

## Intro

This document is mostly for my own personal note taking,
but hopefully it will also be useful to anyone who
comes across this project (I don't expect a lot of
traffic... :/ ). All code and examples are available under
permissive Open Source licenses, so please don't hesitate
to use, and re-use, what you need.

## The Historical Documents

### Sept 21, 2021

Not a lot of good info about the 20x4 LED Displays and what
there is is kind of conflicting. But finally figured out how
to set the cursor to the row and column I need. Started adjusting
the code and libraries to both use the 20x4 display but also
be backwards compatible with the 16x2.

For Up/Down scrolling right now I use large blocks of text,
already fixed in a 20 column format, padded with spaces. This
makes the code and implementation easier, but is quite wasteful.
Thinking about using pointers, but is it worth the time and
effort?

Got the MAX232 in the mail so went ahead and soldered the
pins in. Still need to wire it in but we're making progress!

![max232](./Images/max232.png)

--

### Sept 18, 2021

I decided I needed a better way to load programs into
RAM. The sixty502 bootloader does well enough, but
the dependency on a Nano seems limiting to me. Bite
the bullet and decide to instead use the 6551 ACIA
chip for serial I/O. This will eventually also allow
me to connect to the system via a serial `tty` interface.
Although old, and somewhat limited, common knowledge seem
to be to use the old Rockwell R6551, instead of the newer
65c51, because the latter has some nasty timing bugs.

I've seen some people add in USB and VGA to their 6502
projects. This seems like overkill. The whole allure, for
me at least, is the old-school aspect of the project.
Another reason to drop the Nano. Will keep the
mini-keyboard and the LCD display though: will likely
use that as the main menu and as supplemental IO.

With both the VIA (65c22) and the ACIA chip (R6551), I think that
simply tying both to the `IRQ` line will likely work, but isn't
ideal. Since the R6551 is an open drain design, I use a 4.7K pullup
on its IRQ line and feed it and the 65c22 IRQ  into a 74HC08 `AND` gate
and use that output to drive the `IRQ` input to the 6502.

Looked around for a TTL-serial converter. Found one on
[Digi-key](https://www.digikey.com/en/products/detail/mikroelektronika/MIKROE-222/4495513), so placed an order.

In the meantime, pulled out the Nano and started wiring
up the 6551. Times like this one really appreciates breadboards.

--

### Sept 16, 2021

As with others, found that `vasm`, while a great assembler,
has its limitations. Needed something a bit more
finely suited to larger 6502 assembler projects. Started
migrating code to `cc65`.

`cc65` requires a `cfg` file, which tells the linker
where to put stuff. This looks like a good inital version:

```
MEMORY
 {
   ZP:   start = $0,    size = $100,  type = rw, define = yes;
   RAM:  start = $0230, size = $7dd0, type = rw, define = yes;
   VIA2: start = $8000, size = $1000, type = rw, define = yes, fill = yes, fillval = $ea, file = %O;
   VIA1: start = $9000, size = $1000, type = rw, define = yes, fill = yes, fillval = $ea, file = %O;
   ROM:  start = $a000, size = $6000, type = ro, define = yes, fill = yes, fillval = $ea, file = %O;
 }

 SEGMENTS {
   ZEROPAGE:  load = ZP,  type = zp,  define = yes;
   DATA:      load = ROM, type = rw,  define = yes, run = RAM, optional = yes;
   BSS:       load = RAM, type = bss, define = yes, optional = yes;
   HEAP:      load = RAM, type = bss, define = yes, optional = yes;
   CODE:      load = ROM, type = ro,  define = yes,  start = $a000;
   RODATA:    load = ROM, type = ro,  define = yes;
   ISR:       load = ROM, type = ro,  start = $ffc0;
   VECTORS:   load = ROM, type = ro,  start = $fffa;
 }
```
--

### Sept 13, 2021

Found a pretty cool x6502 emulator. Folded it into the overall project
and made the modifications required for my setup. Added actual
user documents to the project too.

Starting thinking about switching the 16x2 LCD display with
a 20x4. The extra space will come in handy.

--

### Sept 8, 2021

Decide to put everything up on [Github](https://github.com/jimjag/JJ65c02).

--

### Sept 3, 2021

Decided that I really need to start generating schematics. I don't
ever expect to go the PCB route, but will likely end
up wire-wrapping at some point. Plus, it's good to actually
document what connects to what, etc. Chose KiCad.

![schematics](./Images/phase2-schematic.jpg)
--

### Sept 1, 2021

Found Jan Roesner's [sixty502](https://github.com/janroesner/sixty5o2) project, which uses an Arduino and bootloader to load programs into RAM. So
I [fork](https://github.com/jimjag/sixty5o2) the project and start
modifying it for my newly-named JJ65c02 project.

--

### ~Aug 30, 2021

First step on some improvements. First of all, Ben's memory map isn't ideal
(he admits as much) and I wanted to allocate as much space
for RAM as possible. Came up with an address decoder which only
requires 1 additional chip, but allows for 32k RAM, 24k ROM
and 2 4K VIA/IO address blocks. Those IO blocks are still
huge for my needs, but right now, they are good enough.

--

### Aug 26, 2021

While playing around on Youtube, I came across the various
[Ben Eaters 6502 Computer](https://eater.net/6502) videos
and addition to being impressed with his style, skill and
knowledge, I also became intrigued. Back as an undergrad
at JHU, one of my courses was in microprocessor architecture,
and a project was a 6502 breadboard setup. I can't recall
the full specifics; I am pretty sure that other than RAM
and ROM (maybe 8k of each), there were no other 6502-family
chips used in the project. Just some logic gates, switches
and LEDs. Still, I had a blast with the project and took my
time to plan every detail, both from a hardware placement
standpoint to software design. When all was done, I was
extremely proud of what I did and was also shocked when
the Prof was just as impressed. He kept my wirewrap (no
pushboards back then) and code as a prototype example for
display in the course.

My first computer was, as with many, an Apple ][, which
was also 6502 based, and I spent many, many, many hours
coding on that, in both assembly and Basic. The skills
I learned doing assembly language programming are still
valuable to this day.

So when I saw Ben's videos, I was hooked.

I ordered Ben's kit (I always like supporting people)
and jumped into making my own version. As can be seen, it's pretty much a 1-1 match of Ben's version.
![photo](./Images/phase1.jpg)