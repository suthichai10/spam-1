# simplecpu

Simple CPU simulation built using Logism Evolution and including and Google Sheets based assembler

See also the accompanying [Simple CPU Assembler](https://docs.google.com/spreadsheets/d/1lYyPqYNF1dGDRP2n3ablaqkgZuxJ9x6T-ylut_nT1p4/edit?usp=sharing) built using Google Sheets.

## Motivation

A bit of fun!

I started working life in 1986 as a hardware engineer but quickly switched to software. As a teenager I'dbeen fascinated with
discrete electronics and then later on with integrated circuits and build many little home projects; nothing too exciting as we didn't have the resources (ie ££) back then.

Recently, like many other folk, I came across [Ben Eater's series of YT videos](https://www.youtube.com/watch?v=HyznrdDSSGM&list=PLowKtXNTBypGqImE405J2565dvjafglHU) and also those of quite a few others that inspired me to have a go at building my
own CPU. Back in 1980 even the relatively few parts needed would probably have been beyond my means, but not anymore !!

However, back in the 1980's  I would have been building more or less blind. I still don't have an oscilloscope but what I do have is a simulator.   
Having spent the last few weeks getting to know [Logisim Evolution](https://github.com/reds-heig/logisim-evolution)  and having hours trying to figure out the fine details of my simulated processor
it's clear that if I had attempted to build a CPU back in 1980 then I'd have fallen flat on my face.
It's been a great learning experience, if frustrating at times.

So I've decided to build an 8 bit CPU for myself, for the sheer joy and nostalgia, sweat and tears.

# Objectives

- I want to be able to run at least the typical demo programs like Fibonacci 
- It will have an assembly langauge and assembler
- I want to simulate it first
- I want to build it physically, or a more likely a  derivative
- Attach some output device - eg a UART / tty that respects VT codes   
- I might port or other higher level language to it for curiosity (which one and where to start?)
- I would like to extend it to play some kind of basic game (tbd)

:star: But I wanted to do things a little differently to some of the other efforts on the internet! I want the assembler and any other code I write to 
to be more readily accessible and instantly usable to others (like you) without installing python or perl or whatever first, so I've written the assembler in google sheets! 

# Architecture

- Single bus
- 8 bits data
- 8 bits address
- 16 bit instruction
- 8 bit ALU - add/subtract
- Separate RAM and ROM (for no particular reason - could have been all RAM)
- One instruction per clock cycle (effectively "Fetch/Decode" on falling edge of clock and "Execute" on rising edge of clock)
- Uses microcode instructions, not "microcoded" instructions, ie each instruction is at microcode level and directly enables the necessary control lines.
 Therefore control logic is trivial so unlike some other systems there is not EEPROM for control decoding and there is no Instruction Register either.
- Registers
  - A and B general purpose registers - These are not symmetrical as "A" always comes first in arithmetic ie "A+B" and "A-B"
  - Memory address register
  - Program counter
  - Flags register - Zero,  Carry, Equals (ie A=B)
  - Display register
- Instructions for load any register with any other register, jump and branch, addition and subtraction - there's a surprising lot you can do with this and even without complex microcoded instructions

![Block diagram](docs/blocks.png)

# Run the simulator

Works in Window 10 at least. I haven't tried running Logism yet on Linux but it's all Java. 

- Clone the git repository
- Change directory to _./logism_ subdirectory
- Run the logism evolution jar in the repo's _logism/_ subdirectory (or download the latest version from [the author's git repo](https://github.com/reds-heig/logisim-evolution)) 
- Load the circuit from the same directory
- Start the simulator. Menu -> Simulator -> Ticks Enabled

# Change the Assembly Program

- Open the [Simple CPU Assembler](https://docs.google.com/spreadsheets/d/1lYyPqYNF1dGDRP2n3ablaqkgZuxJ9x6T-ylut_nT1p4/edit?usp=sharing) built using Google Sheets
- Goto, or duplicate, the Assemble Demo Tab 
- Make changes to the Assembler
- Copy the ROM bytes from the cells on the right of that same page into your clipboard
- Place the data into the files on disk and then load into the ROMS or paste direct into the ROM's in Logism
    - Unfortunately the clipboard will have quotes in it so edit the clipboard in a test editor to remove the two quote.
    - If you are not writing the clipboard into a "rom file" the remove the "v2.0 header" from the clipboard contents too
 - Start the simulator as above

## Program Storage

Program is stored in ROM and is, wastefully, a fixed 16 bit instruction, organised over a pair of ROMs, one each for for high and low byte of the instruction.
The high byte defines the operation and the low byte is used only for constants (at present) which is why I said it's wasteful.
 
### High ROM byte
The high order bytes is organised into three parts, identifying the ALU operation and the input and output devices.

![High Byte](docs/op-hi-byte.png)

- 2 "ALU" bits configure the ALU operation - only add/subtract right now.
- 3 "OUT" bits select one device (0-7) that will be enabled to output onto the bus.
- 3 "IN" bits select the device who's input register will be enabled to latch the value on the bus.
  
Therefore with this design I can have at most 8 "input" devices and 8 "output" devices (some ideas on improving this are below).

### Low ROM byte

This low order ROM is used only for program constants at present; this is rather wasteful (see below). 

### Example Program

```
:start	    LD A,#0
            DISP A
            LD B, #1
            DISP B

:loopUp     ADD A
            BCS :backDown
            DISP B
            ADD B
            BCS :backDown
            DISP B
            JMP :loopUp
	
:backDown   LD A,#e9
            LD B,#90
            LD MAR, #0
            DISP B
:loopDown   SUB A
            BZS :start
            DISP A
            LD RAM, A
            LD A, B
            LD B, RAM
            JMP :loopDown                                                                                                                                                                                                
```

# Progress

I've spent a couple of weeks building the sim for a CPU. It's 8 bit and based on ideas form various places but kind of grew by itself with a little planning.
It's a fairly primitive one in that there is no opcode vs microcode, or to put it another way every instruction is microcode. Also, this approach meant I never
got around to needing to add an instruction register.

:star: The complete set of instruction and argument combinations at [here](docs/instructions.txt)

- The simulator works
- The assembler and decoder work (see below) and I'm happy with the way the software turned out
- My Fib program counts up and down in a loop

So all good !!


# Documentation

## Simulated in Logism Evolution 

![Logisim-animated](docs/logisim-animation.gif)

## :thumbsup: I've built an assembly language for it and also an assembler.

I've built the assembler in Google Sheets, which I think might be a pretty unique approach (let me know).

![Assembler](docs/sheets-assembler.png) 
    
## Todo

Keep going .

## Try my CPU and Assembler for yourself

You can then download the Logism jar plus my circuit files and the rom images and run it. You can play with the assembler and 
put your own programs into the ROMs for a giggle.  
 
There is also an "instruction decoder" page which will decode the assembly program and show you which control lines are enabled for each instruction in the program.

![Decoder](docs/decoder.png)




# Improvements

## Better use of ROM

My use of a fixed 16 bit instruction word is quite wasteful. Unless I'm dealing with a constant then the second ROM is entirely unused.
One solution is a variable width 8 bit instruction where most instructions are 8 bit, but when ROM_out is enabled in the first byte 
then the control logic looks for the operand in the subsequent byte.

## Immediate arithmetic

At present I can only interact with the ALU via the A/B registers. This means I can't do arithmetic
 on a value from the ROM or RAM without wiping one of those two registers. I can of course mux the data bus into the
 ALU, however, a problem with getting a value from RAM into the ALU 
  and capturing the result of the arithmetic is that I only have one bus and I can't have both the RAM active out on the BUS
 whilst also having the ALU active out. A solution might be to put a register on the output of the ALU so that I can do the arithmetic in
 one micro-instruction and then emit the result in the next micro-instruction. 
 
## CALL and RET

I'd like to demonstrate a call to a subroutine and a return from that call. 

All my instructions are micro-instructions and doing a "CALL" requires at least two micro-instructions, one to push the PC into RAM then another to move the PC to 
the new location. So I don't think I have the luxury of being able to introduce an "CALL" op code in the hardware. However the assembler could certainly expand a 
"CALL :label" into something like this (note: typically one places a stack at the end of memory and works backwards through RAM as items are pushed to the sta ck- I've used that approach below.)
 
```
# store PC into the stack
    MAR=RAM[#stackpointer_location]     #set the MAR to point at the current location of the SP
    RAM=PC

# decrement stack pointer
    A=RAM[#stackpointer_location]
    B=1
    SUB A
    RAM[#stackpointer_location]=A

# Jump to subroutine
    PC=#subroutine_location

```

And "RET" could be expanded to.  


```
# increment stack pointer
    A=RAM[#stackpointer_location]
    B=1
    ADD A
    RAM[#stackpointer_location]=A

# retrieve stack pointer into the PC
    MAR=RAM[#stackpointer_location]     #set the MAR to point at the current location of the SP
    PC=RAM
```

If passing args to the subroutine then they would also need to go into RAM and I could add a "PUSH" instruction to the Assembler to support this.

Where other processors have high level instruction built into the hardware and the control logic decodes this into micro-instructions,
 in my case the high level instructions would be merely a feature of the assembler and the assembler would "compile" these into the 
 micro-instructions that my CPU uses.
 
On a more traditional CPU a binary program (eg ".exe" or ELF executable) could work on multiple CPU types with different underlying CPU hardware and micro-instructions
as long as the CPU's all support the same set of "high level" Opcodes. The CPU's control logic takes care of translating the high level opcodes into the internal 
 micro-instruction language of the CPU. However, in my case that translation is happening in the assembler and if there is a change to the hardware
 then this renders all programs inoperable; there is no abstraction to save me.
 Of course I can just recompile the assembler to resolve the issue, however, this goes to highlight the power of high level op codes and embedded micro-code where no 
 recompilation is necessary (eg Intel vs AMD).  

Using the assembler to compile high level opcodes I can add things like ..

```
CALL :subroutine
RET 
PUSH <some register>
POP <some register>
INC <come register>
DEC <come register>
```           

## Save a control line by memory mapping the Display device

The display register steals a control line. In principal this could just be mapped to a specific memory location which would free up the control line
for something useful, for instance doubling the number if Input or Output devices on the bus. This might for instance allow me to implement Branch on Equals.
Though to be fair I have two selector lines going into the ALU and use only one of them at present so I could co-opt that if I wanted.

## Add more ALU operations

- Add logical operations.
- Add a shift left/right to the ALU (same as multiply by 2, div by 2)
- Add BCD operations

This is a biggie.

Having no logical operations at all is far from ideal.

But this would mean feeding at least three selector lines into it, which could give me 8 potential operations rather than the two I have currently implemented. 
However, I am already short on control lines so this isn't too appealing. If I switched to variable length instructions or added a register to 
the output of the ALU then perhaps I could get a lot more flexibility. Dunno.

Alternatively I could do something like add an 8 bit register for the ALU config, eg giving me 256 possible ALU operations. Or I could organise the 8 bit register 
 as 4 bits for multiplexing the inputs and output of the ALU, and 4 bits for the selection of the ALU operation. If I multiplex the inputs and outputs 
 of the ALU then I could do something like having a 4x8bit register file rather than just A and B and I could multiplex the RAM or ROM or whatever into the 
 ALU overcoming the register trashing  problem mentioned earlier.

Or perhaps the variable length instruction idea could yield benefits by giving me another 8 bits for control logic.

Obviously, being able to simulate all this before building is fantastic.

Considering basing the future ALU on a similar set to that used by [CrazySmallCpu](https://minnie.tuhs.org/Programs/CrazySmallCPU/description.html) ...
```
The ALU can perform sixteen operations based on the A and B inputs:
A + B decimal
A - B decimal
A & B
A | B
A ^ B
A + 1
Output 0, flags set to B's value
Output 0
A + B binary
A - B binary
Output A
Output B
A * B binary, high nibble
A * B binary, low nibble
A / B binary
A % B binary
```

Might use a ROM for the ALU. But haven't figured out with a single 8 bit wide ROM how to get a carry bit which would be necessary for chaining arithmetic to achieve arbitrary length additions. 
Perhaps this will require two 8 bit ROMS operating in 4 bit chained mode, or perhaps revert to using 4 bit arithmetic and chain operations in software? Not sure.

On the other hand I have two reclaimed [74181](http://ee-classes.usc.edu/ee459/library/datasheets/DM74LS181.pdf) ALU's in my desk - I think I should use those for nostalgia reasons.
I don't get BCD arithmetic with the 74181 but I do get to use the same type of chip that went went to the moon. Hooking it up fully would take 5 control lines plus the carry in. 
Hmm, I don't think I have the "LS" version which only pulls 20-40mA. The SN74181N that I have pulls a horrible amount of current according to the datasheet; 88-150mA.

  


## Write a C compiler

Yep - a C compile - others have done it.

Hmm. Or perhaps [PL/0](https://www.youtube.com/watch?v=hF43WUd8jrg&list=PLgAD2y-6wgwoTnPfZWhMuXID14xnzkz2x)??


## Hardware Components

- [74HC161](https://assets.nexperia.com/documents/data-sheet/74HC161.pdf)  4-bit presettable synchronous binary counter; asynchronous reset
- [74HC245](https://assets.nexperia.com/documents/data-sheet/74HC_HCT245.pdf) Octal transceiver - 3 state. Has convenient pinout than the [74244](https://assets.nexperia.com/documents/data-sheet/74HC_HCT244.pdf)
- [74HC377](https://assets.nexperia.com/documents/data-sheet/74HC_HCT377.pdf) 8 bit reg - convenient bit out at sides 
- [74HC670](https://assets.nexperia.com/documents/data-sheet/74HC_HCT377.pdf) 8 bit reg - convenient bit out at sides 
- [74HC670](https://www.ti.com/lit/ds/symlink/cd74hc670.pdf) - 4x4 register file - not synchronous so probably need to add edge detect to it. Not common but [Mouser has it](https://www.mouser.co.uk/Search/Refine?Keyword=74ls670) in DIP package. 


# Further reading and links

I'd also encourage you to look at [James Bates' series](https://www.youtube.com/watch?v=gqYFT6iecHw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui) of  Ben Eater inspired videos. 
I found James' discussion much more detailed in many cases and very useful. 

And definitly the [Crazy Small CPU series](https://www.youtube.com/playlist?list=PL9YEAcq-5hHIJnflTcLA45sVxr900ziEy). 

## Ben's links

https://www.youtube.com/watch?v=X7rCxs1ppyY&t=4m29s Ben Eater comment on clock sync, the need for a separate ("inverted") clock for the enablement of registers, and also the need to do enablement of registers ahead of the synchronous clock - his solution is to buffer the clock line so that it is delayed by some nanoseconds compared to the clock used for register enablement.   

## James Bates links

https://www.youtube.com/watch?v=AALVh39X3xw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=3#t=4m52s  Mentions "extensions to Bens video"

https://www.youtube.com/watch?v=AALVh39X3xw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=3#t=5m15s  Bus and no need for pulls up/downs on bus in his case 

https://www.youtube.com/watch?v=AALVh39X3xw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=3#t=6m30s  Discussion of program counter & bus width; Ben has 4 vs this 8

https://www.youtube.com/watch?v=hRJO97PbPlw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=4#t=43m30s Need to pulse the write as this isn’t synchronous ram

https://www.youtube.com/watch?v=hRJO97PbPlw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=4#t=46m09s Clock pulse and edge detector - Enable AND Rising Edge of clock via RC net ( Schmitt trigger??)

https://www.youtube.com/watch?v=hRJO97PbPlw&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=4#t=49m09s Discussion on the need to buffer the clock before James' edge detection signal to avoid pollution of the raw clock

https://www.youtube.com/watch?v=tUXboOaisAY&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=5#t=27m59s Good discussion on instruction encoding (compression) in 8 bits

https://www.youtube.com/watch?v=DfuFNBJn1hk&list=PL_i7PfWMNYobSPpg1_voiDe6qBcjvuVui&index=6#t=6m48s Fixes one of the operands to reduce instruction space B is always second input   so can’t do A=C+D

## Crazy Small Cpu

https://minnie.tuhs.org/Programs/CrazySmallCPU/ Home page

https://www.youtube.com/playlist?list=PL9YEAcq-5hHIJnflTcLA45sVxr900ziEy Playlist for the Crazy Small CPU

https://www.youtube.com/watch?v=zJw7WcikX9A RAM and flags

https://minnie.tuhs.org/Programs/UcodeCPU/index.html Microcode Logism Sim

## Simple CPU

http://www.simplecpudesign.com/ Home page

http://www.simplecpudesign.com/simple_cpu_v1/index.html  V1

http://www.simplecpudesign.com/simple_cpu_v1a/index.html  V1a

http://www.simplecpudesign.com/simple_cpu_v2/index.html   V3

 


## Other links

https://www.youtube.com/watch?v=Fq0MIJjlGsw Using the 74181

https://www.youtube.com/watch?v=WN8i5cwjkSE Doing binary arithmetic

http://teaching.idallen.com/dat2343/10f/notes/040_overflow.txt What we mean by Carry and Overflow


## Other Computers

https://github.com/DoctorWkt/CSCvon8/blob/master/Docs/CSCvon8_design.md

https://hackaday.io/project/24511-jaca-1-2-homebrew-computer

https://minnie.tuhs.org/Programs/CrazySmallCPU/description.html


 






## Simulators

[Logisim (original)](http://www.cburch.com/logisim/) is no longer supported however there seems to be a lot of reusable circuits out there for it (eg github). 
I started building in Logisim "original" and got a long way. However, at one point I was having difficulty with something and
I went investigating and only then discovered that it was no longer under development. Apparently the author had decided to go off and build a new shiny product 
but that project ran out of steam and never materialised. In the mean time Logism went stale. 
Fortunately however, Logisim "original" was adopted by [Reds Institute](http://blog.reds.ch) and was reborn as "Logisim Evolution".
 
[Logisim Evolution](https://github.com/reds-heig/logisim-evolution) is a fork that has added many features and also fixed various problems apparently.
It's worked pretty well for me. It's not perfect and a bunch of the UI interactions are non-intuitive but on the whole it works pretty well. Occasionally 
the simulation engine inside it crashed and I had to restart but the app told me to save and restart and this always worked fine without any loss of work so it wasn't
 much of an inconvenience. 

Unfortunately, there seems to be a bit of fragmentation in Logism as there appear to be a further two "active" forks.

[Cornell fork of Logism Evolution](https://github.com/cs3410/logisim-evolution) which is used by their [computer science course](
http://www.cs.cornell.edu/courses/cs3410/2019sp/labs/lab1/).
 
As a user of logism I don't welcome forks. I have to choose which to use.
I'm not sure what the incompatibilities might be, there might be features in either that I want. Its unclear which fork 
has the best chance of support and development going forward.

As a user I'd prefer it if all these clever folk pooled their resources into one mighty version of Evo.
The forking risks leaking resources away from the product generally and damages reputation.

### Upgrading from Logisim Original to Evolution

Upgrading wasn't trivial, buit wasn't too difficult either. Unfortunately, "original" and "evo" are not 100% compatible from an upgrade perspective. It seems that the problems occur if using the "memory" components like RAM, ROM and register for instance
 as these have changed in the "evo" dist.   

:thumbsup: The [video from MrMcsoftware](https://www.youtube.com/watch?v=yd7DeWTbfWQ) was incredibly helpful in giving me my first pointers on how to sort out the issues
without starting from scratch. It does mean editing the "circ" file in a text editor but the changes were pretty straightforward. Pity there isn't a better written guide to this.

One gripe myself and [MrMcsoftware](https://mrmcsoftware.wordpress.com/author/mrmcsoftware/) have in common is our dislike of the clunk ROM and RAM figures used by Evo.
The new images take up a lot more space needlessly.
I think they are some kind of ANSI rendition of the component - see the document [_"Texas Instruments paper Overview of IEEE Standard 91-1984 - 
Explanation of Logic Symbols "_](http://www.ti.com/lit/ml/sdyz001a/sdyz001a.pdf) (also copied into the docs folder of this repo).

MrMcsoftware has a replacement library (ForEv.jar) but I decided just to accept the change.
Another, gripe is that the rendering in evo is much chunkier so less seems to fit in the same area.
I find the original rendering much more pleasing to the eye, however, there are sufficient improvements in evo to persuade me to accept these changes.

For comparison: Original vs Evolution ...

![Original](docs/logisim-original-sample.png)
![Evolution](docs/logisim-evolution-sample.png)

### Logism Libraries

In the end I didn't use any libraries (yet) and used just the build in components, however I spent ages faffing about looking at them.
When I come to moving to hardware I may go looking for libraries then, I don't know, at that point I might try one of the other simulators.   

In any case my thought on libs follow ..
 
I wasn't able to find a good resource listing the various libraries that exist out there in github and elsewhere. Whether a given library works in original or evolution 
is uncertain until you actually try it. Many "original" circuit libs do work functionally in evolution but often the rendering of the component in evolution is utterly 
different than in the original product. My guess is that evo often ignores the rendering info in libraries from original and just renders a big clunky default.

For example is what you get if you import the 7477 from [stsvetkov](https://github.com/stsvetkov/L8cpu). To be fair this library doesn't pretend to be evo-compatible, but below you can see that the 747D latch gets rendered as some kind of evo default rendering.
Also, notice the mangled chip name "L_7474_bd25d20c. This name mangling is a feature of the auto upgrade that evo does to incompatible files from original. This name mangling typically occurs
when the name in the library breaks one of evo's name rules. Evo substitutes a valid name instead. This name mangling doesn't seem to mess with the functionality however.
In anycase if there is a library you like and want to use then you can always copy the file and edit it to remove offending characters like whitespace and hyphen.
You will still get a chunky glyph however then names will be more sensible. For contrast below you can see the 74181 from the same library after I've fixed various naming issues. 

![Original](docs/logisim-evolution-7474-and-181.png)

What worked for me where I didn't like the appearance of a component was that I imported it into Evo into a sub circuit and then I edited the appearance of the subcircuit in evo to make it
smaller and more convenient. This approach doesn't of course work for the chunk ROM and RAM I mentioned earlier because they have interactive UI's that I'd end up hiding
if I wrapped it and hid it inside a subcircuit. Anyway, it's worth considering.
     
Another, gripe with some libs is that they aren't accurate. In at least two cases I found for instance that outputs that were documented in the datasheet as "open collector"
had been implemented with regular logic; the 74181 "A=B" output is an example. It's not that hard to fix this if you wrap the component with output 
buffered as shown below

![OpenCollectorBuf](docs/open-collector.png)

Here's an example of usage of open collector outputs connecting in a "wired and" configuration ...
 
![OpenCollectorBuf](docs/open-collector-181.png)

I ended up putting the open collector buffer component into a subcircuit and then created an "appearance" for it in Evo's appearance editor that looks like a buffer with an asterisk next to it. 
I understand this is the correct icon for such.

### Getting Logism Evolution

See the downloads in guthub https://github.com/reds-heig/logisim-evolution/releases
  
  
### Yet more Simulators

[circuitverse](https://circuitverse.org/)   

Can't recall why I was put off by this product.
 
It's online which is cool but for some reason when I was playing originally I got stuck and gave up.
There does seem to be a community of project folk have worked that you can form and extend.
Looking again just now after having spent two weeks with Evo I think CircuitVerse looks pretty decent; however I still can't work out how to make
CV's plot feature work (Logism's Cronogram was useful to me).  
So, might be worth considering.

   
[Digital](https://github.com/hneemann/Digital)

Seems like a cousin of Logism and is actively supported too. 
The author responded very quickly to comments I made on an old closed ticket!.
I think I'd already started with Logisim by the time I discovered Digital.

Rather like Logisim this product is merely a jar you download and run; so it's not online.

The author provides a bunch of history on Logism that illustrates the fragmentation in the Logisim space. 

Digital's author says that he fixes a bunch of the long standing architectural issues in all variants of Logism.

The author also states that error detection in Digital is better than Logism. 
Any improvements in that space are a definite plus. 
It's a huge pain sometimes trying to figure out where an oscillation is coming from or where there's transient conflict 
on a level on a wire.

I found the UI interactions unintuitive at times. I couldn't work out how to reroute a wire without deleting it.

There's a lot of cool stuff in there including documentation on extending Digital. Docs on Logism are a bit lacking or fragmented.
I particularly like the claimed 80% test coverage. I understand Logism also lack good automated testing. 

Again probably worth a look.

Given Digital's connection back to Logism it's a pity there's no way to import a Logism circuit :(

 

