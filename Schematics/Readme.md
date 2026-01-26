
# JJ65c02 : jimjag's 65c02 Breadboard Computer

Based on [Ben Eaters 6502 Computer](https://eater.net/6502), aka BE6502, this is an my own take on his system, following in the long trend of others who have found inspiration and fun due to Ben's work.

There is no way that I could do justice to the insightful education that Ben provides in his videos, and so I won't even try. I encourage you to watch Ben's videos to get the background on his setup and his design choices. Only then will my changes make any sense...

Back? Good! Just jump in.


# What's different?

So starting from Ben's design (as of Sept. 2021), here's a list of modifications I've made:

* Different memory map
* Console terminal
* Dependent on 65c02 chip (not "generic" 6502)
* Added W65c51 ACIA chip and TTL-serial converter.
* Video/Audio/PS2 Keyboard interface via RP2040/RP2350 (Pi Pico)

Let's look at each in more detail.

### Memory Map
Ben's design uses a simple but functional address decoder design for his setup. The issue is that it wastes a _lot_ of memory. When all you have to work with is 64k, shared between RAM, ROM and I/O, each byte is precious.

For me, I wanted as much RAM as possible, then as much ROM as I could have, and just a little bit of I/O space.

The design I came up with requires the use of the ATF22V10C PLD for decoding. With this new address decoder, we get a much more agreeable memory map:

```
 $0000 - $9fff      RAM: 40k
   $0000 - $00ff      RAM: Zero Page
   $0100 - $01ff      RAM: Stack pointer (sp) / Page 1
   $0200 - $03ff      RAM: Bootloader set-aside / Page 2
   $0400 - $9fff      RAM: Runnable code area
   $8000 - $9fff      RAM: Bankable/swappable 8k segment
 $a000 - $afff      IO: 4k
   $a010 - $a01f      ACIA
   $a020 - $a02f      VIA
   $a100 - $a1ff      RP2040/RP2350
 $b000 - $ffff      ROM: 20k
```

This allows for a pretty sizable ROM-based loader and even OS, as well as extremely large (for a 6502) RAM-based code.

Because of this, Ben's code will not run unmodified on the JJ65c02, but the changes are minimal. And easy.

### 65C02
Ben's design, of course, also uses the 65C02, in fact, the WDC65C02. However his code doesn't use any of the newer opcodes which this later version of the chip provides (like **PHY**). I've decided that as long as we are using the newer chip, we should take not only hardware but software advantage of that. This means, for example, that whatever assembler you use must honor the 65C02 opcode set. For `vasm`, this means you'll need to assemble with `vasm6502_oldstyle -wdc02 -dotdir -Fbin`

### Serial Support
Adding the `W65c51` ACIA chip and the `Max232` TTL-Serial
converter board allows for true RS232 terminal support,
vital for bootloader support.
