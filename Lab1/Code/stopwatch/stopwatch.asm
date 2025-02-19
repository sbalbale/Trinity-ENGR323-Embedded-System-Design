            ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     

            ; Initialize registers
            MOV     R0, #00h      ; 1/100 second digit (stopwatch)
            MOV     R1, #00h      ; 1/10 second digit (stopwatch)
            MOV     R2, #00h      ; seconds digit (stopwatch)
            MOV     R3, #00h      ; 10 seconds digit (stopwatch)
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            MOV     R6, #00h     ; Mode (0=Clock, 1=Run, 2=Stop)
            MOV     30h, #00h     ; Clock seconds (ones)
            MOV     31h, #00h     ; Clock seconds (tens)
            MOV     32h, #00h     ; Clock minutes (ones)
            MOV     33h, #00h     ; Clock minutes (tens)
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Enable display refresh timer
            SETB    ET0           ; Enable Timer 0
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   ; Check if 1 second has elapsed (clock)
            MOV     A, R5
            CJNE    A, #0C8h, Check_Stopwatch  ; Wait for 200 * 5ms
            MOV     R5, #00h      ; Reset counter

            ; Update clock seconds
            INC     30h           ; Increment ones second
            MOV     A, 30h
            CJNE    A, #0Ah, Check_Stopwatch
            MOV     30h, #00h     ; Reset ones second
            
            ; Update tens seconds
            INC     31h           ; Increment tens seconds
            MOV     A, 31h
            CJNE    A, #06h, Check_Stopwatch
            MOV     31h, #00h     ; Reset tens seconds
            
            ; Update minutes
            INC     32h           ; Increment minutes
            MOV     A, 32h
            CJNE    A, #0Ah, Check_Stopwatch
            MOV     32h, #00h     ; Reset minutes
            
            ; Update tens minutes
            INC     33h           ; Increment tens minutes
            MOV     A, 33h
            CJNE    A, #06h, Check_Stopwatch
            MOV     33h, #00h     ; Reset tens minutes

Check_Stopwatch:
            ; Check current mode
            MOV     A, R6
            CJNE    A, #01h, MainLoop  ; If not mode 1, skip stopwatch

            ; Update stopwatch
            MOV     A, R5
            CJNE    A, #02h, MainLoop  ; Wait for 10ms (2 * 5ms)
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
           
; 1ms delay routine
MSECDelay:  MOV     R7, #0C7h    ; 199 * 1us = 1ms
BackA:      DEC     R7
            NOP
            NOP
            CJNE    R7, #000h, BackA
            RET

; External Interrupt 1 ISR - Toggle modes
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     A, R6        ; Get current mode
            INC     A             ; Next mode
            CJNE    A, #03h, Save_Mode
            MOV     A, #00h       ; Wrap to mode 0
Save_Mode:  MOV     R6, A
            
            POP     PSW
            POP     ACC
            RETI

; Timer 0 ISR - Display refresh only
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #08Ch     
            CLR     TF0            
            SETB    TR0            

            ; Increment 5ms counter
            INC     R5            

            ; Select display based on mode
            MOV     A, R6
            JNZ     Show_Stopwatch

Show_Clock: MOV     A, R4          
            CJNE    A, #00h, Clock_Pos1
            MOV     A, 33h         ; Display 10 minutes
            SJMP    Output_Digit

Clock_Pos1: CJNE    A, #01h, Clock_Pos2
            MOV     A, 32h         ; Display 1 minute
            ORL     A, #10h        
            SJMP    Output_Digit

Clock_Pos2: CJNE    A, #02h, Clock_Pos3
            MOV     A, 31h         ; Display 10 seconds
            ORL     A, #20h        
            SJMP    Output_Digit

Clock_Pos3: MOV     A, 30h         ; Display 1 second
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