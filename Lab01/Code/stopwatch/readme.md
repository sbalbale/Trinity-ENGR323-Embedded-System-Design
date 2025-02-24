# 8051 Stopwatch and Clock Implementation

## Overview
This project implements a dual-function digital display system for the 8051 microcontroller, featuring a real-time clock and stopwatch with a 4-digit 7-segment LED display.

## Features
- Real-time clock displaying hours and minutes (00:00 to 59:59)
- Stopwatch with 1/100 second precision (0.00 to 59.99)
- Mode switching via external interrupt
- Multiplexed 4-digit 7-segment display
- Register bank switching for separate timekeeping

## Hardware Requirements
- 8051 microcontroller (12MHz)
- 4-digit 7-segment LED display (common anode)
- External button for INT1
- Port connections:
  - P1: Display output
  - INT1: Mode switch button

## Memory Organization

### Register Banks
```
Bank 0 (Stopwatch):
- R0: 1/100 second digit (0-9)
- R1: 1/10 second digit (0-9)
- R2: Seconds digit (0-9)
- R3: 10 seconds digit (0-5)
- R4: Display position (0-3)
- R5: 5ms interval counter

Bank 1 (Clock):
- R0: Seconds ones (0-9)
- R1: Seconds tens (0-5)
- R2: Minutes ones (0-9)
- R3: Minutes tens (0-5)
```

### Direct Memory
- `20h`: Mode storage
  - 0 = Clock display
  - 1 = Stopwatch running
  - 2 = Stopwatch stopped

## Timing Details
- Timer 0: 5ms base interval (Mode 1, 16-bit)
- Clock update: 200 × 5ms = 1 second
- Stopwatch update: 2 × 5ms = 10ms
- Display refresh: 5ms per digit

## Display Format
```
Position    Clock Mode          Stopwatch Mode
0 (Left)    Minutes tens       10 seconds
1           Minutes ones       Seconds
2           Seconds tens      1/10 seconds
3 (Right)   Seconds ones      1/100 seconds

Output format to P1:
xxxx xxxx
||||----- Digit value (0-9)
||||
```

## Operating Modes
1. **Clock Mode (0)**
   - Displays time in MM:SS format
   - Continuously runs in background
   - Updates every second

2. **Stopwatch Run Mode (1)**
   - Displays SS.CC format (seconds.centiseconds)
   - Updates every 10ms
   - Counts up to 59.99

3. **Stopwatch Stop Mode (2)**
   - Freezes stopwatch display
   - Maintains last count value
   - Clock continues in background

## Interrupt Vectors
- `0000h`: Reset vector → MAIN
- `000Bh`: Timer 0 → Timer0_ISR
- `0013h`: External INT1 → EXT1_ISR

## Key Routines

### Timer0_ISR
- Handles display multiplexing
- Updates clock and stopwatch
- Manages register bank switching
- Implements 5ms base timing

### EXT1_ISR
- Cycles through display modes
- Triggered by falling edge on INT1
- Mode sequence: Clock → Run → Stop → Clock

## Limitations
- No time setting capability
- Maximum display: 59:59 (clock), 59.99 (stopwatch)
- No battery backup
- Fixed 24-hour format
- Display brightness not adjustable

## Assembly and Usage
1. Assemble using 8051 assembler
2. Program microcontroller
3. Connect display to P1
4. Connect mode button to INT1
5. Power up system
6. Use mode button to switch functions