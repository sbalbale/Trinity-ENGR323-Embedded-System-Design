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
            MOV     R0, #00h      
            MOV     R1, #00h
            MOV     R2, #00h
            MOV     R3, #00h
            MOV     R4, #00h      
            MOV     R5, #00h      
            MOV     R6, #55h      ; New seed value
            MOV     R7, #32       ; More iterations for better entropy
            
            ; Enhanced seeding process
SeedLoop:   MOV     A, TL0        ; Get timer low byte
            XRL     A, R6         ; XOR with current seed
            RLC     A             ; Rotate left
            ADD     A, TH0        ; Add timer high byte
            XRL     A, #0A5h      ; XOR with different constant
            RRC     A             ; Rotate right
            ADD     A, R6         ; Add previous seed
            XRL     A, #5Ah      ; XOR with another constant
            MOV     R6, A         ; Store new seed
            
            ; Additional mixing
            MOV     A, TH0
            XRL     A, R6
            RLC     A
            MOV     21h, A        ; Store additional entropy
            
            DJNZ    R7, SeedLoop
            
            MOV     R7, #0        
            MOV     20h, #00h     
            
            ; Setup External Interrupt 1
            SETB    IT1           
            SETB    EX1           
            
            SETB    ET0           
            SETB    EA            

MainLoop:   ; Rest of the main loop remains same
            MOV     A, 20h        
            JNZ     MainLoop      
            
            MOV     A, R5
            INC     A
            CJNE    A, #20, SaveCount
            MOV     A, #00h  
            
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
            
; External Interrupt 1 - Switch to random mode
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     20h, #01h     ; Switch to random mode

            ; Generate first digit (1-9 to ensure number > 1000)
            ACALL   GetRandom     
            MOV     B, #9         ; Divide by 9 to get 0-8
            DIV     AB            
            MOV     A, B          ; Get remainder (0-8)
            INC     A             ; Add 1 to get 1-9
            MOV     R0, A         ; Store first digit (1-9)
            
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

; Timer 0 ISR - Display refresh
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            
            ; Get current position and display digit
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R0          ; Get leftmost digit (thousands)
            SETB    P1.4           ; Enable digit 3
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R1          ; Get hundreds digit
            SETB    P1.5           ; Enable digit 2
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R2          ; Get tens digit
            SETB    P1.6           ; Enable digit 1
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R3          ; Get ones digit
            SETB    P1.7           ; Enable digit 0

Output_Digit:
            ANL     A, #0Fh        ; Mask to keep only lower 4 bits
            MOV     P1, A          ; Output digit value to lower 4 bits

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
