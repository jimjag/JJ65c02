# The Software

There are 3 main codebases included:

* The bootloader
* The Arduino Nano Receiver
* The host Sender

The bootloader itself is standalone, which means that it provides limited functionality all on its own. But the main function of the bootloader is to be able to transfer your "compiled" 6502 code to the JJ65c02's RAM, and for this you need the other 2 programs

The way this works is that you "send" the object file to the serial port that the Arduino Nano is connected to on your host computer (mac, Windows, whatever). This is the _Sender_. On the Arduino, you run a sketch which listens on that serial port for the data, and then works with the JJ65c02 board to copy it to RAM. This is the _Receiver_.

## JJ65c02: The bootloader

`bootloader.asm` is a minimalist bootloader/ROM OS for the JJ65c02. Even so, it includes some pretty useful functionality:

1. __Load__ externally assembled __programs__ into RAM via serial connection to Arduino Nano
2. __Run__ programs that were previously loaded into RAM
3. __Load & Run__ programs in one go
4. __Debug__ the full address space via an integrated __hex monitor__ (currently read only)
5. __Clean RAM__ for use with non-volatile RAM or during development
6. __Adjust__ the internal expectation of the external __clock speed__, from 1Mhz to 14Mhz

The bootloader also provides some helper library functions to handle delays, driving the __LCD__ display, and reading the __mini keyboard__.


### Software Requirements

The following software components are must have's:

- Arduino IDE to be found [here](https://www.arduino.cc/en/main/software)
- The [VASM Assembler](http://sun.hasenbraten.de/vasm/) to build for the 6502
- Node.js 8+ to be able to use the serial program loading functionality via the Arduino

### Install the bootloader

Assemble the bootloader:

```
vasm6502_oldstyle -wdc02 -Fbin -dotdir -L bootloader.lst -o bootloader.out bootloader.asm
```

Burn it (`bootloader.out`)onto the EEPROM using your TL866 programmer in conjunction with minipro (Linux, Mac) or the respective Windows GUI tool provided by XG.

The `bootloader.lst` file is the resultant symbol list with the hexadecimal addresses for all routines and labels. If you scroll down to the bottom, you will find the addresses of every routine that the bootloader exports for program use. Now you can use these addresses in a new program, that you assemble and upload to RAM.

## Arduino: Receiver

- Load `Receiver.ino` into your Arduino IDE.
- Open the IDE's package library and search and install the `Base64` package by Arturo Guadalupi v0.0.1 also to be found [here](https://github.com/agdl/Base64)
- Compile the source
- Upload the program to your Arduino

## Host: Sender (node.js)

The sender code is written in node, so you'll need that.

- Install the necessary npm support packages via:

```
npm install
```
or
```
yarn
```
- Adjust the `tty` setting in `.sender_config.json` to match the device file which represents your connected Arduino
- **DO NOT** adjust any other value in there, as it will render the serial link unstable

## Usage

#### Arduino Port Setup

Before you can upload a program to the 6502 through the Arduino, you need make sure that the Arduino Nano is connected as indicated in the Schematics. If instead you simply want to jumper the Nano to the board, you can do that too.

- You need 8 jumper wires connecting the digital output ports of the Arduino with the PORTB of the VIA 6522 (See table 1 below)
- You need 1 jumper wire connecting one digital output port of the Arduino with the IRQ line of the 6502 (See table 2 below)
- You need 1 jumper wire connecting one of the `GND` pins of the Arduino with common ground of your 6502 breadboard

**Table 1: Port Setup VIA 6522**
 
| Arduino | VIA 6522 |
|---------|----------|
|   D5    |   10     |
|   D6    |   11     |
|   D7    |   12     |
|   D8    |   13     |
|   D9    |   14     |
|   D10   |   15     |
|   D11   |   16     |
|   D12   |   17     |

If unsure, look up the pin setup of the VIA in the `Datasheets` folder.

**Table 2: Port Setup 6502**
 
| Arduino |     6502    |
|---------|-------------|
|   D13   |   4 (IRQB)  |

The pin setup of the 6502 can also be found in the `Datasheets` folder.

**Important:** Make sure, you still have the IRQB pin (PIN 4) of the 6502 tied high via a 1k Ohm resistor as per the design. The jumper cable to pin D13 of the Arduino just pulls the pin low in short pulses. The line needs to be normal _high_.

#### Uploading a Program

You can now write a program in 65C02 assembly language and assemble it like so:

```
vasm6502_oldstyle -wdc02 -Fbin -dotdir -o /examples/hello_world.out /examples/hello_world.asm
```

**Important:** Since your programs now target RAM instead of ROM your program needs to have a different entry vector specified:

```
    .org $0220
```

To upload and run your program onto the JJ65c02, first power up the machine, and reset it. Using the keyboard, navigate to `Load` using the _Up_ and _Down_ keys in the main menu. To start the uploading process hit the _Right_ key which acts as `Enter` in most cases.

Now you can upload your program using the Sender.js CLI tool like so:

```
node Sender.js /examples/hello_world.out
```

The upload process will inform you when it's done. The bootloader automatically switches back into the main menu after the upload finished.

Should you encounter any errors during upload, check the `tty` setting in `.sender_config.json` and adjust it to your Arduinos device port. In addition you can lower the transfer speed to values to 4800, 2400 or 1200 baud. Don't use values above 9600 baud, they won't work.

Navigate to the menu entry `Run` and hit the _Right_ key to run your program.

**Note:** You can also use `Load & Run` to streamline the process during debugging.

**Also note:** Resetting your 6502 **DOES NOT** erase the RAM. So you can reset any time, and still `Run` your program afterwards.

**And note:** The `Sender.js` accepts two commandline parameters. If you want, you can also specify your Arduino port manually, whithout having to hardwire it in the `.sender_config.json` like so:

```
node Sender.js /examples/hello_world.out /dev/path_to_arduino_port
```

## Using the Monitor

The **hex monitor** is very useful during development and debugging. It lets you inspect the whole address space, RAM and ROM. you can navigate using the _UP_ and _DOWN_ keys. The _RIGHT_ key performs a bigger jump in time and space and the _LEFT_ key returns you to the main menu. The monitor is currently read only and the keyboard debouncing is far from being good. But it works.

## Important to know - Allocated Resources

### 1. Allocated Zero Page Locations

The bootloader needs to use some Zero Page locations: `$00 - $03`. Expect trouble if you overwrite / use them from within your own programs.

### 2. Allocated RAM

The bootloader also occupies some RAM. Most of the allocated block is used as VideoRam to talk to the LCD. Another few RAM bytes are used by the bootloader itself.

**However, don't use RAM from `$0200 - $021f`. Expect problems if you do so.**

### 3. Interrupt Service Routine - ISR

The Interrupt Service Routine (ISR) implemented at the end of available ROM realizes the serial loading. The way it works is quite simple. As soon as the Arduino set up all 8 bit of a byte at the data ports, it pulls the interrupt pin of the 6502 low for 30 microseconds. This triggers the 6502 to halt the current program, put all registers onto the stack and execute any routine who's starting address can be found in the Interrupt Vector Address (`$fffe-$ffff`) - the ISR. This routine reads the byte, writes it into the RAM, increases the address pointer for the next byte to come and informs the main program that data is still flowing. Consult the source for further details, it's quite straight forward.

## Shortcomings

- The loader is slow. Quite slow. Even though 9600 baud as choosen transfer speed is not too bad, there are some significant idle timeouts implemented, to make the data transfer work reliably. You'll find it in `Receiver.ino`, the `Sender.js` does not have any timeouts left other than the necessary but unproblematic connection timeout once at the beginning. The worst is the timeout which allows to reliably read the UART buffer of the Arduino. When reduced, the whole data transfer becomes unreliable.
Happy to accept PR's with improvement here. On the other hands, it's not that we transfer Gigabytes of data here ... not even Megabytes, so the current speed might suffice.

## Known Problems

Despite the fact that the bootloader and all of it's components are quite stable, there are some problems, which are to be found via a #TODO in the source.

Worth mentioning are the following:

- Simple delay-based EOF detection during data transfer - if more than a few packages fail to transfer and need to be repeated by the sender, it might happen, that the `BOOTLOADER__program_ram` routine interprets this as EOF, since no data is coming in no more. This problem can not be "easily" solved, since there are no control characters that can be transferred between the Arduino and the 6522. There are solutions, but first there needs to be a problem.
- sub optimal register preservation - the (reduced) 6502 instruction set makes it hard to preserve all registers w/o wasting RAM locations. The current implementation does put focus on register preservation only where explicitly needed.
- the ISR is currently static, so it can handle only interrupt requests which come from the Arduino. If you want to use other interrupts of the 6522 or software interrupts, you need to implement a priorization mechanism as well as a branching in the ISR, since (to my knowledge) there is only one interrupt vector, the 6502 can handle.
