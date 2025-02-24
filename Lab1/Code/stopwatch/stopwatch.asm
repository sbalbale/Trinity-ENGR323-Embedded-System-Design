            ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize stopwatch registers (Bank 0)
            CLR     RS0            ; Select Bank 0
            CLR     RS1
            MOV     R0, #00h      ; 1/100 second digit
            MOV     R1, #00h      ; 1/10 second digit
            MOV     R2, #00h      ; seconds digit
            MOV     R3, #00h      ; 10 seconds digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            
            ; Initialize clock registers (Bank 1)
            SETB    RS0            ; Select Bank 1
            MOV     R0, #00h      ; seconds ones
            MOV     R1, #00h      ; seconds tens
            MOV     R2, #00h      ; minutes ones
            MOV     R3, #00h      ; minutes tens
            
            ; Back to Bank 0
            CLR     RS0
            MOV     20h, #00h     ; Mode (0=Clock, 1=Run, 2=Stop)
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    ET0           ; Enable Timer 0
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   SJMP    MainLoop      ; Everything handled by interrupts

Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #08Ch     
            CLR     TF0            
            SETB    TR0            

            ; Update clock every 200 intervals (1 second)
            INC     R5            
            MOV     A, R5
            CJNE    A, #0C8h, Update_Stopwatch  ; 200 * 5ms = 1 second
            MOV     R5, #00h     

            ; Switch to Bank 1 for clock update
            SETB    RS0

            ; Update clock seconds ones
            INC     R0
            MOV     A, R0
            CJNE    A, #0Ah, Switch_Bank_0
            MOV     R0, #00h
            
            ; Update clock seconds tens
            INC     R1
            MOV     A, R1
            CJNE    A, #06h, Switch_Bank_0
            MOV     R1, #00h
            
            ; Update clock minutes ones
            INC     R2
            MOV     A, R2
            CJNE    A, #0Ah, Switch_Bank_0
            MOV     R2, #00h
            
            ; Update clock minutes tens
            INC     R3
            MOV     A, R3
            CJNE    A, #06h, Switch_Bank_0
            MOV     R3, #00h

Switch_Bank_0:
            CLR     RS0           ; Switch back to Bank 0

Update_Stopwatch:
            MOV     A, 20h        ; Check mode
            CJNE    A, #01h, Display_Update

            ; Update stopwatch every 2 intervals (10ms)
            MOV     A, R5
            ANL     A, #01h       ; Check if even number
            JNZ     Display_Update

            ; Update stopwatch digits (Bank 0)
            INC     R0           ; 1/100 seconds
            MOV     A, R0
            CJNE    A, #0Ah, Display_Update
            MOV     R0, #00h
            
            INC     R1           ; 1/10 seconds
            MOV     A, R1
            CJNE    A, #0Ah, Display_Update
            MOV     R1, #00h
            
            INC     R2           ; Seconds
            MOV     A, R2
            CJNE    A, #0Ah, Display_Update
            MOV     R2, #00h
            
            INC     R3           ; 10 seconds
            MOV     A, R3
            CJNE    A, #06h, Display_Update
            MOV     R3, #00h

Display_Update:
            ; Select display based on mode
            MOV     A, 20h
            JNZ     Show_Stopwatch

Show_Clock: MOV     A, R4          
            SETB    RS0           ; Switch to Bank 1
            CJNE    A, #00h, Clock_Pos1
            MOV     A, R3         ; Minutes tens
            CLR     RS0           ; Back to Bank 0
            SJMP    Output_Digit

Clock_Pos1: CJNE    A, #01h, Clock_Pos2
            MOV     A, R2         ; Minutes ones
            CLR     RS0
            ORL     A, #10h        
            SJMP    Output_Digit

Clock_Pos2: CJNE    A, #02h, Clock_Pos3
            MOV     A, R1         ; Seconds tens
            CLR     RS0
            ORL     A, #20h        
            SJMP    Output_Digit

Clock_Pos3: MOV     A, R0         ; Seconds ones
            CLR     RS0
            ORL     A, #30h        
            SJMP    Output_Digit

Show_Stopwatch:
            MOV     A, R4          
            CJNE    A, #00h, Stop_Pos1
            MOV     A, R3         ; 10 seconds
            SJMP    Output_Digit

Stop_Pos1:  CJNE    A, #01h, Stop_Pos2
            MOV     A, R2         ; Seconds
            ORL     A, #10h        
            SJMP    Output_Digit

Stop_Pos2:  CJNE    A, #02h, Stop_Pos3
            MOV     A, R1         ; 1/10 second
            ORL     A, #20h        
            SJMP    Output_Digit

Stop_Pos3:  MOV     A, R0         ; 1/100 second
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

EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     A, 20h        ; Get current mode
            INC     A             ; Next mode
            CJNE    A, #03h, Save_Mode
            MOV     A, #00h       ; Wrap to mode 0
Save_Mode:  MOV     20h, A        ; Save new mode
            
            POP     PSW
            POP     ACC
            RETI

            END