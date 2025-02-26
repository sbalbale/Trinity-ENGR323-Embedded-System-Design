# Random Number Generator and Display

## Overview
`displayRandom.asm` implements a 4-digit random number generator and display system for an 8051 microcontroller. The program features both an animated "slot machine" mode and a random number generation mode that can be toggled via an external interrupt button.

## Hardware Requirements
- 8051-compatible microcontroller running at 12 MHz
- 4-digit 7-segment display connected to Port 1
- External button connected to INT1 (External Interrupt 1)

## Functionality

### Animation Mode
By default, the system starts in animation mode, displaying continuously changing digits across all four positions to create a slot machine effect. Each digit position updates at a slightly different rate to enhance the visual appeal.

### Random Number Generation
When the external button (connected to INT1) is pressed:
- The system generates a truly random 4-digit number
- The first digit is guaranteed to be 1-9 (non-zero)
- The remaining three digits can be 0-9
- The display immediately shows this number

## Technical Implementation

### Initialization and Setup
The program begins with timer and register initialization:

```assembly
; Timer 0 setup for 5ms (12 MHz clock)
MOV     TH0, #0ECh     
MOV     TL0, #78h      
SETB    TR0            

; Initialize registers 
MOV     R0, #01h      ; First digit - initialize with non-zero
MOV     R1, #02h      ; Second digit
MOV     R2, #03h      ; Third digit
MOV     R3, #04h      ; Fourth digit
MOV     R4, #00h      ; Display position
MOV     R5, #00h      ; Animation speed counter
MOV     R6, #55h      ; Initial seed value
MOV     R7, #32       ; Seeding iterations
```

### Random Number Generation
The program implements a robust pseudo-random number generator that uses a Linear Feedback Shift Register (LFSR) algorithm:

```assembly
GetRandom:  MOV     A, R6         ; Get current seed
            MOV     B, A          ; Save copy
            RLC     A             ; Rotate left
            JNC     Skip1
            XRL     A, #0B2h      ; Polynomial tap
Skip1:      XRL     A, 21h        ; Mix with stored entropy
            ADD     A, TL0        ; Add timer value
            XRL     A, R7         ; Mix with counter
            ADD     A, B          ; Add original seed
            MOV     R6, A         ; Save new seed
            MOV     A, 21h        ; Update stored entropy
            RLC     A
            XRL     A, R6
            MOV     21h, A
            INC     R7            
            RET
```

This algorithm:
- Seeds itself using timer values for enhanced randomness
- Uses polynomial feedback (XOR with 0B2h)
- Mixes in entropy from timer values and internal state
- Updates the seed value with each call

### Seeding Process
To ensure proper randomness, the seed is thoroughly mixed on startup:

```assembly
SeedLoop:   MOV     A, TL0        ; Get timer low byte
            XRL     A, R6         ; XOR with current seed
            RLC     A             ; Rotate left
            ADD     A, TH0        ; Add timer high byte
            XRL     A, #0A5h      ; XOR with different constant
            RRC     A             ; Rotate right
            ADD     A, R6         ; Add previous seed
            XRL     A, #5Ah       ; XOR with another constant
            MOV     R6, A         ; Store new seed
            
            ; Additional mixing
            MOV     A, TH0
            XRL     A, R6
            RLC     A
            MOV     21h, A        ; Store additional entropy
            
            DJNZ    R7, SeedLoop
```

### Display Multiplexing System
The display is managed by the Timer 0 interrupt, which selects the appropriate digit to display every 5ms:

```assembly
; Select digit to display using position code in high nibble
MOV     A, R4          
CJNE    A, #00h, Try_Pos1
MOV     A, R0          ; First digit (thousands)
ORL     A, #00h        ; Position 0 code (00h)
SJMP    Output_Digit

; ... code for other positions ...

Output_Digit:
            ANL     A, #3Fh        ; Ensure upper 2 bits are clear
            MOV     P1, A          ; Output digit value with position code

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            CLR     A             
Save_Pos:   MOV     R4, A
```

The high nibble of Port 1 contains the position code that selects which display digit to activate.

### Random Number Generation on Button Press
When the external button is pressed, the External Interrupt 1 handler generates a new random number:

```assembly
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     20h, #01h     ; Switch to display mode

            ; Generate first digit (1-9 to ensure non-zero first digit)
            ACALL   GetRandom     
            MOV     B, #9         ; Divide by 9 to get 0-8
            DIV     AB            
            MOV     A, B          ; Get remainder (0-8)
            INC     A             ; Add 1 to get 1-9
            MOV     R0, A         ; Store first digit
            
            ; Generate remaining digits (0-9)
            ACALL   GetRandom     ; Second digit
            MOV     B, #10        
            DIV     AB
            MOV     R1, B
            
            ; Similar code for other digits...
```

This ensures:
- The first digit is between 1-9 (by using modulo 9 + 1)
- Other digits are between 0-9 (using modulo 10)

### Animation Logic
In animation mode, the digits are updated every 3 timer interrupts with different increment patterns:

```assembly
; Slot machine animation
INC     R5
MOV     A, R5
CJNE    A, #03h, Skip_Anim_Update  ; Update animation every 3 ticks
MOV     R5, #00h

; Update all digits for animation with varying speeds
MOV     A, R0
INC     A
ANL     A, #0Fh        ; Keep 0-F range
JNZ     Save_Anim_Digit0
MOV     A, #01h        ; Avoid 0 to make it look active
Save_Anim_Digit0:
MOV     R0, A

; Different increment patterns for other digits
MOV     A, R1
ADD     A, #03h        ; Different increment pattern
ANL     A, #0Fh
MOV     R1, A

; Similar patterns for other digits...
```

## Register Usage
- R0-R3: Store the four display digits
- R4: Current display position (0-3)
- R5: Animation speed counter
- R6: Random seed value
- R7: Counter for various operations
- Memory location 20h: Mode flag (0=Animation, 1=Display Random)
- Memory location 21h: Additional entropy storage

## Memory Organization
- Main code starts at address 0030h
- External Interrupt 1 vector at 0013h
- Timer 0 interrupt vector at 000Bh

## Operation
1. On startup, the system enters animation mode
2. Press the external button to generate and display a random number
3. The system will maintain this display until reset or power cycle

## Timing Parameters
- 5ms refresh rate for display multiplexing (Timer 0 reload values: TH0=0ECh, TL0=78h)
- Animation updates every 15ms (every 3 timer interrupts)

## Interrupt Structure
The program uses two interrupt vectors:

```assembly
ORG     0013h          ; External Interrupt 1 vector
AJMP    EXT1_ISR           

ORG     000Bh          ; Timer 0 vector
AJMP    Timer0_ISR
```

Both interrupts are enabled during initialization:

```assembly
; Setup External Interrupt 1
SETB    IT1           ; Falling edge triggered 
SETB    EX1           ; Enable external interrupt 1

SETB    ET0           ; Enable Timer 0 interrupt
SETB    EA            ; Enable global interrupts
```