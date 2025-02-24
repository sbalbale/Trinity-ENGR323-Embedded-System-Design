            ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize registers
            MOV     R0, #00h      ; 1/100 second digit (0-9)
            MOV     R1, #00h      ; 1/10 second digit (0-9)
            MOV     R2, #00h      ; seconds digit (0-9)
            MOV     R3, #00h      ; 10 seconds digit (0-5)
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; MS counter (0-9 for 10ms)
            MOV     20h, #00h     ; Mode (0=Clock, 1=Run, 2=Stop)
            MOV     30h, #00h     ; Clock MS counter
            MOV     31h, #00h     ; Clock seconds
            MOV     32h, #00h     ; Clock minutes
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Enable display refresh timer
            SETB    ET0           ; Enable Timer 0
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   ACALL   MSECDelay     ; 1ms delay

            ; Always update clock first
            INC     30h           ; Count milliseconds
            MOV     A, 30h
            CJNE    A, #0E8h, Check_Stopwatch  ; Wait for 1000ms (232 decimal)
            MOV     30h, #00h     ; Reset MS counter
            
            ; Update clock seconds
            MOV     A, 31h
            INC     A
            CJNE    A, #3Ch, Save_Clock_Sec  ; 60 seconds
            MOV     A, #00h
            
            ; Update clock minutes
            MOV     A, 32h
            INC     A
            CJNE    A, #3Ch, Save_Clock_Min  ; 60 minutes
            MOV     A, #00h
            
Save_Clock_Min:  MOV     32h, A         ; Save minutes
Save_Clock_Sec:  MOV     31h, A         ; Save seconds
                SJMP    MainLoop

Check_Stopwatch:
            ; Check current mode
            MOV     A, 20h
            CJNE    A, #01h, MainLoop  ; If not mode 1, skip stopwatch

            ; Update stopwatch
            INC     R5            ; Count milliseconds
            MOV     A, R5
            CJNE    A, #0Ah, MainLoop  ; Wait for 10ms
            MOV     R5, #00h     ; Reset MS counter

            ; Update stopwatch digits
            INC     R0           ; 1/100 seconds
            MOV     A, R0
            CJNE    A, #0Ah, MainLoop
            MOV     R0, #00h
            
            INC     R1           ; 1/10 seconds
            MOV     A, R1
            CJNE    A, #0Ah, MainLoop
            MOV     R1, #00h
            
            INC     R2           ; Seconds
            MOV     A, R2
            CJNE    A, #0Ah, MainLoop
            MOV     R2, #00h
            
            INC     R3           ; 10 seconds
            MOV     A, R3
            CJNE    A, #06h, MainLoop  ; Max 59.99 seconds
            MOV     R3, #00h
            SJMP    MainLoop

MSECDelay:  MOV     R7, #0C7h    ; 199 * 1us = 1ms
BackA:      DEC     R7
            NOP
            NOP
            CJNE    R7, #000h, BackA
            RET

; External Interrupt 1 ISR - Toggle modes
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     A, 20h         ; Get current mode
            INC     A              ; Next mode
            CJNE    A, #03h, Save_Mode
            MOV     A, #00h        ; Wrap to mode 0
Save_Mode:  MOV     20h, A         ; Save new mode
            
            POP     PSW
            POP     ACC
            RETI

; Timer 0 ISR - Display refresh
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #0BDh     

            ; Select display based on mode
            MOV     A, 20h
            JNZ     Show_Stopwatch

Show_Clock: MOV     A, R4          
            CJNE    A, #00h, Clock_Pos1
            MOV     A, 32h         ; Minutes
            MOV     B, #0Ah
            DIV     AB             ; Divide by 10 for tens digit
            SJMP    Output_Digit

Clock_Pos1: CJNE    A, #01h, Clock_Pos2
            MOV     A, 32h         ; Minutes
            MOV     B, #0Ah
            DIV     AB
            MOV     A, B           ; Use remainder for ones digit
            ORL     A, #10h        
            SJMP    Output_Digit

Clock_Pos2: CJNE    A, #02h, Clock_Pos3
            MOV     A, 31h         ; Seconds
            MOV     B, #0Ah
            DIV     AB             ; Divide by 10 for tens digit
            ORL     A, #20h        
            SJMP    Output_Digit

Clock_Pos3: MOV     A, 31h         ; Seconds
            MOV     B, #0Ah
            DIV     AB
            MOV     A, B           ; Use remainder for ones digit
            ORL     A, #30h        
            SJMP    Output_Digit

Show_Stopwatch:
            MOV     A, R4          
            CJNE    A, #00h, Stop_Pos1
            MOV     A, R3          ; 10 seconds
            SJMP    Output_Digit

Stop_Pos1:  CJNE    A, #01h, Stop_Pos2
            MOV     A, R2          ; Seconds
            ORL     A, #10h        
            SJMP    Output_Digit

Stop_Pos2:  CJNE    A, #02h, Stop_Pos3
            MOV     A, R1          ; 1/10 second
            ORL     A, #20h        
            SJMP    Output_Digit

Stop_Pos3:  MOV     A, R0          ; 1/100 second
            ORL     A, #30h        

Output_Digit:
            MOV     P1, A          

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