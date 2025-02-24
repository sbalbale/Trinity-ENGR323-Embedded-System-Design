ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0030h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     


            ; Initialize registers 
            MOV     R0, #00h      ; Display digits
            MOV     R1, #00h
            MOV     R2, #00h
            MOV     R3, #00h
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Animation counter
            
            ; Initialize random seed using timer
            MOV     TL0, #0       ; Clear timer
            SETB    TR0           ; Start timer
SeedLoop:   INC     R6           ; Increment seed
            MOV     A, TL0        ; Get current timer value
            JZ      SeedLoop      ; Keep going if timer is 0
            MOV     R6, A         ; Use timer value as seed
            MOV     R7, #0        ; Counter for additional randomization
            
            MOV     20h, #00h     ; Mode (0=Animation, 1=Random)
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Enable interrupts
            SETB    ET0           ; Enable Timer 0 interrupt 
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   ; Main program loop
            MOV     A, 20h        ; Get current mode
            JNZ     MainLoop      ; If in random mode, just wait
            
            ; Animation sequence in mode 0
            MOV     A, R5
            INC     A
            CJNE    A, #20, SaveCount ; Update every 100ms
            MOV     A, #00h  
            
            ; Update animation pattern
            MOV     A, R0
            ADD     A, #11h
            MOV     R0, A
            MOV     A, R1  
            ADD     A, #11h
            MOV     R1, A
            MOV     A, R2
            ADD     A, #11h
            MOV     R2, A
            MOV     A, R3
            ADD     A, #11h
            MOV     R3, A
            
SaveCount:  MOV     R5, A
            SJMP    MainLoop

; Enhanced random number generator using LFSR with counter
GetRandom:  MOV     A, R6         ; Get current seed
            MOV     B, A          ; Save copy
            RLC     A             ; Rotate left through carry
            JNC     Skip1         ; If carry was 0, skip
            XRL     A, #B2h       ; XOR with polynomial tap
Skip1:      XRL     A, R7         ; Mix with counter
            ADD     A, B          ; Add original value
            MOV     R6, A         ; Save new seed
            INC     R7            ; Increment counter
            RET
            
; Convert hex to single decimal digit (1-9)
; Input: Hex number in A
; Output: BCD digit 1-9 in A
Hex_to_Digit:
            PUSH    B           ; Save B register
            MOV     B, #09h     ; Maximum value
            DIV     AB          ; Divide by 9
            MOV     A, B        ; Get remainder (0-8)
            INC     A           ; Add 1 to get 1-9
            POP     B
            RET

; External Interrupt 1 - Switch to random mode
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     20h, #01h     ; Switch to random mode

            ; Generate 4 random numbers (0-9)
            
            ; First digit (0-9)
            ACALL   GetRandom     ; Get random seed in A
            MOV     B, #10        ; Divide by 10 to get 0-9
            DIV     AB            ; A = quotient, B = remainder
            MOV     R0, B         ; Store first digit
            
            ; Second digit 
            ACALL   GetRandom
            MOV     B, #10
            DIV     AB
            MOV     R1, B
            
            ; Third digit
            ACALL   GetRandom 
            MOV     B, #10
            DIV     AB
            MOV     R2, B
            
            ; Fourth digit
            ACALL   GetRandom
            MOV     B, #10
            DIV     AB
            MOV     R3, B
            
            POP     PSW
            POP     ACC
            RETI

; Timer 0 ISR - Display refresh
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            
            ; Get current position and display digit
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R3          ; Get first digit
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R2          ; Get second digit
            ORL     A, #10h        ; Set position bit
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R1          ; Get third digit
            ORL     A, #20h        ; Set position bit
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R0          ; Get fourth digit
            ORL     A, #30h        ; Set position bit

Output_Digit:
            MOV     P1, A          ; Update display

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h        
Save_Pos:   MOV     R4, A         

            POP     PSW            
            POP     ACC
            RETI

            END
