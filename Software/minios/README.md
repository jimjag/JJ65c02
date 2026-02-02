
## JJ65c02: The miniOS

`miniOS` is a minimalist minios/ROM OS for the JJ65c02. Even so, it includes some pretty useful functionality:

1. __Load__ externally assembled __programs__ into RAM via RS232 serial connection.
2. __Run__ programs that were previously loaded into RAM.
3. __Debug__ the full address space via an integrated __WOZMON__
4. __Clean RAM__ for use with non-volatile RAM or during development
5. __EhBasic__ BASIC interpreter
6. __MilliForth__ interpreter


## Build and Install the miniOS

minios requires the [ca65 Assembler](https://cc65.github.io) to assemble
and link the required files. For ease of assembly, you'll find a `Makefile`
in the JJ65c02/minios directory. From there simply type `make`:

```
$ make
ca65 -t none --cpu w65c02 -U -I ./include -o objs/minios.o minios.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/sysram.o sysram.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/via.o via.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/lib.o lib.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/acia.o acia.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/tty.o tty.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/console.o console.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/xmodem.o xmodem.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/ehbasic.o ehbasic.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/wozmon.o wozmon.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/intel-hex.o intel-hex.s
ca65 -t none --cpu w65c02 -U -I ./include -o objs/milliforth.o milliforth.s
ld65 -C ./jj65c02.cfg -v -Ln minios.lbl -vm -m minios.map -o minios objs/minios.o objs/sysram.o objs/via.o objs/lib.o objs/acia.o objs/tty.o objs/console.o objs/xmodem.o objs/ehbasic.o objs/wozmon.o objs/intel-hex.o objs/milliforth.o
Opened `minios.bin'...
  Dumping 'RAM'
    Writing 'BSS'
Opened `minios.rom'...
  Dumping 'ROM_FILL'
  Dumping 'IO'
  Dumping 'ROM'
    Writing 'CODE'
    Writing 'RODATA'
    Writing 'RODATA_PA'
    Writing 'IOVECTORS'
    Writing 'VECTORS'
  Dumping 'ROM_FILL2'
touch minios
ar65 r minios.lib objs/minios.o objs/sysram.o objs/via.o objs/lib.o objs/acia.o objs/tty.o objs/console.o objs/xmodem.o objs/ehbasic.o objs/wozmon.o objs/intel-hex.o objs/milliforth.o
#rm -f minios.bin
```

Burn the ROM image (`minios.rom`)onto the EEPROM using your TL866 programmer in conjunction with minipro (Linux, Mac) or the respective Windows GUI tool provided by XG.

```
minipro -p AT28C256 -w ./minios.rom
```

Later versions of the board use the SSL39SF010 RAM chip as a ROM (for performance reasons); to burn the image to that chip, perform the following:

```
minipro -p "SST39SF010A" -w ./minios.rom
```

The `minios.lbl` file is the resultant symbol list with the hexadecimal
addresses for all routines and labels. If you scroll down to the bottom,
you will find the addresses of every routine that the minios exports
for program use. There is also a more detailed `minios.map` file that provides even
more in depth info. We will talk more about this when we discuss
building and loading RAM-based programs.

## Important to know - Allocated Resources

### 1. Allocated Zero Page Locations

The miniOS needs to use some Zero Page locations, so expect trouble if you
overwrite / use them from within your own programs. Currently, we use
locations `$00-$DC`, which can be confirmed via looking at the
`__ZP_LAST__` variable in the `minios.map` file. Now if you
follow the below instuctions for assembling and building your own
RAM programs, you don't need to worry about this, because during the
build process `cc65` will handle the allocations and reservations of
zeropage itself, and avoid any collisions. However, if you use some
other method to compile your software, like `vasm`, then you'll need
to take more direct action in both avoiding these zeropage collisions
as well as hardcoding the minios library function addresses into your
code (for now).

To help with this, we also provide a set of `start` and `end` variables for each module that allocates zeropage memory:
```
SYSMEM_ZP_start
SYSMEM_ZP_end
XMODEM_ZP_start
XMODEM_ZP_end
BASIC_ZP_start
BASIC_ZP_end
```
Without a doubt, EhBASIC is the largest consumer of zeropage memory. However, you can re-use this space by starting your zeropage allocations at `BASIC_ZP_start` and setting the `EHBASIC_ZP_CORRUPTED_FLAG` in the `MINIOS_STATUS` register. This will force the EhBASIC interpreter to clean-up the corrupted memory block via a COLD start.

### 2. Allocated RAM

The miniOS also occupies some RAM. In the `jj65c02.cfg`
file this is set-aside as `RAM0` and is typically refered to as `SYSRAM`.
Your programs are free to use `PROG`, `BSS`, `HEAP` and `RWDATA` as needed. (_*NOTE*_: `CODE` is ROM space)

## Bootloader, aka Getting Programs into RAM

As mentioned, one of the main functions of miniOS is as a bootloader,
which allows you to download/transfer your own pre-assembled code to
RAM and run it from there. This uses the `W65c51` ACIA chip and the
`MAX232` TTL-Serial converter card on the `JJ65c02` board.

The serial connection is hardcoded as 19200 baud, 8 data bits, 1 stop
bit, no parity with H/W flow control. This is commonly refered to as `19200-8N1`. Good choices for rs232/vt100 terminals  are `picocom` with `sz` for Mac and Linux, or `ZOC` for Mac.
`MacWise` is a good choice, but it lacks the XMODEM transfer capability.

To transfer binary code to the board, we offer 2 options: The XMODEM protocol or the Intel HEX format. Both are selected via the Main Menu.

### XMODEM

To initiate the transfer, connect your "tty" machine (the serial/terminal
program) to the `JJ65c02` and power up the board. You should see a Welcome
message on the tty's terminal window. If you don't, check your serial
settings. You do ***not*** need a null modem connection.

If all looks good, using the miniOS menu on the Console, select *Load*.
Confirm that you are ready to
initiate the transfer and hit the `l` or `L` key. At this
point you'll see on the Host terminal the message to *Begin XMODEM transfer.*

From the tty machine chose to **upload** the program and select *XMODEM* as
the transfer protocol. The transfer should take just a few seconds. The
screen will display any errors as well as the number of the blocks being
currently transferred. This may happen so fast that you don't even see
the numbers change; all you may see is the last block number.

Once complete, you will be returned to miniOS, at which point you can
chose to *Run* the just downloaded program. Have fun!

NOTE: We use *XMODEM CRC*.

### Intel HEX
For the Intel HEX format, you will need to use the capabilities of your host terminal program to transfer the file. Even though we use hardware flow control, it is still possible that the transfer may be too fast for the 6502 to keep up. A common fix is to add some delay at the end of each line of the file; this is done via a setting in the host terminal program.

## Assembling your own RAM based programs

Included in the `examples` directory is a simple guide to how
to build and assemble your own programs. You'll notice that if your program uses any of the miniOS features, you'll
need to link against the miniOS object library so that when your
program is assembled and links, it is automatically aware of the
addresses and location of set-aside memory as well as the exported
functions. In the example, you'll also notice that the resultant
file has the `.bin` suffix. That is the file/image to be transfered
to RAM.

To make it easier, since most of the time 3rd party programs just need to know how to read and write a character, we have an IO Vector jump table, which assures non-variable access to those functions via a `jmp ($fff0)` (for example) instruction. Check out the values for the various IOV* labels in the `minios.lbl` file.

## Build and Install the PLD Image

We use the `ATF22V10C` PLD to handle our address logic. First you'll
need to use `WinCUPL` to compile the `JJ65C02.PLD` file to the `.jed`
image format expected by the chip. Once you do that, copy over the
image to the chip using `minipro`

```
minipro -p ATF22V10C -w ./JJ65C02.jed
```
or
```
minipro -p ATF22V10CQZ -w ./JJ65C02.jed
```
A pre-built version of the `JED` file is available in the repo. We've also provided a copy of `WinCUPL` as well.

## RAM Banking
Memory space between 0x8000 and 0x9FFF is reserved for RAM Banking.
This area is used for dynamic memory allocation and can be banked
between two banks, allowing more actual RAM to be used than is directly addressable. There are 7 banks actually available, and they are set and selected by using the `LIB_setrambank` function, where the value of the `A` register is used to select the bank number to be active. Using this function changes the bit pattern on `Port B` of the VIA chip which itself is then used to modify the address lines to the RAM chip. Increasing the number and size of the RAM banks is a possible future enhancement.

## EhBASIC
EhBASIC is a fast and powerful BASIC interpreter for the 6502 microprocessor. EhBASIC is a great way to learn about computer programming but is also sophisticated enough to be used for serious projects. EhBASIC takes full advantage of the capabilities of the Pi Pico support chip (see [README.md](pico-code/README.md)) allowing for retro graphics and sound.

A manual for EhBASIC is available in the `Documents` directory ([here](../../Documents/EhBASIC-manual.pdf)).

Our version of EhBASIC has been as follows:
- Support for lower and upper case characters (BASIC commands are automatically converted to upper case)
- Added `CSTR$()`: `CSTR$(19)` returns "19" not " 19" ala `STR$()` (not the space character in the 2nd string)
- Added the `EXIT` command to exit the program and return to the miniOS menu
- Added the `LOAD` and `SAVE` commands to load and save programs between a host computer via the serial connection. The transfer protocol is XMODEM.
- Added the `TTY` command to switch user I/O between the console (PS2 keyboard and VGA monitor) and the serial connection.

#### Loading and Saving BASIC Programs
As noted above, the `LOAD` and `SAVE` commands allow you to load and save programs to a host computer via the serial connection. However, these are the _binary_ versions of the BASIC programs, and not the typical source text format.

For the most part, people will want to load and save the actual text itself, and the mentioned `TTY` command is there to make it easier. To Save a program in its text format, switch to TTY mode and then, from the host terminal, type `LIST`. Capture this text to a file on the host computer. To "load" a BASIC program, again switch to TTY mode and paste or "send" the file containing the BASIC program directly to EhBASIC; it will appear to BASIC as if you were typing it in directly (think of it as a "paste" command). You may need to add some delays or some send-throttling by the host terminal program to avoid overloading the serial connection.

## WOZMON
Wozmon (or Woz Monitor) is a tiny but powerful ~256-byte monitor program written by the legendary Steve Wozniak for the original Apple-1 computer in 1976.
It provides a command-line interface for debugging programs running on the miniOS system. WOZMON allows you to set breakpoints, step through code, and inspect variables, making it a valuable tool for debugging and testing your programs. A small manual is included in the `Documents` directory.

Our version of WOZMON has been updated to support both UPPER and lower case characters, and the command `Q` to quit the program and return to the miniOS menu.

## Milliforth
Milliforth is a simple Forth interpreter written in assembly language for the 6502 microprocessor.

## Supermon+
Port of the famous Supermon monitor, originally written for the Commodore PET and then the C64.

A simple user guide for supermon+ is available in the Documents directory ([here](../../Documents/supermon.md)).
