# Supermon+64
By Jim Butterfield et. al.

Supermon64 was a machine-language monitor for the Commodore 64.  In modern parlance, it would be
called a debugger, providing functions including inspecting and altering registers and memory locations;
searching, comparing, and transferring blocks of memory; and assembling and disassembling machine code.

## Background

Supermon is closely associated with [Jim Butterfield](https://en.wikipedia.org/wiki/Jim_Butterfield)
but it had many contributors over the years.  The original version of Supermon for the Commodore PET
contained the following credits:

- Dissassembler by Wozniak/Baum
- Single step by Jim Russo
- Most other stuff (,HAFT) by Bill Seiler
- Tidied & Wrapped by Jim Butterfield


## Usage Instructions

SUPERMON+ is a new version of 'SUPERMON'. The reason for the new
version is to provide identical commands to those of the built-in
monitor of the Commodore 128.

The most visible changes from earlier versions of SUPERMON are:

  - decimal or binary input allowed;
  - disk status and commands (@);
  - looser (easier) syntax.

### Number Conversion 

```
$2000
      $2000
      +8192
      &20000
      %10000000000000
```

In the above example the user has asked for the numeric
equivalents to hexadecimal 2000.  The reply shows the value in hex
($), in decimal (+), in octal (&) and in binary (%).

The user could ask for a number to be converted from any of these
bases by giving the appropriate prefix.

IMPORTANT NOTE -- At any time in the following text, you may enter
any number in any base and conversion will be done for you.

Example:

```
m +4096
```

Will cause a memory display from decimal address 4096. In the
display, the hex address ($1000) will be shown. Similarly,

```
+2048 lda#%10000000
```

Will be converted to assemble: "a $0400 lda #$80"

If you don't give a prefix, the monitor will assume hexadecimal.


### Register Display

```
r

   pc  sr ac xr yr sp
; 0000 01 02 03 04 05
```

Displays the register values saved when SUPERMON+ was entered.
Values may be changed by typing over the display followed by a
return character.

pc - program counter
sr - status register
ac, xr, yr - a, x, and y registers
sp - stack pointer

### Memory Display

```
m 200 209

>0200 4d 20 32 30 30 20 32 30: m 200 20
>0208 39 00 00 04 00 04 00 04: 9.......
```

Display memory from 0200 hex to 0209 hex. Display is in lines of
8, so addresses $200 to $20f are shown. If only one address is
used then 12 lines (96 locations) will be shown. If no address is
given display will go from the last address. Equivalent ASCII
characters are shown in reverse at the right. Values are changed
by typing over the display followed by a return character.


### Exit to miniOS

```
x
```

Return to miniOS Main Menu.

### Simple Assembler

```
a 2000 lda #+18
```

changes  to:

```
a 2000 a9 12    lda #$12
a 2002  ..next instruction
```

In the above example the user started assembly at 2000 hex. The
first instruction was load a register with immediate 18
decimal. In following lines the user need not type the "a" and
address. The simple assembler prompts with the next address. To
exit the assembler type a return after the the address prompt.

Previous lines may be changed by typing over the right hand part.

### Disassembler

```
d 2000 2004

. 2000 a9 12    lda #$12
. 2002 9d 00 80 sta $8000,x
```

Disassembles instructions from 2000 to 2004 hex. If one address
is given, 20 bytes will be disassembled. If no address, 
start from the last used address.  

Code may be reassembled by moving the cursor back and typing over
the right hand part.

This version understands and supports the complete WDC65C02 opcode set. For internal reasons, however, the `BBR[0-7]`, `BBS[0-7]`, `RMB[0-7]` and `SMB[0-7]` opcodes are displayed as `BR[a-h]`, `BS[a-h]`, `RB[a-h]` and `SB[a-h]`, respectively


### Fill Memory

```
f 1000 1100 ff
```

fills the memory from 1000 hex to 1100 hex with the byte ff hex.

### Go (run)

```
g 1000
```

Go to address 1000 hex and begin running code. If no address is
given, the address from the <pc> register is used.

### Jump (subroutine)

```
j 1000
```

Call address 1000 hex and begin running code. Return to the
monitor.

### Hunt Memory 

```
h c000 d000 'read
```

Hunt thru memory from c000 hex to d000 hex for the ascii string
"read" and print the address where it is found. A maximum of
32 characters may be used.

```
h c000 d000 20 d2 ff
```

Hunt memory from c000 hex to d000 hex for the sequence of bytes
20 d2 ff and print the address. A maximum of 32 bytes may be used.

### Transfer Memory 

```
t 1000 1100 5000
```

Transfer memory in the range 1000 hex to 1100 hex and start storing
it at address 5000 hex.  

### Compare Memory

```
c 1000 1100 5000
```

Compare memory in the range 1000 hex to 1100 hex with memory
starting at address 5000 hex.  

### Summary

- `$ , + , & , %`  number conversion
- `g`  go (run)
- `j`  jump  (subroutine)
- `m`  memory display
- `r`  register display
- `x`  exit to miniOS
- `a`  simple assembler
- `d`  disassembler
- `f`  fill memory
- `h`  hunt memory
- `t`  transfer memory
- `c`  compare memory
- `;`  alter registers
- `>`  alter memory

## License

To the best of my knowledge, this software is in the public domain.  I claim no ownership.
