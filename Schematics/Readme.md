
# JJ65c02 : jimjag's 65c02 Breadboard Computer

Based on [Ben Eaters 6502 Computer](https://eater.net/6502), aka BE6502, this is an my own take on his system, following in the long trend of others who have found inspiration and fun due to Ben's work.

There is no way that I could do justice to the insightful education that Ben provides in his videos, and so I won't even try. I encourage you to watch Ben's videos to get the background on his setup and his design choices. Only then will my changes make any sense...

Back? Good! Just jump in.


# What's different?

So starting from Ben's design (as of Sept. 2021), here's a list of modifications I've made:

* Different memory map
* "Directional" keys tied low
* Capability to add 2nd VIA chip
* Support for bootloader
* Dependent on 65c02 chip (not "generic" 6502)

Let's look at each in more detail.

### Memory Map
Ben's design uses a simple but functional address decoder design for his setup. The issue is that it wastes a _lot_ of memory. When all you have to work with is 64k, shared between RAM, ROM and I/O (sure, we could implement banking... maybe in the future), each byte is precious.

For me, I wanted as much RAM as possible, ideally the full 32k, then as much ROM as I could have, and just a little bit of I/O space.

The design I came up with requires the addition of an another chip to Ben's, a 74HC02, and just a single NOR gate from that. But it's worth it. With this new address decoder, we get a much more agreeable memory map:

```
 $0000 - $7fff      RAM: 32k
   $0000 - $00ff      RAM: Zero Page / we use $00-$03
   $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
   $0200 - $021f      RAM: Bootloader set-aside / Page 2
   $0220 - $7fff      RAM: Runnable code area
 $8000 - $8fff      VIA 2: 4K (not currently used)
 $9000 - $9fff      VIA 1: 4K
 $a000 - $ffff      ROM: 24K
```

This allows for a pretty sizable ROM-based loader and even OS, as well as extremely large (for a 6502) RAM-based code.

Because of this, Ben's code will not run unmodified on the JJ65c02, but the changes are minimal. And easy.

### Directional key(board)
I only use 4 buttons on my setup, organized (and coded) as _Left_, _Up_, _Right_ and _Down_. I use this "keyboard" extensively in the bootloader. The other difference is that I use a pull_down_ resistor, to have those buttons tied _low_, instead of being tied _high_, as in Ben's design. Philosophically, I like _active high_ more than _active low_, plus I like the (admittedly pretty much ignorable) power saving.

### VIA2
The breadboard layout, as well as the memory map, allows for a 2nd VIA chip to be added relatively easily. As I investigate adding SPI capability, this will be very useful.

### Bootloader
Of course, the biggest part of bootloader support is, well, the bootloader itself. And, as mentioned, huge kudos to Jan Roesner for his _sixty5o2_ mini-bootloader, which I've hacked away on mercilessly. But the bootloader requires an Aduino Nano as an integral component, so it is both on the breadboard layout as well as included in the schematics.

This also means that, since you can load code into RAM and run it there, you won't be constantly removing the ROM, flashing it, and reinstalling it.

### 65C02
Ben's design, of course, also depends on the 65C02, in fact, the WDC65C02, but his code doesn't use any of the newer opcodes which this later version of the chip provides (like **PHY**). I've decided that as long as we are using the newer chip, we should take not only hardware but software advantage of that. This means, for example, that whatever assembler you use must honor the 65C02 opcode set. For `vasm`, this means you'll need to assemble with `vasm6502_oldstyle -wdc02 -dotdir -Fbin`

