
# JJ65c02 : jimjag's 65c02 Breadboard Computer

Based on [Ben Eaters 6502 Computer](https://eater.net/6502), aka BE6502, this is my own take on his system, following in the long trend of others who have found inspiration and fun due to Ben's work.

There is no way that I could do justice to the insightful education that Ben provides in his videos, and so I won't even try. I encourage you to watch Ben's videos to get the background on his setup and his design choices. Only then will my changes make any sense...

Back? Good! Just jump in.


## What's different?

So starting from Ben's design (as of Sept. 2021), here's a partial list of modifications I've made:

* Different memory map, including bankable RAM
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
   $a800              Pi Pico
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

## Schematics
All schematics are in the `JJ65c02` folder and use `KiCad`.

## Design
The Design Philosophy is based on being as true as possible to the concept of retro computing, while still being practical. We take advantage of modern technology only where it doesn't compromise on the "retro nature" of the system.

For example, as will be noted below, we use a Pi Pico as an I/O support chip. Now the Pico is an extremely powerful microcontroller; one look at the demos associated with the RP2040/2350, especially those around its graphics capability, show that it would be easy and tempting to offload _all_ those functions to the Pico. To me, however, that would be cheating. I wanted the system to be a 6502 which just happens to use a Pi Pico, not a Pi Pico that just happens to have a 6502.

The SBC is based around a WDC65C02, and uses the same pinout as the original 6502, but with the newer 65C02 opcodes. The design also includes a WDC65C22 VIA chip for additional I/O capabilities, and a WDC65C51 ACIA chip for serial support. All these chips support much higher clock speeds than the original 6502, and the system itself runs at 8MHz and at 5Vdc.

As noted, a Pi Pico (actually the Pico 2 at this time), is used to drive the VGA monitor and the PS2 keyboard which serve as the system _console_. PS2 key codes are sent to the 6502 via the VIA chip, but are limited to 7 bits. Since the system is ASCII based, this is not an issue (the reason why we only send 7 bits is due to not having enough GPIO pins on the Pico). The Pico "answers" on the system at address $A200 and uses the full 8 data bits.

Some of the complexity of the design is due to the level mismatch between the 6502 (et.al.) and the Pico, since the Pico itself runs on 3.3Vdc. We could run the 6502 also at 3.3, but that still would not solve all issues. To address this problem, we use line level converters as needed between the 2 voltages. When talking to the Pico, we actually latch the WRITE data, to ensure that the Pico has the time to read and process the data before the DATA bus goes unstable. All communication from the Pico is, as noted, driven by the VIA chip and interupts.

Running at 8Mhz, a standard EEPROM is simply too slow. There are a few ways of handling this, including clock stretching. I opted for using a `SST39SF010` 128K NOR Flash, which behaves like a super fast EEPROM and is programmed the exact same way. The current design however wastes a lot of that memory, since we only use 20K of its 128K capability. ROM banking is a possible future enhancement.

For the RAM, I selected the `AS6C1008` 128K SRAM chip. It is fast enough to easily handling the 8Mhz system clock speed, and provides for extra RAM via banking. The RAM banking itself is determine via the value on `Port B` of the VIA chip, and is user selectable. There are a total of 7 8K banks currently.

A `FT234XD` RS232 chip with USB output is driven by the ACIA chip to provide terminal (or "tty") communication at `19200-8N1` with hardware flow control. Sound output is line level and provided by a standard audio jack. Power is provided by a USBC connector at 5Vdc which is then also converted to 3.3Vdc with the 2 power buses being routed on the board.
