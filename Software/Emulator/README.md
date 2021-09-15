# x65c02
This is a fork of a [fork](https://github.com/sci4me/x6502) of the original [x6502](https://github.com/haldean/x6502) project that implements full support for the WDC 65c02 instruction set.

## License
`x6502` is freely available under the original 4-clause BSD license, the full text of which is included in the LICENSE file.

## Usage
### Requirements
`x6502` requires gcc (or compatible), pthreads and ncurses. You will also need a 6502 assembler to "compile" the ASM source code to native 6502 code. The assumption is that you will use `vasm`. See the *examples* directory for info on how to assemble your source.

### Building
Building `x65c02` is super easy. From the top level of the  source, type `./build`. Assuming no issues, you will see the `x65c02` executable.

### Running
`x65c02` takes as its main argument the file of the native 65c02 machine code:

```
    ./x65c02 examples/lcd_test/lcd_test.bin
```

You will then see the emulator window. There are 4 modes (or speeds) of the emulator: STEP (***FKEY5***), SLOW (***FKEY6***), FAST (***FKEY7***) and SPRINT (***FKEY8***). You can switch at will between these speeds. In STEP mode, you can single step using the RETURN/ENTER key as well as the ARROW keys.

The emulator shows a hex dump of memory, and you can move around that visible memory area via the ***{***, ***[***, ***]*** and ***}*** keys.

To exit the emulator, hit the ***ESC*** key.

### Limitations
* The emulator assumes the layout and memory map of the JJ65c02 platform.
* Hardware shifting and scrolling of the LCD display is not yet implemented
* 4-bit LCD display mode is not fully tested
* the "mini keypad" is not yet implemented

## Thanks
Thanks to haldean and all other contributors for the original x6502 project!
