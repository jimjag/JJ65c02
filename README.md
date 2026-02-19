![6502 Rulz](./Images/6502-rulz.png)
6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502 6502
# Introduction

**JJ65c02** is my own personal 6502 Single Board Computer (SBC) interpretation of the noteworthy [Ben Eater 6502 Computer](https://eater.net/6502) setup. In addition to Ben's work, I've used code, concepts and inspiration from a number of people, all acknowledged below in the **Credits** section. The ultimate inspirations are the venerable Apple II and the Atari 800 personal computers

This project contains 3 main sections:

* The actual JJ65c02 breadboard computer ([Schematics](./Schematics))
* [Software](./Software)
  * The `miniOS` OS menu and ROM bootloader
  * `pico-code` : The Pi Pico (RP2040/RP2350) A/V chip (VGA driver and PS/2 keyboard interface)
  * `x65c02` Emulator
* [Documents](./Documents)

Each section has its own Readme.md and folder under this repo.

## Philosophy

More than anything, I want JJ65c02 to have a retro feel. Sure, I'll use modern technology where needed, but I don't want it to be the focus of the project. I want to keep the hardware and software as authentic as possible, while still being able to take advantage of modern tools and techniques where it doesn't impact the feel and spirit of being "retro."

I am therefore putting some restrictions on the project. For example, I am limiting the video output to a 640x480 VGA screen, and the keyboard input to PS/2; graphics are bitmapped. The system is setup to encourage and foster experimentation and innovation.

Basically, I want to keep it simple and fun and recall the early days of 8-bit computing.

## Updates

Keep up to date by following the project on [Hackaday](https://hackaday.io/project/193153-jj65c02) and our [YouTube channel](https://www.youtube.com/playlist?list=PLI32OMXu1rudGl28vJc05QFXHkXWn0A19). Older notes can be found by reading the [History](./HISTORY.md) file, which served as a running log of additions and improvements.

## Pull Requests

If you would like to see any particular feature I would be happy to accept any actual code contributions via Pull Requests, or even Enhancement requests. I am happy to screen, test and merge any valuable PR.

## Contact

You can, of course, contact me via the normal Github development methods, such as Issues, Pull Requests, etc. You can also ping me via [Email](mailto:jimjag@gmail.com) and follow me/DM me on [Twitter](https://twitter.com/jimjag/)

## Credits

* Specific content noted in their respective sections
* All the helpful peeps on reddit r/beneater/
