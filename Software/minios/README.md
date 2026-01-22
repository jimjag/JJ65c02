
## JJ65c02: The miniOS

`miniOS` is a minimalist minios/ROM OS for the JJ65c02. Even so, it includes some pretty useful functionality:

1. __Load__ externally assembled __programs__ into RAM via RS232 serial connection.
2. __Run__ programs that were previously loaded into RAM
3__Debug__ the full address space via an integrated __WOZMON__
4__Clean RAM__ for use with non-volatile RAM or during development
5__EhBasic__ BASIC interpreter


## Build and Install the miniOS

minios requires the [ca65 Assembler](https://cc65.github.io) to assemble
and link the required files. For ease of assembly, you'll find a `Makefile`
in the JJ65c02/minios directory. From there simply type `make`:

```
$ make
ca65 -t none --cpu 65c02 -U -I ./include -o objs/minios.o minios.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/sysram.o sysram.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/via.o via.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/lib.o lib.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/acia.o acia.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/tty.o tty.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/console.o console.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/xmodem.o xmodem.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/ehbasic.o ehbasic.s
ca65 -t none --cpu 65c02 -U -I ./include -o objs/wozmon.o wozmon.s
ld65 -C ../jj65c02.cfg -v -Ln minios.lbl -vm -m minios.map -o minios objs/minios.o objs/sysram.o objs/via.o objs/lib.o objs/acia.o objs/tty.o objs/console.o objs/xmodem.o objs/ehbasic.o objs/wozmon.o
Opened 'minios.bin'...
  Dumping 'RAM'
    Writing 'BSS'
Opened 'minios.rom'...
  Dumping 'ROM_FILL'
  Dumping 'IO'
  Dumping 'ROM'
    Writing 'CODE'
    Writing 'RODATA'
    Writing 'RODATA_PA'
    Writing 'VECTORS'
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
`__ZEROPAGE_LAST__` variable in the `minios.map` file. Now if you
follow the below instuctions for assembling and building your own
RAM programs, you don't need to worry about this, because during the
build process `cc65` will handle the allocations and reservations of
zeropage itself, and avoid any collisions. However, if you use some
other method to compile your software, like `vasm`, then you'll need
to take more direct action in both avoiding these zeropage collisions
as well as hardcoding the minios library function addresses into your
code (for now)

### 2. Allocated RAM

The miniOS also occupies some RAM. In the `jj65c02.cfg`
file this is set-aside as `RAM0` and is typically refered to as `SYSRAM`.
Your programs are free to use `BSS`, `HEAP` and `RWDATA` as needed.

## Bootloader, aka Getting Programs into RAM

As mentioned, one of the main functions of miniOS is as a bootloader,
which allows your to download/transfer your own pre-assembled code to
RAM and run it from there. This uses the `W65c51` ACIA chip and the
`MAX232` TTL-Serial converter card on the `JJ65c02` board.

The serial connection is hardcoded as 19200 baud, 8 data bits, 1 stop
bit and no parity. This is commonly refered to as `19200-8N1`. The
current implementation does not support any flow control, so make sure
that whatever serial/terminal connection program you use also has that
configured as such. Good choices for such programs are `picocom` with `sz` for Mac and Linux, or `ZOC` for Mac.
Avoid `MacWise` because it lacks the transfer capability we need.

To initiate the transfer, connect your "tty" machine (the serial/terminal
program) to the `JJ65c02` and power up the board. You should see a Welcome
message on the tty's terminal window. If you don't, check your serial
settings. You do ***not*** need a null modem connection.

If all looks good, using the miniOS menu on the Console, select *Load*.
Confirm that you are ready to
initiate the transfer and hit anykey. At this
point you'll see on the Host terminal the message to *Begin XMODEM transfer.*

From the tty machine chose to **upload** the program and select *XMODEM* as
the transfer protocol. The transfer should take just a few seconds. The
screen will display any errors as well as the number of the blocks being
currently transfered. This may happen so fast that you don't even see
the numbers change; all you may see is the last block number.

Once complete, you will returned to miniOS, at which point you can
chose to *Run* the just downloaded program. Have fun!

NOTE: We use *XMODEM CRC*.

## Assembling your own RAM based programs

Included in the `examples` directory is a simple guide to how
to build and assemble your own programs. You'll notice that you
need to link against the minios object files so that when your
program is assembled and links, it is automatically aware of the
addresses and location of set-aside memory as well as the exported
functions. In the example, you'll also notice that the resultant
file has the `.bin` suffix. That is the file/image to be transfered
to RAM.

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
A pre-built version of the JED file is available in the repo.
