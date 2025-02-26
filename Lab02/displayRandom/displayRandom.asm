ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0030h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Timer 0 setup for 5ms (12 MHz clock)
            MOV     TH0, #0ECh     
            MOV     TL0, #78h      
            SETB    TR0            

            ; Initialize registers 
            MOV     R0, #01h      ; First digit - initialize with non-zero
            MOV     R1, #02h      ; Second digit - initialize with different values
            MOV     R2, #03h      ; Third digit  - for better animation effect
            MOV     R3, #04h      ; Fourth digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Animation speed counter
            MOV     R6, #55h      ; Initial seed value
            MOV     R7, #32       ; Seeding iterations
            
            ; Enhanced seeding process
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
            
            MOV     R7, #0        
            MOV     20h, #00h     ; Mode (0=Animation, 1=Display Random)
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable external interrupt 1
            
            SETB    ET0           ; Enable Timer 0 interrupt
            SETB    EA            ; Enable global interrupts

MainLoop:   SJMP    MainLoop      ; Everything handled by interrupts

; Enhanced random number generator
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
            
; External Interrupt 1 - Generate random numbers
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
            
            ACALL   GetRandom     ; Third digit
            MOV     B, #10
            DIV     AB
            MOV     R2, B         
            
            ACALL   GetRandom     ; Fourth digit
            MOV     B, #10
            DIV     AB
            MOV     R3, B         
            
            POP     PSW
            POP     ACC
            RETI

; Timer 0 ISR - Display refresh and animation
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            
            ; Check mode
            MOV     A, 20h
            JNZ     Display_Random   ; If mode=1, show random numbers
            
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
            
            MOV     A, R1
            ADD     A, #03h        ; Different increment pattern
            ANL     A, #0Fh
            MOV     R1, A
            
            MOV     A, R2
            ADD     A, #02h
            ANL     A, #0Fh
            MOV     R2, A
            
            MOV     A, R3
            INC     A
            ANL     A, #0Fh
            JNZ     Save_Anim_Digit3
            MOV     A, #01h
Save_Anim_Digit3:
            MOV     R3, A
            
Skip_Anim_Update:
            ; Fall through to display digits

Display_Random:
            ; Select digit to display using position code in high nibble
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R0          ; First digit (thousands)
            ORL     A, #00h        ; Position 0 code (00h)
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R1          ; Second digit (hundreds)
            ORL     A, #10h        ; Position 1 code (10h)
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R2          ; Third digit (tens)
            ORL     A, #20h        ; Position 2 code (20h)
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R3          ; Fourth digit (ones)
            ORL     A, #30h        ; Position 3 code (30h)

Output_Digit:
            ANL     A, #3Fh        ; Ensure upper 2 bits are clear
            MOV     P1, A          ; Output digit value with position code

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            CLR     A             
Save_Pos:   MOV     R4, A         

            POP     PSW            
            POP     ACC
            RETI

            END